import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  Future<User> call({required String username, required String password}) {
    return _repository.login(username: username, password: password);
  }
}
