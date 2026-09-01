import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../core/database/local_chat_database.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/socket_client.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._client, this._socket, this._prefs, this._database);

  final DioClient _client;
  final SocketClient _socket;
  final SharedPreferences _prefs;
  final LocalChatDatabase _database;
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, StreamController<List<ChatMessage>>> _controllers = {};
  final Set<String> _listeningConversations = {};
  final Set<String> _activeConversations = {};

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String conversationId,
    required User currentUser,
  }) {
    final controller = _controllers.putIfAbsent(
      conversationId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    final cached = _database
        .getMessages(conversationId)
        .map((message) => _fromCache(message, currentUser))
        .toList();
    if (cached.isNotEmpty) _messages[conversationId] = cached;
    unawaited(_load(conversationId, currentUser));
    final token = _prefs.getString(StorageConstants.accessToken);
    if (token != null) {
      _socket.connect(accessToken: token);
      _socket.emit('conversation:join', conversationId);
      if (_listeningConversations.add(conversationId)) {
        _socket.messageStream
            .where((data) => data['conversationId'] == conversationId)
            .listen((data) {
              final message = _fromJson(data, currentUser);
              final items = _messages.putIfAbsent(conversationId, () => []);
              final pendingIndex = message.clientMessageId == null
                  ? -1
                  : items.indexWhere(
                      (item) => item.id == message.clientMessageId,
                    );
              if (pendingIndex >= 0) {
                items[pendingIndex] = message;
                items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                controller.add(List.unmodifiable(items));
                _cacheMessage(message);
              } else if (!items.any((item) => item.id == message.id)) {
                items.add(message);
                controller.add(List.unmodifiable(items));
                _cacheMessage(message);
              }
              if (!message.isMine &&
                  _activeConversations.contains(conversationId)) {
                unawaited(_markRead(conversationId));
              }
            });
        _socket.readStream
            .where((data) => data['conversationId'] == conversationId)
            .listen((receipt) {
              if (receipt['conversationId'] != conversationId) return;
              final ids =
                  (receipt['messageIds'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toSet() ??
                  const <String>{};
              if (ids.isEmpty) return;
              final items = _messages[conversationId];
              if (items == null) return;
              var changed = false;
              _messages[conversationId] = items.map((message) {
                if (!message.isMine ||
                    !ids.contains(message.id) ||
                    message.isRead) {
                  return message;
                }
                changed = true;
                return message.copyWith(status: 'READ');
              }).toList();
              if (changed) {
                controller.add(List.unmodifiable(_messages[conversationId]!));
                _markCachedMessagesRead(ids);
              }
            });
      }
    }
    return _watchWithInitial(
      conversationId,
      controller.stream,
      List.unmodifiable(_messages[conversationId] ?? const []),
    );
  }

  Stream<List<ChatMessage>> _watchWithInitial(
    String conversationId,
    Stream<List<ChatMessage>> updates,
    List<ChatMessage> initial,
  ) async* {
    _activeConversations.add(conversationId);
    try {
      yield initial;
      yield* updates;
    } finally {
      _activeConversations.remove(conversationId);
    }
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required User currentUser,
    required String content,
  }) async {
    final pending = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName,
      content: content,
      createdAt: DateTime.now(),
      isMine: true,
      status: 'SENDING',
      clientMessageId: null,
    );
    final items = _messages.putIfAbsent(conversationId, () => []);
    items.add(pending);
    _controllers[conversationId]?.add(List.unmodifiable(items));

    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '${ApiConstants.conversations}/$conversationId/messages',
        data: {'content': content, 'clientMessageId': pending.id},
      );
      final message = _fromJson(response.data!, currentUser);
      items.removeWhere((item) => item.id == pending.id);
      if (!items.any((item) => item.id == message.id)) {
        items.add(message);
      }
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _controllers[conversationId]?.add(List.unmodifiable(items));
      _cacheMessage(message);
    } on DioException catch (error) {
      final index = items.indexWhere((item) => item.id == pending.id);
      if (index >= 0) items[index] = pending.copyWith(status: 'FAILED');
      _controllers[conversationId]?.add(List.unmodifiable(items));
      throw Exception(_errorMessage(error));
    } catch (_) {
      final index = items.indexWhere((item) => item.id == pending.id);
      if (index >= 0) items[index] = pending.copyWith(status: 'FAILED');
      _controllers[conversationId]?.add(List.unmodifiable(items));
      rethrow;
    }
  }

  Future<void> _load(String conversationId, User user) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '${ApiConstants.conversations}/$conversationId/messages',
      );
      final remoteItems = response.data!
          .map((json) => _fromJson(json as Map<String, dynamic>, user))
          .toList();
      final remoteClientIds = remoteItems
          .map((message) => message.clientMessageId)
          .nonNulls
          .toSet();
      _messages[conversationId]?.removeWhere(
        (message) => remoteClientIds.contains(message.id),
      );
      final byId = <String, ChatMessage>{
        for (final message
            in _messages[conversationId] ?? const <ChatMessage>[])
          message.id: message,
        for (final message in remoteItems) message.id: message,
      };
      final items = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages[conversationId] = items;
      _controllers[conversationId]?.add(List.unmodifiable(items));
      for (final message in items) {
        _cacheMessage(message);
      }
      await _markRead(conversationId);
    } on DioException catch (error) {
      _controllers[conversationId]?.addError(Exception(_errorMessage(error)));
    }
  }

  ChatMessage _fromJson(Map<String, dynamic> json, User currentUser) {
    final sender = json['sender'] as Map<String, dynamic>;
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: sender['displayName'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      isMine: json['senderId'] == currentUser.id,
      clientMessageId: json['clientMessageId'] as String?,
      status: (json['status'] as String? ?? 'SENT').toUpperCase(),
    );
  }

  CachedMessage _toCache(ChatMessage message) {
    return CachedMessage(
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      createdAt: message.createdAt,
      status: message.status,
    );
  }

  void _cacheMessage(ChatMessage message) {
    try {
      _database.upsertMessage(_toCache(message));
    } catch (_) {
      // A cache failure must never prevent a server message reaching the UI.
    }
  }

  void _markCachedMessagesRead(Iterable<String> ids) {
    try {
      _database.markMessagesRead(ids);
    } catch (_) {
      // Read receipts remain valid in memory even if local persistence fails.
    }
  }

  ChatMessage _fromCache(CachedMessage message, User currentUser) {
    return ChatMessage(
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      createdAt: message.createdAt,
      isMine: message.senderId == currentUser.id,
      clientMessageId: null,
      status: message.status,
    );
  }

  Future<void> _markRead(String conversationId) async {
    await _client.dio.post<void>(
      '${ApiConstants.conversations}/$conversationId/read',
    );
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] != null
        ? data['message'].toString()
        : 'Unable to communicate with the server';
  }
}
