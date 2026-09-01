import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/database/local_chat_database.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/socket_client.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/registered_user.dart';
import '../../domain/repositories/conversation_repository.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl(this._client, this._socket, this._database);

  final DioClient _client;
  final SocketClient _socket;
  final LocalChatDatabase _database;
  final _controller = StreamController<List<ChatConversation>>.broadcast();
  List<ChatConversation> _conversations = const [];
  bool _presenceStarted = false;
  String? _currentUserId;

  @override
  Stream<List<ChatConversation>> watchConversations(String currentUserId) {
    _currentUserId = currentUserId;
    _conversations = _database
        .getConversations(currentUserId)
        .map(_fromCache)
        .toList();
    if (!_presenceStarted) {
      _presenceStarted = true;
      _socket.presenceStream.listen(_applyPresence);
      _socket.messageStream.listen(_applyIncomingMessage);
      _socket.readStream.listen(_applyReadReceipt);
    }
    unawaited(_load(currentUserId));
    return _watchWithInitial(List.unmodifiable(_conversations));
  }

  Stream<List<ChatConversation>> _watchWithInitial(
    List<ChatConversation> initial,
  ) async* {
    yield initial;
    yield* _controller.stream;
  }

  @override
  Future<ChatConversation?> getConversation(String id) async {
    final conversations = await _fetchConversations(_currentUserId);
    return conversations.where((item) => item.id == id).firstOrNull;
  }

  @override
  Future<void> seedIfNeeded({
    required String currentUserId,
    required String currentDisplayName,
  }) async {}

  Future<void> _load(String currentUserId) async {
    try {
      _conversations = await _fetchConversations(currentUserId);
      _database.replaceConversations(
        currentUserId,
        _conversations.map(_toCache).toList(),
      );
      _controller.add(List.unmodifiable(_conversations));
    } catch (error, stackTrace) {
      if (_conversations.isEmpty) {
        _controller.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<List<RegisteredUser>> getRegisteredUsers() async {
    try {
      final response = await _client.dio.get<List<dynamic>>(ApiConstants.users);
      return response.data!.map((value) {
        final json = value as Map<String, dynamic>;
        return RegisteredUser(
          id: json['id'] as String,
          username: json['username'] as String,
          displayName: json['displayName'] as String,
          avatarUrl: json['avatarUrl'] as String?,
          isOnline: json['isOnline'] as bool? ?? false,
          isIdle: json['presenceStatus'] == 'IDLE',
        );
      }).toList();
    } on DioException catch (error) {
      throw Exception(_message(error));
    }
  }

  @override
  Future<ChatConversation> createDirectConversation(String userId) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        ApiConstants.conversations,
        data: {
          'memberIds': [userId],
        },
      );
      final conversation = _fromJson(response.data!, _currentUserId);
      _conversations = [
        conversation,
        ..._conversations.where((item) => item.id != conversation.id),
      ];
      _persistConversations();
      _controller.add(List.unmodifiable(_conversations));
      return conversation;
    } on DioException catch (error) {
      throw Exception(_message(error));
    }
  }

  void _applyPresence(Map<String, dynamic> event) {
    final userId = event['userId'] as String?;
    final isOnline = event['isOnline'] as bool?;
    final isIdle = event['isIdle'] as bool? ?? event['status'] == 'IDLE';
    if (userId == null || isOnline == null) return;

    var changed = false;
    _conversations = _conversations.map((conversation) {
      if (conversation.peerId != userId ||
          (conversation.isOnline == isOnline &&
              conversation.isIdle == isIdle)) {
        return conversation;
      }
      changed = true;
      return conversation.copyWith(isOnline: isOnline, isIdle: isIdle);
    }).toList();
    if (changed) {
      _persistConversations();
      _controller.add(List.unmodifiable(_conversations));
    }
  }

  void _applyIncomingMessage(Map<String, dynamic> event) {
    final conversationId = event['conversationId'] as String?;
    if (conversationId == null) return;
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) {
      final userId = _currentUserId;
      if (userId != null) unawaited(_load(userId));
      return;
    }

    final updated = _conversations[index].copyWith(
      lastMessageId: event['id'] as String?,
      lastMessage: event['content'] as String?,
      lastMessageStatus: event['status'] as String?,
      lastMessageIsMine: event['senderId'] == _currentUserId,
      unreadCount: event['senderId'] == _currentUserId
          ? _conversations[index].unreadCount
          : _conversations[index].unreadCount + 1,
      lastMessageAt: event['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(event['createdAt'] as String).toLocal(),
    );
    _conversations = [
      updated,
      ..._conversations.where((item) => item.id != conversationId),
    ];
    _persistConversations();
    _controller.add(List.unmodifiable(_conversations));
  }

  void _applyReadReceipt(Map<String, dynamic> event) {
    final ids =
        (event['messageIds'] as List<dynamic>?)?.whereType<String>().toSet() ??
        const <String>{};
    var changed = false;
    _conversations = _conversations.map((conversation) {
      if (event['readBy'] == _currentUserId &&
          event['conversationId'] == conversation.id &&
          conversation.unreadCount > 0) {
        changed = true;
        return conversation.copyWith(unreadCount: 0);
      }
      if (!conversation.lastMessageIsMine ||
          !ids.contains(conversation.lastMessageId)) {
        return conversation;
      }
      changed = true;
      return conversation.copyWith(lastMessageStatus: 'READ');
    }).toList();
    if (changed) {
      _persistConversations();
      _controller.add(List.unmodifiable(_conversations));
    }
  }

  void _persistConversations() {
    final ownerId = _currentUserId;
    if (ownerId == null) return;
    _database.replaceConversations(
      ownerId,
      _conversations.map(_toCache).toList(),
    );
  }

  CachedConversation _toCache(ChatConversation item) {
    return CachedConversation(
      id: item.id,
      title: item.title,
      peerId: item.peerId,
      lastMessage: item.lastMessage,
      lastMessageId: item.lastMessageId,
      lastMessageStatus: item.lastMessageStatus,
      lastMessageIsMine: item.lastMessageIsMine,
      lastMessageAt: item.lastMessageAt,
      avatarUrl: item.avatarUrl,
      isOnline: item.isOnline,
      unreadCount: item.unreadCount,
    );
  }

  ChatConversation _fromCache(CachedConversation item) {
    return ChatConversation(
      id: item.id,
      title: item.title,
      peerId: item.peerId,
      lastMessage: item.lastMessage,
      lastMessageId: item.lastMessageId,
      lastMessageStatus: item.lastMessageStatus,
      lastMessageIsMine: item.lastMessageIsMine,
      lastMessageAt: item.lastMessageAt,
      avatarUrl: item.avatarUrl,
      isOnline: item.isOnline,
      isIdle: false,
      unreadCount: item.unreadCount,
    );
  }

  Future<List<ChatConversation>> _fetchConversations(
    String? currentUserId,
  ) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        ApiConstants.conversations,
      );
      return response.data!
          .map((json) => _fromJson(json as Map<String, dynamic>, currentUserId))
          .toList();
    } on DioException catch (error) {
      throw Exception(_message(error));
    }
  }

  ChatConversation _fromJson(Map<String, dynamic> json, String? currentUserId) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      peerId: json['peerId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      isIdle: json['presenceStatus'] == 'IDLE',
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastMessage: last?['content'] as String?,
      lastMessageId: last?['id'] as String?,
      lastMessageStatus: last?['status'] as String?,
      lastMessageIsMine: last?['senderId'] == currentUserId,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String).toLocal(),
    );
  }

  String _message(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] != null
        ? data['message'].toString()
        : 'Unable to load conversations';
  }
}
