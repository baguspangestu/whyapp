import '../entities/user.dart';

abstract interface class AuthRepository {
  Future<User> login({required String username, required String password});

  Future<User> register({
    required String username,
    required String displayName,
    required String password,
  });

  Future<void> logout();

  Future<User?> getCurrentUser();
}
