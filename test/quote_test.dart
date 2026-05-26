import 'package:flutter_test/flutter_test.dart';
import 'package:puente_railway/puente_railway.dart';

void main() {
  test('Quote.fromJson correctly maps fields', () {
    final json = {
      "id": "qte_12345",
      "source_amount": {
        "amount": 10000,
        "currency": "USD"
      },
      "target_amount": {
        "amount": 197300,
        "currency": "MXN"
      },
      "exchange_rate": 19.73,
      "fee": {
        "amount": 150,
        "currency": "USD"
      },
      "expires_at": "2024-01-01T12:00:00Z"
    };

    final quote = Quote.fromJson(json);
    
    expect(quote.id, "qte_12345");
    expect(quote.sourceAmount, const Money(cents: 10000, currency: "USD"));
    expect(quote.targetAmount, const Money(cents: 197300, currency: "MXN"));
    expect(quote.exchangeRate, 19.73);
    expect(quote.fee, const Money(cents: 150, currency: "USD"));
    expect(quote.expiresAt, DateTime.utc(2024, 1, 1, 12, 0, 0));
  });
}
