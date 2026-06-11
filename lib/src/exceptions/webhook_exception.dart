import 'puente_exception.dart';

/// Webhook signature verification failed.
///
/// Thrown by [WebhookVerifier.constructEvent] when the inbound signature
/// header is missing, malformed, stale, or doesn't match the expected
/// HMAC. Use [reason] to disambiguate cases for ops logs.
class WebhookException extends PuenteException {
  /// Machine-readable reason for the rejection.
  final WebhookFailureReason reason;

  /// Build a [WebhookException].
  const WebhookException(super.message, {required this.reason});

  @override
  String toString() => 'WebhookException(${reason.name}): $message';
}

/// Why a webhook was rejected by [WebhookVerifier].
enum WebhookFailureReason {
  /// Header value was empty or didn't parse as the expected format.
  malformedHeader,

  /// Signed timestamp is outside the configured tolerance.
  staleTimestamp,

  /// HMAC didn't match the expected digest.
  signatureMismatch,

  /// Payload was not valid JSON.
  invalidJson,

  /// Configuration-level error (e.g. missing secret).
  misconfigured,
}
