import '../models/currency.dart';
import '../models/money.dart';
import '../models/quote.dart';
import '../transport/puente_request.dart';
import 'resource_base.dart';

/// `POST /v1/quotes` — get a short-lived FX + fee quote for a
/// cross-currency send.
///
/// Quotes are stateless and free; create as many as you like. To convert
/// a quote into a real movement, pass [Quote.id] to
/// `TransfersResource.create`.
class QuotesResource extends ResourceBase {
  /// Build a [QuotesResource].
  QuotesResource(super.transport);

  /// Create a quote.
  ///
  /// [sourceAmount] is what the sender will be debited; the server
  /// returns a [Quote] with the matching [Quote.targetAmount] and
  /// [Quote.fee] in the source currency.
  ///
  /// Pass [idempotencyKey] to dedup repeated quote requests for the
  /// same UX gesture (e.g. tapping "preview" twice). The SDK generates
  /// one automatically if you don't.
  Future<Quote> create({
    required Money sourceAmount,
    required Currency targetCurrency,
    String? idempotencyKey,
  }) async {
    final response = await request(PuenteRequest(
      method: 'POST',
      path: '/quotes',
      body: <String, dynamic>{
        'source_amount': sourceAmount.toJson(),
        'source_currency': sourceAmount.currency.code,
        'target_currency': targetCurrency.code,
      },
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
    ));
    return Quote.fromJson(response.jsonObject);
  }
}
