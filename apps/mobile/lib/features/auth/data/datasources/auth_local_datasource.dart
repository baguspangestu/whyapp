import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

abstract interface class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);

  Future<UserModel?> getCurrentUser();

  Future<void> saveTokens(AuthTokensModel tokens);

  Future<AuthTokensModel?> getTokens();

  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<void> saveUser(UserModel user) async {
    final saved = await _prefs.setString(
      StorageConstants.user,
      jsonEncode(user.toJson()),
    );
    if (!saved) {
      throw const CacheException(message: 'Could not save user session');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final raw = _prefs.getString(StorageConstants.user);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const CacheException(message: 'Could not read user session');
    }
  }

  @override
  Future<void> saveTokens(AuthTokensModel tokens) async {
    await _prefs.setString(StorageConstants.accessToken, tokens.accessToken);
    if (tokens.refreshToken == null) {
      await _prefs.remove(StorageConstants.refreshToken);
    } else {
      await _prefs.setString(
        StorageConstants.refreshToken,
        tokens.refreshToken!,
      );
    }
  }

  @override
  Future<AuthTokensModel?> getTokens() async {
    final accessToken = _prefs.getString(StorageConstants.accessToken);
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    return AuthTokensModel(
      accessToken: accessToken,
      refreshToken: _prefs.getString(StorageConstants.refreshToken),
    );
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(StorageConstants.user);
    await _prefs.remove(StorageConstants.accessToken);
    await _prefs.remove(StorageConstants.refreshToken);
  }
}
