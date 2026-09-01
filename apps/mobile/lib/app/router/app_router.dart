import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/conversation/domain/entities/chat_conversation.dart';
import '../../features/conversation/presentation/bloc/conversation_bloc.dart';
import '../../features/home/presentation/pages/home_page.dart';
import 'go_router_refresh.dart';

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';
      final isSplash = location == '/splash';

      if (auth.status == AuthStatus.initial) {
        return isSplash ? null : '/splash';
      }

      if (auth.status == AuthStatus.loading && auth.user == null) {
        if (isAuthRoute) {
          return null;
        }
        return isSplash ? null : '/splash';
      }

      if (auth.status == AuthStatus.authenticated) {
        if (isAuthRoute || isSplash) {
          return '/home';
        }
        return null;
      }

      if (!isAuthRoute) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final user = authBloc.state.user;
          if (user == null) {
            return const _SplashPage();
          }

          return BlocProvider(
            create: (_) => ConversationBloc(
              repository: getIt(),
              currentUser: user,
            )..add(const ConversationsStarted()),
            child: const HomePage(),
          );
        },
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final user = authBloc.state.user;
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          final conversation = extra is ChatConversation ? extra : null;

          if (user == null) {
            return const NoTransitionPage(child: _SplashPage());
          }

          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            child: BlocProvider(
              create: (_) => ChatBloc(
                repository: getIt(),
                currentUser: user,
                conversationId: id,
              )..add(const ChatStarted()),
              child: ChatPage(
                conversationId: id,
                title: conversation?.title ?? 'Chat',
                isOnline: conversation?.isOnline ?? false,
                isIdle: conversation?.isIdle ?? false,
                peerId: conversation?.peerId,
                avatarUrl: conversation?.avatarUrl,
              ),
            ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.14, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.86, end: 1).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
