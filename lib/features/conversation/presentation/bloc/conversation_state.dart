part of 'conversation_bloc.dart';

enum ConversationStatus { initial, loading, ready, failure }

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ConversationStatus.initial,
    this.conversations = const [],
    this.message,
  });

  final ConversationStatus status;
  final List<ChatConversation> conversations;
  final String? message;

  ConversationState copyWith({
    ConversationStatus? status,
    List<ChatConversation>? conversations,
    String? message,
  }) {
    return ConversationState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, conversations, message];
}
