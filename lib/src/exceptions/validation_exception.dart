import 'puente_exception.dart';

class ValidationException extends PuenteException {
  final Map<String, String> fieldErrors;

  const ValidationException(super.message, {required this.fieldErrors});

  @override
  String toString() => 'ValidationException: $message. Field errors: $fieldErrors';
}
