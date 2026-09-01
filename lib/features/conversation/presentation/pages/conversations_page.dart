import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/presence_avatar.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/registered_user.dart';
import '../bloc/conversation_bloc.dart';
import '../widgets/conversation_tile.dart';

class ConversationsPage extends StatelessWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WhyApp',
          style: TextStyle(
            color: Color(0xFFE91E63),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new-group', child: Text('New group')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: true),
                  const SizedBox(width: 8),
                  const _FilterChip(label: 'Unread'),
                  const SizedBox(width: 8),
                  const _FilterChip(label: 'Groups'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New chat',
        onPressed: () => _showNewChat(context),
        elevation: 1,
        child: const Icon(Icons.chat_rounded),
      ),
      body: BlocBuilder<ConversationBloc, ConversationState>(
        builder: (context, state) {
          if (state.status == ConversationStatus.loading ||
              state.status == ConversationStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ConversationStatus.failure) {
            return Center(child: Text(state.message ?? 'Could not load chats'));
          }

          if (state.conversations.isEmpty) {
            return const Center(child: Text('No conversations yet'));
          }

          return ListView.separated(
            itemCount: state.conversations.length,
            padding: const EdgeInsets.only(top: 6, bottom: 88),
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final conversation = state.conversations[index];
              return ConversationTile(
                conversation: conversation,
                onTap: () => _openChat(context, conversation),
              );
            },
          );
        },
      ),
    );
  }

  void _openChat(BuildContext context, ChatConversation conversation) {
    context.push('/chat/${conversation.id}', extra: conversation);
  }

  Future<void> _showNewChat(BuildContext context) async {
    final bloc = context.read<ConversationBloc>();
    final conversation = await showModalBottomSheet<ChatConversation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _NewChatSheet(
        loadUsers: bloc.getRegisteredUsers,
        createConversation: bloc.createDirectConversation,
      ),
    );
    if (conversation != null && context.mounted) {
      _openChat(context, conversation);
    }
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({
    required this.loadUsers,
    required this.createConversation,
  });

  final Future<List<RegisteredUser>> Function() loadUsers;
  final Future<ChatConversation> Function(String userId) createConversation;

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  late Future<List<RegisteredUser>> _users;
  String _query = '';
  String? _openingUserId;

  @override
  void initState() {
    super.initState();
    _users = widget.loadUsers();
  }

  void _retry() {
    setState(() => _users = widget.loadUsers());
  }

  Future<void> _open(RegisteredUser user) async {
    if (_openingUserId != null) return;
    setState(() => _openingUserId = user.id);
    try {
      final conversation = await widget.createConversation(user.id);
      if (mounted) Navigator.of(context).pop(conversation);
    } catch (error) {
      if (!mounted) return;
      setState(() => _openingUserId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'New chat',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchBar(
              hintText: 'Search name or username',
              leading: const Icon(Icons.search_rounded),
              elevation: WidgetStatePropertyAll(1),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<RegisteredUser>>(
              future: _users,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _UsersError(onRetry: _retry);
                }
                final users = (snapshot.data ?? const <RegisteredUser>[])
                    .where(
                      (user) =>
                          _query.isEmpty ||
                          user.displayName.toLowerCase().contains(_query) ||
                          user.username.toLowerCase().contains(_query),
                    )
                    .toList();
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No other registered users yet'
                          : 'No users found',
                    ),
                  );
                }
                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final opening = _openingUserId == user.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: PresenceAvatar(
                        name: user.displayName,
                        imageUrl: user.avatarUrl,
                        isOnline: user.isOnline,
                        isIdle: user.isIdle,
                      ),
                      title: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('@${user.username}'),
                      trailing: opening
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      enabled: _openingUserId == null,
                      onTap: () => _open(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersError extends StatelessWidget {
  const _UsersError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          const SizedBox(height: 12),
          const Text('Could not load registered users'),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      onSelected: (_) {},
      visualDensity: VisualDensity.compact,
    );
  }
}
