import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('WebhookEventType', () {
    test('wire round-trip', () {
      for (final t in WebhookEventType.values) {
        expect(WebhookEventType.fromWire(t.wire), t);
      }
    });

    test('unknown wire value falls back to unknown', () {
      expect(WebhookEventType.fromWire('mystery'), WebhookEventType.unknown);
    });
  });

  group('WebhookEvent', () {
    test('fromJson reads event id when present', () {
      final e = WebhookEvent.fromJson({
        'id': 'evt_1',
        'type': 'transfer.settled',
        'data': {'id': 'tx_1'},
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(e.id, 'evt_1');
      expect(e.type, WebhookEventType.transferSettled);
      expect(e.data['id'], 'tx_1');
    });

    test('fromJson tolerates missing data object', () {
      final e = WebhookEvent.fromJson({
        'type': 'quote.expired',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(e.data, isEmpty);
    });
  });
}
