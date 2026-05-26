class PuenteException implements Exception {
  final String message;

  const PuenteException(this.message);

  @override
  String toString() => 'PuenteException: $message';
}
