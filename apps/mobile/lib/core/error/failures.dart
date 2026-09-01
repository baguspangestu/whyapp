sealed class Failure {
  final String message;

  const Failure(this.message);
}

final class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode});
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class SocketFailure extends Failure {
  const SocketFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
