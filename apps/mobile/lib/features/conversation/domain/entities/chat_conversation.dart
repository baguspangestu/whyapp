import 'package:equatable/equatable.dart';

class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.title,
    this.peerId,
    this.lastMessage,
    this.lastMessageId,
    this.lastMessageStatus,
    this.lastMessageIsMine = false,
    this.lastMessageAt,
    this.avatarUrl,
    this.isOnline = false,
    this.isIdle = false,
    this.unreadCount = 0,
  });

  final String id;
  final String title;
  final String? peerId;
  final String? lastMessage;
  final String? lastMessageId;
  final String? lastMessageStatus;
  final bool lastMessageIsMine;
  final DateTime? lastMessageAt;
  final String? avatarUrl;
  final bool isOnline;
  final bool isIdle;
  final int unreadCount;

  @override
  List<Object?> get props => [
    id,
    title,
    peerId,
    lastMessage,
    lastMessageId,
    lastMessageStatus,
    lastMessageIsMine,
    lastMessageAt,
    avatarUrl,
    isOnline,
    isIdle,
    unreadCount,
  ];

  ChatConversation copyWith({
    bool? isOnline,
    bool? isIdle,
    String? lastMessage,
    String? lastMessageId,
    String? lastMessageStatus,
    bool? lastMessageIsMine,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id,
      title: title,
      peerId: peerId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      lastMessageIsMine: lastMessageIsMine ?? this.lastMessageIsMine,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      avatarUrl: avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      isIdle: isIdle ?? this.isIdle,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
