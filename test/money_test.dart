import 'package:flutter_test/flutter_test.dart';
import 'package:puente_railway/puente_railway.dart';

void main() {
  group('Money', () {
    test('Arithmetic operations work for same currency', () {
      const m1 = Money(cents: 1000, currency: 'USD');
      const m2 = Money(cents: 500, currency: 'USD');
      
      expect(m1 + m2, const Money(cents: 1500, currency: 'USD'));
      expect(m1 - m2, const Money(cents: 500, currency: 'USD'));
    });

    test('Arithmetic operations throw for different currencies', () {
      const m1 = Money(cents: 1000, currency: 'USD');
      const m2 = Money(cents: 500, currency: 'MXN');
      
      expect(() => m1 + m2, throwsArgumentError);
      expect(() => m1 - m2, throwsArgumentError);
    });

    test('Formatting outputs correctly', () {
      const m = Money(cents: 1234, currency: 'USD');
      expect(m.format(), 'USD 12.34');
    });

    test('JSON round-trip', () {
      const m = Money(cents: 999, currency: 'MXN');
      final json = m.toJson();
      expect(json, {'amount': 999, 'currency': 'MXN'});
      expect(Money.fromJson(json), m);
    });
  });
}
