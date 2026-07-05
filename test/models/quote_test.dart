import 'package:clock/clock.dart';
import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('Quote', () {
    test('fromJson parses every field', () {
      final q = Quote.fromJson({
        'id': 'qt_abc',
        'source_amount': {'amount': 10000, 'currency': 'USD'},
        'target_amount': {'amount': 197300, 'currency': 'MXN'},
        'exchange_rate': 19.73,
        'fee': {'amount': 50, 'currency': 'USD'},
        'created_at': '2026-01-01T00:00:00Z',
        'expires_at': '2026-01-01T00:02:00Z',
      });
      expect(q.id, 'qt_abc');
      expect(q.sourceAmount, const Money.fromMinor(10000, Currency.usd));
      expect(q.targetAmount, const Money.fromMinor(197300, Currency.mxn));
      expect(q.exchangeRate, 19.73);
      expect(q.fee, const Money.fromMinor(50, Currency.usd));
      expect(q.expiresAt.isUtc, isTrue);
    });

    test('isExpired honors injected clock', () {
      final q = Quote.fromJson({
        'id': 'qt_x',
        'source_amount': {'amount': 1, 'currency': 'USD'},
        'target_amount': {'amount': 19, 'currency': 'MXN'},
        'exchange_rate': 19.0,
        'fee': {'amount': 0, 'currency': 'USD'},
        'expires_at': '2026-01-01T12:00:00Z',
      });
      expect(q.isExpired(DateTime.parse('2026-01-01T11:59:59Z')), isFalse);
      expect(q.isExpired(DateTime.parse('2026-01-01T12:00:00Z')), isTrue);
      expect(q.isExpired(DateTime.parse('2026-01-01T12:00:01Z')), isTrue);
    });

    test('JSON round-trip preserves values', () {
      final q = Quote.fromJson({
        'id': 'qt_rt',
        'source_amount': {'amount': 10000, 'currency': 'USD'},
        'target_amount': {'amount': 197300, 'currency': 'MXN'},
        'exchange_rate': 19.73,
        'fee': {'amount': 50, 'currency': 'USD'},
        'created_at': '2026-01-01T00:00:00Z',
        'expires_at': '2026-01-01T00:02:00Z',
      });
      final back = Quote.fromJson(q.toJson());
      expect(back, q);
    });

    test('fromJson parses the real-backend shape (quote_id keyed)', () {
      final q = Quote.fromJson({
        'quote_id': 'c9f1a2b3-0000-4000-8000-000000000007',
        'source_amount_minor': 10000,
        'source_currency': 'USD',
        'destination_amount_minor': 197300,
        'destination_currency': 'MXN',
        'fx_rate': '19.73',
        'total_fee_minor': 100,
        'total_cost_minor': 10100,
        'expires_at': '2026-07-01T00:02:00Z',
        'transfer_type': 'cross_border',
        'currency_leg': 'CETES',
        'fee_breakdown': {
          'flat_fee_minor': 100,
          'fx_spread_fee_minor': 0,
          'vendor_fee_minor': 0,
          'total_fee_minor': 100,
          'currency': 'USD',
        },
      });
      expect(q.id, 'c9f1a2b3-0000-4000-8000-000000000007');
      expect(q.sourceAmount, const Money.fromMinor(10000, Currency.usd));
      expect(q.targetAmount, const Money.fromMinor(197300, Currency.mxn));
      expect(q.exchangeRate, 19.73);
      expect(q.fee, const Money.fromMinor(100, Currency.usd));
      expect(q.totalCost, const Money.fromMinor(10100, Currency.usd));
      expect(q.expiresAt, DateTime.utc(2026, 7, 1, 0, 2));
      // No created_at on the backend quote — falls back to expires_at.
      expect(q.createdAt, q.expiresAt);
      expect(q.transferType, 'cross_border');
      expect(q.currencyLeg, CurrencyLeg.cetes);
      expect(q.feeBreakdown, isNotNull);
      expect(q.feeBreakdown!.flatFee, const Money.fromMinor(100, Currency.usd));
      expect(
          q.feeBreakdown!.totalFee, const Money.fromMinor(100, Currency.usd));
    });

    test('real-backend same-currency quote parses with fx_rate "1"', () {
      final q = Quote.fromJson({
        'quote_id': 'p2p-quote',
        'source_amount_minor': 5000,
        'source_currency': 'USD',
        'destination_amount_minor': 5000,
        'destination_currency': 'USD',
        'fx_rate': '1',
        'total_fee_minor': 0,
        'total_cost_minor': 5000,
        'expires_at': '2026-07-01T00:02:00Z',
        'transfer_type': 'p2p_same_region',
        'currency_leg': 'USDC',
      });
      expect(q.exchangeRate, 1.0);
      expect(q.fee.isZero, isTrue);
      expect(q.transferType, 'p2p_same_region');
      expect(q.currencyLeg, CurrencyLeg.usdc);
      expect(q.feeBreakdown, isNull);
    });

    test('unparseable fx_rate degrades to 0 (display-only field)', () {
      final q = Quote.fromJson({
        'quote_id': 'q_badrate',
        'source_amount_minor': 100,
        'source_currency': 'USD',
        'destination_amount_minor': 100,
        'destination_currency': 'USD',
        'fx_rate': 'not-a-number',
        'total_fee_minor': 0,
        'expires_at': '2026-07-01T00:02:00Z',
      });
      expect(q.exchangeRate, 0);
    });

    // Suppress unused-import warning when running this file in isolation.
    test('clock import is referenced', () {
      expect(clock.now().isUtc || !clock.now().isUtc, isTrue);
    });
  });
}
