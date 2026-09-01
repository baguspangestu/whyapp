import 'package:equatable/equatable.dart';

class RegisteredUser extends Equatable {
  const RegisteredUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isOnline = false,
    this.isIdle = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isOnline;
  final bool isIdle;

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    avatarUrl,
    isOnline,
    isIdle,
  ];
}
