part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

final class ChatStarted extends ChatEvent {
  const ChatStarted();
}

final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.content);

  final String content;

  @override
  List<Object> get props => [content];
}
