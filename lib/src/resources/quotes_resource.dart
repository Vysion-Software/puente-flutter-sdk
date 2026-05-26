import '../http/puente_http_client.dart';
import '../models/money.dart';
import '../models/quote.dart';

class QuotesResource {
  final PuenteHttpClient _client;

  QuotesResource(this._client);

  Future<Quote> create({
    required Money sourceAmount,
    required String sourceCurrency,
    required String targetCurrency,
  }) async {
    final response = await _client.post(
      '/quotes',
      body: {
        'source_amount': sourceAmount.toJson(),
        'source_currency': sourceCurrency,
        'target_currency': targetCurrency,
      },
    );
    return Quote.fromJson(response);
  }
}
