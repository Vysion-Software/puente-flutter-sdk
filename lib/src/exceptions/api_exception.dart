import 'puente_exception.dart';

class ApiException extends PuenteException {
  final int statusCode;
  final String? requestId;

  const ApiException(
    String message, {
    required this.statusCode,
    this.requestId,
  }) : super(message);

  @override
  String toString() => 'ApiException [$statusCode]: $message (Request ID: $requestId)';
}
