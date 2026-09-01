abstract final class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.2.3:3000/api/',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://192.168.2.3:3000',
  );

  // Auth
  static const String login = 'auth/login';
  static const String register = 'auth/register';
  static const String logout = 'auth/logout';
  static const String refresh = 'auth/refresh';

  // User
  static const String users = 'users';
  static const String profile = 'users/me';

  // Chat
  static const String conversations = 'conversations';
  static const String messages = 'messages';
}
