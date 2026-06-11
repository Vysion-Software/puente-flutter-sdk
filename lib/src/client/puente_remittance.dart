import '../models/currency.dart';
import '../models/money.dart';
import '../models/quote.dart';
import '../models/transfer.dart';
import '../resources/quotes_resource.dart';
import '../resources/transfers_resource.dart';

/// Result of a one-shot `PuenteRemittance.send` call.
class RemittanceResult {
  /// The quote consumed by the send.
  final Quote quote;

  /// The transfer Puente accepted. Watch its lifecycle with
  /// `PuenteClient.transfers.watch(id)`.
  final Transfer transfer;

  /// Build a [RemittanceResult].
  const RemittanceResult({required this.quote, required this.transfer});
}

/// High-level facade that fuses the `quote → transfer` pattern Pesito's
/// demo uses into a single call.
///
/// Lower-level resources ([QuotesResource], [TransfersResource]) remain
/// available for callers that want explicit control over the
/// intermediate quote (e.g. to display the FX rate to the user before
/// committing).
class PuenteRemittance {
  /// Build a [PuenteRemittance] facade.
  const PuenteRemittance({
    required QuotesResource quotes,
    required TransfersResource transfers,
  })  : _quotes = quotes,
        _transfers = transfers;

  final QuotesResource _quotes;
  final TransfersResource _transfers;

  /// Send [sourceAmount] in [sourceAmount.currency] to a beneficiary
  /// CLABE in [targetCurrency], in one round trip.
  ///
  /// The SDK calls `POST /quotes` then immediately `POST /transfers`
  /// against the returned quote id. Both calls share the same
  /// [idempotencyKey] (when supplied) so retries don't double-charge.
  /// When [idempotencyKey] is `null` the SDK generates two UUIDv4s
  /// internally.
  ///
  /// Throws the same typed exceptions as the underlying resources.
  Future<RemittanceResult> send({
    required Money sourceAmount,
    required Currency targetCurrency,
    required String receiverClabe,
    required String receiverName,
    String? memo,
    String? senderAccountId,
    String? idempotencyKey,
  }) async {
    final quote = await _quotes.create(
      sourceAmount: sourceAmount,
      targetCurrency: targetCurrency,
      idempotencyKey: idempotencyKey,
    );
    final transfer = await _transfers.create(
      quoteId: quote.id,
      receiverClabe: receiverClabe,
      receiverName: receiverName,
      memo: memo,
      senderAccountId: senderAccountId,
      idempotencyKey: idempotencyKey,
    );
    return RemittanceResult(quote: quote, transfer: transfer);
  }

  /// Watch a transfer's lifecycle. Forwarded to
  /// `TransfersResource.watch` for ergonomics.
  Stream<Transfer> watch(
    String transferId, {
    Duration pollInterval = const Duration(seconds: 1),
    Duration timeout = const Duration(minutes: 2),
  }) =>
      _transfers.watch(
        transferId,
        pollInterval: pollInterval,
        timeout: timeout,
      );
}
