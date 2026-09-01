import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/chat_message.dart';

abstract interface class ChatRepository {
  Stream<List<ChatMessage>> watchMessages({
    required String conversationId,
    required User currentUser,
  });

  Future<void> sendMessage({
    required String conversationId,
    required User currentUser,
    required String content,
  });
}
