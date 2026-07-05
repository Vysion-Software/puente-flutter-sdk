import 'puente_exception.dart';

/// Thrown when a [Quote] is submitted to `transfers.create*` past its
/// `expires_at`. Mapped from server `409 quote_expired` responses **and**
/// from the SDK's client-side guard in
/// `TransfersResource.createFromQuote`.
///
/// Callers should catch this distinctly from generic `ApiException`s so
/// the UI can re-quote and retry rather than surfacing a generic error.
class StaleQuoteException extends PuenteException {
  /// The quote id that was stale. May be empty when the exception is
  /// synthesized from a server 409 response that doesn't echo the id.
  final String quoteId;

  /// When the quote expired (server-provided; may be [DateTime.now] when
  /// synthesized server-side and no expiry echo is present).
  final DateTime expiresAt;

  /// When the SDK detected the staleness.
  final DateTime detectedAt;

  /// Whether this exception was raised by the SDK's client-side guard
  /// (`false`) or synthesized from a server 409 `quote_expired`
  /// response (`true`).
  final bool serverEmitted;

  /// Build a [StaleQuoteException] from the client-side pre-flight guard.
  StaleQuoteException.clientGuard({
    required this.quoteId,
    required this.expiresAt,
    required this.detectedAt,
    super.requestId,
  })  : serverEmitted = false,
        super('quote $quoteId expired at $expiresAt (detected at $detectedAt)');

  /// Build a [StaleQuoteException] from a server 409 `quote_expired`.
  StaleQuoteException.fromServer(super.message, {super.requestId})
      : quoteId = '',
        expiresAt = DateTime.now().toUtc(),
        detectedAt = DateTime.now().toUtc(),
        serverEmitted = true;

  /// Convenience constructor used only by ResourceBase to map plain 409
  /// responses without echoing the quote id. Prefer the named
  /// constructors elsewhere.
  factory StaleQuoteException(String serverMessage) =>
      StaleQuoteException.fromServer(serverMessage);
}
