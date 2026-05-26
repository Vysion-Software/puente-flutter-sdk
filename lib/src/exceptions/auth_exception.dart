import 'puente_exception.dart';

class AuthException extends PuenteException {
  const AuthException(super.message);

  @override
  String toString() => 'AuthException: $message';
}
