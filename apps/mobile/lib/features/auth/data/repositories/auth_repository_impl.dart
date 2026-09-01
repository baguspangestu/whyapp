import '../../../../core/error/exceptions.dart';
import '../../../../core/network/socket_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._socketClient,
  );

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final SocketClient _socketClient;

  @override
  Future<User> login({
    required String username,
    required String password,
  }) async {
    final response = await _remoteDataSource.login(
      username: username,
      password: password,
    );

    await _persistSession(response);
    return response.user.toEntity();
  }

  @override
  Future<User> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final response = await _remoteDataSource.register(
      username: username,
      displayName: displayName,
      password: password,
    );

    await _persistSession(response);
    return response.user.toEntity();
  }

  @override
  Future<void> logout() async {
    _socketClient.disconnect();
    try {
      await _remoteDataSource.logout();
    } catch (_) {
      // Local session must still be cleared if remote logout fails.
    }

    await _localDataSource.clear();
  }

  @override
  Future<User?> getCurrentUser() async {
    final localUser = await _localDataSource.getCurrentUser();
    final tokens = await _localDataSource.getTokens();
    if (localUser == null || tokens == null) return null;

    try {
      final verifiedUser = await _remoteDataSource.getCurrentUser();
      await _localDataSource.saveUser(verifiedUser);
      final refreshedTokens = await _localDataSource.getTokens();
      if (refreshedTokens != null) {
        _socketClient.connect(accessToken: refreshedTokens.accessToken);
      }
      return verifiedUser.toEntity();
    } on AuthException catch (error) {
      if (error.statusCode == 401) {
        _socketClient.disconnect();
        await _localDataSource.clear();
        return null;
      }

      // Keep the last valid local session available while the server is
      // unreachable so cached conversations can still be read offline.
      _socketClient.connect(accessToken: tokens.accessToken);
      return localUser.toEntity();
    }
  }

  Future<void> _persistSession(AuthResponseModel response) async {
    await _localDataSource.saveUser(response.user);
    await _localDataSource.saveTokens(response.tokens);
    _socketClient.connect(accessToken: response.accessToken);
  }
}
