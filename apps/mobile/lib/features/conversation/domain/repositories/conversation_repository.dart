import '../../domain/entities/chat_conversation.dart';
import '../entities/registered_user.dart';

abstract interface class ConversationRepository {
  Stream<List<ChatConversation>> watchConversations(String currentUserId);

  Future<ChatConversation?> getConversation(String id);

  Future<List<RegisteredUser>> getRegisteredUsers();

  Future<ChatConversation> createDirectConversation(String userId);

  Future<void> seedIfNeeded({
    required String currentUserId,
    required String currentDisplayName,
  });
}
