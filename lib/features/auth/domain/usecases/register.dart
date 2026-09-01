import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Register {
  const Register(this._repository);

  final AuthRepository _repository;

  Future<User> call({
    required String username,
    required String displayName,
    required String password,
  }) {
    return _repository.register(
      username: username,
      displayName: displayName,
      password: password,
    );
  }
}
