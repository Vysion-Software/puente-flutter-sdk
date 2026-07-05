import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('FeeBreakdown', () {
    test('fromJson parses the backend wire shape', () {
      final fb = FeeBreakdown.fromJson({
        'flat_fee_minor': 100,
        'fx_spread_fee_minor': 25,
        'vendor_fee_minor': 10,
        'total_fee_minor': 135,
        'currency': 'USD',
      });
      expect(fb.flatFee, const Money.fromMinor(100, Currency.usd));
      expect(fb.fxSpreadFee, const Money.fromMinor(25, Currency.usd));
      expect(fb.vendorFee, const Money.fromMinor(10, Currency.usd));
      expect(fb.totalFee, const Money.fromMinor(135, Currency.usd));
    });

    test('totalFee is wire truth — never summed locally', () {
      // If the backend total disagrees with the components, the backend
      // total wins: the SDK must not "correct" it.
      final fb = FeeBreakdown.fromJson({
        'flat_fee_minor': 1,
        'fx_spread_fee_minor': 1,
        'vendor_fee_minor': 1,
        'total_fee_minor': 999,
        'currency': 'MXN',
      });
      expect(fb.totalFee, const Money.fromMinor(999, Currency.mxn));
    });

    test('toJson round-trips through fromJson', () {
      const fb = FeeBreakdown(
        flatFee: Money.fromMinor(100, Currency.usd),
        fxSpreadFee: Money.fromMinor(0, Currency.usd),
        vendorFee: Money.fromMinor(0, Currency.usd),
        totalFee: Money.fromMinor(100, Currency.usd),
      );
      expect(FeeBreakdown.fromJson(fb.toJson()), fb);
      expect(fb.toJson(), {
        'flat_fee_minor': 100,
        'fx_spread_fee_minor': 0,
        'vendor_fee_minor': 0,
        'total_fee_minor': 100,
        'currency': 'USD',
      });
    });
  });
}
