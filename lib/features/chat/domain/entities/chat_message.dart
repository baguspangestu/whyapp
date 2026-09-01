import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.clientMessageId,
    this.status = 'SENT',
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final bool isMine;
  final String? clientMessageId;
  final String status;

  bool get isRead => status == 'READ';
  bool get isDelivered => status == 'DELIVERED' || isRead;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    senderName,
    content,
    createdAt,
    isMine,
    clientMessageId,
    status,
  ];

  ChatMessage copyWith({String? status}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: createdAt,
      isMine: isMine,
      clientMessageId: clientMessageId,
      status: status ?? this.status,
    );
  }
}
