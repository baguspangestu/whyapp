part of 'chat_bloc.dart';

enum ChatStatus { initial, loading, ready, failure }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.message,
  });

  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? message;

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? message,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, messages, message];
}
