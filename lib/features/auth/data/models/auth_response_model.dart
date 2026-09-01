import 'auth_tokens_model.dart';
import 'user_model.dart';

class AuthResponseModel {
  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  final UserModel user;
  final String accessToken;
  final String? refreshToken;

  AuthTokensModel get tokens =>
      AuthTokensModel(accessToken: accessToken, refreshToken: refreshToken);
}
