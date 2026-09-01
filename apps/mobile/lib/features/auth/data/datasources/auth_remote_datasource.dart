import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String username,
    required String displayName,
    required String password,
  });

  Future<void> logout();

  Future<UserModel> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._client);

  final DioClient _client;

  @override
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    return _request(ApiConstants.login, {
      'username': username.trim(),
      'password': password,
    });
  }

  @override
  Future<AuthResponseModel> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    return _request(ApiConstants.register, {
      'username': username.trim(),
      'displayName': displayName.trim(),
      'password': password,
    });
  }

  @override
  Future<void> logout() async {
    await _client.dio.post<void>(ApiConstants.logout);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        ApiConstants.profile,
      );
      return UserModel.fromJson(response.data!);
    } on DioException catch (error) {
      throw AuthException(
        message: _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<AuthResponseModel> _request(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      final data = response.data!;
      return AuthResponseModel(
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String?,
      );
    } on DioException catch (error) {
      throw AuthException(
        message: _errorMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    final message = data is Map ? data['message'] : null;
    return message is List
        ? message.join(', ')
        : message?.toString() ?? 'Unable to connect to the server';
  }
}
