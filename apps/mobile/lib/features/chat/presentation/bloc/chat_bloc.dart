// Public constructor labels intentionally differ from private field names.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required ChatRepository repository,
    required User currentUser,
    required String conversationId,
  }) : _repository = repository,
       _currentUser = currentUser,
       _conversationId = conversationId,
       super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessageSent>(_onMessageSent);
  }

  final ChatRepository _repository;
  final User _currentUser;
  final String _conversationId;

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(state.copyWith(status: ChatStatus.loading));

    await emit.forEach(
      _repository.watchMessages(
        conversationId: _conversationId,
        currentUser: _currentUser,
      ),
      onData: (messages) =>
          state.copyWith(status: ChatStatus.ready, messages: messages),
      onError: (error, _) =>
          state.copyWith(status: ChatStatus.failure, message: error.toString()),
    );
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final content = event.content.trim();
    if (content.isEmpty) {
      return;
    }

    try {
      await _repository.sendMessage(
        conversationId: _conversationId,
        currentUser: _currentUser,
        content: content,
      );
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.failure, message: e.toString()));
    }
  }
}
