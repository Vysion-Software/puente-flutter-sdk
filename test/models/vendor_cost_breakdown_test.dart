import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('VendorCostBreakdown', () {
    test('fromJson parses the backend wire shape', () {
      final vc = VendorCostBreakdown.fromJson({
        'etherfuse_minor': 42,
        'network_minor': 7,
        'other_minor': 0,
        'currency': 'USD',
      });
      expect(vc.etherfuse, const Money.fromMinor(42, Currency.usd));
      expect(vc.network, const Money.fromMinor(7, Currency.usd));
      expect(vc.other, const Money.fromMinor(0, Currency.usd));
    });

    test('equatable by value', () {
      const a = VendorCostBreakdown(
        etherfuse: Money.fromMinor(1, Currency.usd),
        network: Money.fromMinor(2, Currency.usd),
        other: Money.fromMinor(3, Currency.usd),
      );
      const b = VendorCostBreakdown(
        etherfuse: Money.fromMinor(1, Currency.usd),
        network: Money.fromMinor(2, Currency.usd),
        other: Money.fromMinor(3, Currency.usd),
      );
      expect(a, b);
    });
  });
}
