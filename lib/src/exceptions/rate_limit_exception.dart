import 'puente_exception.dart';

class RateLimitException extends PuenteException {
  final Duration? retryAfter;

  const RateLimitException(super.message, {this.retryAfter});

  @override
  String toString() => 'RateLimitException: $message (Retry after: $retryAfter)';
}
