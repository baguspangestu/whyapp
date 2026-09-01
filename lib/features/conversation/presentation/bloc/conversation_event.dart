part of 'conversation_bloc.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();

  @override
  List<Object> get props => [];
}

final class ConversationsStarted extends ConversationEvent {
  const ConversationsStarted();
}
