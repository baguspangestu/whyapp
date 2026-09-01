// Public constructor labels intentionally differ from private field names.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/registered_user.dart';
import '../../domain/repositories/conversation_repository.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required ConversationRepository repository,
    required User currentUser,
  }) : _repository = repository,
       _currentUser = currentUser,
       super(const ConversationState()) {
    on<ConversationsStarted>(_onStarted);
  }

  final ConversationRepository _repository;
  final User _currentUser;

  Future<List<RegisteredUser>> getRegisteredUsers() {
    return _repository.getRegisteredUsers();
  }

  Future<ChatConversation> createDirectConversation(String userId) {
    return _repository.createDirectConversation(userId);
  }

  Future<void> _onStarted(
    ConversationsStarted event,
    Emitter<ConversationState> emit,
  ) async {
    emit(state.copyWith(status: ConversationStatus.loading));

    try {
      await _repository.seedIfNeeded(
        currentUserId: _currentUser.id,
        currentDisplayName: _currentUser.displayName,
      );

      await emit.forEach(
        _repository.watchConversations(_currentUser.id),
        onData: (conversations) => state.copyWith(
          status: ConversationStatus.ready,
          conversations: conversations,
        ),
        onError: (error, _) => state.copyWith(
          status: ConversationStatus.failure,
          message: error.toString(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ConversationStatus.failure,
          message: e.toString(),
        ),
      );
    }
  }
}
