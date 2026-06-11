import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('TransferStatus', () {
    test('wire round-trip', () {
      for (final s in TransferStatus.values) {
        expect(TransferStatus.fromWire(s.wire), s);
      }
    });

    test('unknown wire value falls back to unknown', () {
      expect(TransferStatus.fromWire('definitely-not-real'),
          TransferStatus.unknown);
      expect(TransferStatus.fromWire(null), TransferStatus.unknown);
    });

    test('isTerminal is true only for settled / failed / cancelled', () {
      expect(TransferStatus.pending.isTerminal, isFalse);
      expect(TransferStatus.processing.isTerminal, isFalse);
      expect(TransferStatus.unknown.isTerminal, isFalse);
      expect(TransferStatus.settled.isTerminal, isTrue);
      expect(TransferStatus.failed.isTerminal, isTrue);
      expect(TransferStatus.cancelled.isTerminal, isTrue);
    });
  });

  group('Transfer', () {
    test('fromJson decodes a full doc', () {
      final t = Transfer.fromJson({
        'id': 'tx_1',
        'status': 'processing',
        'source_amount': {'amount': 10000, 'currency': 'USD'},
        'target_amount': {'amount': 197300, 'currency': 'MXN'},
        'receiver_clabe': '012180012345678901',
        'receiver_name': 'María García López',
        'memo': 'Saludos',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:05Z',
        'reference': null,
      });
      expect(t.id, 'tx_1');
      expect(t.status, TransferStatus.processing);
      expect(t.receiverClabe, '012180012345678901');
      expect(t.memo, 'Saludos');
      expect(t.reference, isNull);
      expect(t.updatedAt!.isUtc, isTrue);
    });

    test('fromJson tolerates missing optional fields', () {
      final t = Transfer.fromJson({
        'id': 'tx_2',
        'status': 'pending',
        'source_amount': {'amount': 10000, 'currency': 'USD'},
        'target_amount': {'amount': 197300, 'currency': 'MXN'},
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(t.receiverClabe, isNull);
      expect(t.memo, isNull);
      expect(t.updatedAt, isNull);
      expect(t.reference, isNull);
    });
  });
}
