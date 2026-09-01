class ServerException implements Exception {
  const ServerException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  const NetworkException({this.message = 'No internet connection'});

  final String message;

  @override
  String toString() => message;
}

class CacheException implements Exception {
  const CacheException({this.message = 'Cache error'});

  final String message;

  @override
  String toString() => message;
}

class AuthException implements Exception {
  const AuthException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AppSocketException implements Exception {
  const AppSocketException({this.message = 'Socket connection error'});

  final String message;

  @override
  String toString() => message;
}
