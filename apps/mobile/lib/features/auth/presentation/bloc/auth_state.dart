part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

class AuthState {
  const AuthState({this.status = AuthStatus.initial, this.user, this.message});

  final AuthStatus status;
  final User? user;
  final String? message;

  AuthState copyWith({AuthStatus? status, User? user, String? message}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      message: message,
    );
  }
}
