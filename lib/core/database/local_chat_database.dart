import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class CachedConversation {
  const CachedConversation({
    required this.id,
    required this.title,
    required this.isOnline,
    required this.lastMessageIsMine,
    this.unreadCount = 0,
    this.peerId,
    this.lastMessage,
    this.lastMessageId,
    this.lastMessageStatus,
    this.lastMessageAt,
    this.avatarUrl,
  });

  final String id;
  final String title;
  final String? peerId;
  final String? lastMessage;
  final String? lastMessageId;
  final String? lastMessageStatus;
  final bool lastMessageIsMine;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String? avatarUrl;
  final bool isOnline;
}

class CachedMessage {
  const CachedMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final String status;
}

class LocalChatDatabase {
  Database? _database;

  Database get _db => _database!;

  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'whyapp_cache.sqlite'));
    _database = sqlite3.open(file.path);
    _db.execute('''
      CREATE TABLE IF NOT EXISTS conversations (
        owner_id TEXT NOT NULL,
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        peer_id TEXT,
        last_message TEXT,
        last_message_id TEXT,
        last_message_status TEXT,
        last_message_is_mine INTEGER NOT NULL DEFAULT 0,
        last_message_at INTEGER,
        avatar_url TEXT,
        is_online INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_id, id)
      )
    ''');
    final conversationColumns = _db
        .select('PRAGMA table_info(conversations)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!conversationColumns.contains('unread_count')) {
      _db.execute(
        'ALTER TABLE conversations ADD COLUMN unread_count INTEGER '
        'NOT NULL DEFAULT 0',
      );
    }
    _db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS messages_conversation_at '
      'ON messages(conversation_id, created_at)',
    );
  }

  List<CachedConversation> getConversations(String ownerId) {
    final rows = _db.select(
      'SELECT * FROM conversations WHERE owner_id = ? '
      'ORDER BY last_message_at DESC',
      [ownerId],
    );
    return rows.map((row) => CachedConversation(
      id: row['id'] as String,
      title: row['title'] as String,
      peerId: row['peer_id'] as String?,
      lastMessage: row['last_message'] as String?,
      lastMessageId: row['last_message_id'] as String?,
      lastMessageStatus: row['last_message_status'] as String?,
      lastMessageIsMine: row['last_message_is_mine'] == 1,
      lastMessageAt: row['last_message_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['last_message_at'] as int),
      avatarUrl: row['avatar_url'] as String?,
      isOnline: row['is_online'] == 1,
      unreadCount: row['unread_count'] as int? ?? 0,
    )).toList();
  }

  void replaceConversations(
    String ownerId,
    List<CachedConversation> conversations,
  ) {
    _db.execute('BEGIN');
    try {
      _db.execute('DELETE FROM conversations WHERE owner_id = ?', [ownerId]);
      for (final item in conversations) {
        upsertConversation(ownerId, item);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void upsertConversation(String ownerId, CachedConversation item) {
    _db.execute('''
      INSERT OR REPLACE INTO conversations (
        owner_id, id, title, peer_id, last_message, last_message_id,
        last_message_status, last_message_is_mine, last_message_at,
        avatar_url, is_online, unread_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      ownerId,
      item.id,
      item.title,
      item.peerId,
      item.lastMessage,
      item.lastMessageId,
      item.lastMessageStatus,
      item.lastMessageIsMine ? 1 : 0,
      item.lastMessageAt?.millisecondsSinceEpoch,
      item.avatarUrl,
      item.isOnline ? 1 : 0,
      item.unreadCount,
    ]);
  }

  List<CachedMessage> getMessages(String conversationId) {
    final rows = _db.select(
      'SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at',
      [conversationId],
    );
    return rows.map((row) => CachedMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String,
      content: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      status: row['status'] as String,
    )).toList();
  }

  void replaceMessages(String conversationId, List<CachedMessage> messages) {
    _db.execute('BEGIN');
    try {
      _db.execute('DELETE FROM messages WHERE conversation_id = ?', [conversationId]);
      for (final message in messages) {
        upsertMessage(message);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void upsertMessage(CachedMessage message) {
    _db.execute('''
      INSERT OR REPLACE INTO messages (
        id, conversation_id, sender_id, sender_name, content, created_at, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      message.id,
      message.conversationId,
      message.senderId,
      message.senderName,
      message.content,
      message.createdAt.millisecondsSinceEpoch,
      message.status,
    ]);
  }

  void markMessagesRead(Iterable<String> ids) {
    final statement = _db.prepare('UPDATE messages SET status = ? WHERE id = ?');
    try {
      for (final id in ids) {
        statement.execute(['READ', id]);
      }
    } finally {
      statement.close();
    }
  }

  void close() {
    _database?.close();
    _database = null;
  }
}
