import 'puente_exception.dart';

/// Thrown when a [Quote] is submitted to `transfers.create*` past its
/// `expires_at`. Mapped from server `409 quote_expired` responses **and**
/// from the SDK's client-side guard in
/// `TransfersResource.createFromQuote`.
///
/// Callers should catch this distinctly from generic `ApiException`s so
/// the UI can re-quote and retry rather than surfacing a generic error.
class StaleQuoteException extends PuenteException {
  /// The quote id that was stale.
  final String quoteId;

  /// When the quote expired (server-provided).
  final DateTime expiresAt;

  /// When the SDK detected the staleness.
  final DateTime detectedAt;

  /// Build a [StaleQuoteException].
  const StaleQuoteException({
    required this.quoteId,
    required this.expiresAt,
    required this.detectedAt,
    super.requestId,
  }) : super('quote $quoteId expired at $expiresAt (detected at $detectedAt)');
}
