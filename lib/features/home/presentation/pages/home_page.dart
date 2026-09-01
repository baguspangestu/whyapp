import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../conversation/presentation/pages/conversations_page.dart';
import '../../../conversation/presentation/bloc/conversation_bloc.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final unreadChats = context
        .watch<ConversationBloc>()
        .state
        .conversations
        .where((conversation) => conversation.unreadCount > 0)
        .length;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ConversationsPage(), ProfilePage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: _ChatNavigationIcon(
              unreadChats: unreadChats,
              selected: false,
            ),
            selectedIcon: _ChatNavigationIcon(
              unreadChats: unreadChats,
              selected: true,
            ),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: user?.displayName ?? 'Profile',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _ChatNavigationIcon extends StatelessWidget {
  const _ChatNavigationIcon({
    required this.unreadChats,
    required this.selected,
  });

  final int unreadChats;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unreadChats > 0,
      label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
      child: Icon(
        selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
      ),
    );
  }
}
