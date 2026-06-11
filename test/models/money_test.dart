import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('fromMinor + format on USD', () {
      const m = Money.fromMinor(1234, Currency.usd);
      expect(m.minorUnits, 1234);
      expect(m.currency, Currency.usd);
      expect(m.format(), '12.34 USD');
      expect(m.format(withCode: false), '12.34');
    });

    test('major helper handles whole-major amounts', () {
      final m = Money.major(50, Currency.usd);
      expect(m.minorUnits, 5000);
      expect(m.format(), '50.00 USD');
    });

    test('fromDecimal parses without floating-point loss', () {
      final m = Money.fromDecimal('0.1', Currency.usd) +
          Money.fromDecimal('0.2', Currency.usd);
      expect(m.minorUnits, 30); // exactly 0.30, not 0.30000000000000004
      expect(m.format(), '0.30 USD');
    });

    test('fromDecimal handles 6-decimal currencies', () {
      final m = Money.fromDecimal('1.234567', Currency.usdc);
      expect(m.minorUnits, 1234567);
      expect(m.format(), '1.234567 USDC');
    });

    test('fromDecimal truncates extra precision', () {
      // 0.12345 USD has more digits than USD has cents — last two
      // characters are dropped.
      final m = Money.fromDecimal('0.12345', Currency.usd);
      expect(m.minorUnits, 12);
    });

    test('fromDecimal rejects garbage', () {
      expect(() => Money.fromDecimal('', Currency.usd), throwsFormatException);
      expect(
          () => Money.fromDecimal('abc', Currency.usd), throwsFormatException);
      expect(() => Money.fromDecimal('1.2.3', Currency.usd),
          throwsFormatException);
      expect(
          () => Money.fromDecimal('.5', Currency.usd), throwsFormatException);
    });

    test('fromDecimal handles negative values', () {
      final m = Money.fromDecimal('-12.34', Currency.usd);
      expect(m.minorUnits, -1234);
      expect(m.isNegative, isTrue);
      expect(m.format(), '-12.34 USD');
    });

    test('addition + subtraction require same currency', () {
      const a = Money.fromMinor(1000, Currency.usd);
      const b = Money.fromMinor(500, Currency.usd);
      const c = Money.fromMinor(500, Currency.mxn);

      expect((a + b).minorUnits, 1500);
      expect((a - b).minorUnits, 500);
      expect(() => a + c, throwsA(isA<StateError>()));
      expect(() => a - c, throwsA(isA<StateError>()));
    });

    test('unary minus negates', () {
      const a = Money.fromMinor(1000, Currency.usd);
      expect((-a).minorUnits, -1000);
    });

    test('JSON round-trip preserves minor units + currency', () {
      const original = Money.fromMinor(1973, Currency.mxn);
      final encoded = original.toJson();
      expect(encoded, {'amount': 1973, 'currency': 'MXN'});
      final decoded = Money.fromJson(encoded);
      expect(decoded, original);
    });

    test('fromJson accepts legacy "cents" key', () {
      final m = Money.fromJson({'cents': 500, 'currency': 'USD'});
      expect(m.minorUnits, 500);
      expect(m.currency, Currency.usd);
    });

    test('fromJson throws on missing fields', () {
      expect(() => Money.fromJson({'currency': 'USD'}), throwsFormatException);
      expect(() => Money.fromJson({'amount': 1}), throwsFormatException);
    });

    test('CETES formats with 6 decimal places', () {
      const m = Money.fromMinor(1500000, Currency.cetes);
      expect(m.format(), '1.500000 CETES');
    });

    test('SOL formats with 9 decimal places', () {
      const m = Money.fromMinor(1500000000, Currency.sol);
      expect(m.format(), '1.500000000 SOL');
    });

    test('Currency.fromCode is case-insensitive', () {
      expect(Currency.fromCode('usd'), Currency.usd);
      expect(Currency.fromCode('MXN'), Currency.mxn);
      expect(() => Currency.fromCode('xxx'), throwsA(isA<ArgumentError>()));
      expect(Currency.tryFromCode('xxx'), isNull);
    });
  });
}
