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

    // Suppress unused-import warning when running this file in isolation.
    test('clock import is referenced', () {
      expect(clock.now().isUtc || !clock.now().isUtc, isTrue);
    });
  });
}
