/// Root exception type for everything the Puente Railway SDK can throw.
///
/// All other exceptions in the SDK (`ApiException`, `AuthException`,
/// `RateLimitException`, `ValidationException`, `TransportException`,
/// `WebhookException`) extend [PuenteException], so a single
/// `on PuenteException catch (e)` handler covers every SDK failure mode.
///
/// SDK calls **never** throw raw `Exception`, `dynamic`, or upstream package
/// errors — anything we catch internally is rewrapped as a [PuenteException]
/// subclass with a stable shape.
class PuenteException implements Exception {
  /// Human-readable message. Stable in shape but not part of the public
  /// API — don't string-match against this; use the typed subclass.
  final String message;

  /// Optional Puente-server request id (`X-Request-Id`). Surface this to
  /// users in support flows so a human can correlate a complaint with the
  /// server log.
  final String? requestId;

  /// Build a [PuenteException].
  const PuenteException(this.message, {this.requestId});

  @override
  String toString() {
    final ridPart = requestId == null ? '' : ' (request_id: $requestId)';
    return '$runtimeType: $message$ridPart';
  }
}
