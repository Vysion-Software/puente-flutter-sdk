import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('TransferIntent', () {
    test('toJson emits the exact cross-border POST /v1/transfers body', () {
      const intent = TransferIntent(
        quoteId: 'a3d1c2f4-0000-4000-8000-000000000001',
        receiverName: 'María García López',
        receiverClabe: '012180012345678901',
        memo: 'Para la familia',
      );
      expect(intent.toJson(), {
        'quote_id': 'a3d1c2f4-0000-4000-8000-000000000001',
        'receiver_name': 'María García López',
        'receiver_clabe': '012180012345678901',
        'memo': 'Para la familia',
      });
    });

    test('toJson emits the exact P2P body with both user ids', () {
      const intent = TransferIntent(
        quoteId: 'q_p2p',
        receiverName: 'Ana López',
        senderUserId: 'user_sender',
        receiverUserId: 'user_receiver',
      );
      expect(intent.toJson(), {
        'quote_id': 'q_p2p',
        'receiver_name': 'Ana López',
        'sender_user_id': 'user_sender',
        'receiver_user_id': 'user_receiver',
      });
    });

    test('null optionals are omitted entirely, never sent as null', () {
      const intent = TransferIntent(quoteId: 'q_min', receiverName: 'Ana');
      final json = intent.toJson();
      expect(json.keys, unorderedEquals(['quote_id', 'receiver_name']));
    });

    test('carries no monetary fields — amounts come from the quote', () {
      const intent = TransferIntent(quoteId: 'q_x', receiverName: 'Ana');
      final json = intent.toJson();
      expect(json.keys.where((k) => k.contains('amount')), isEmpty);
      expect(json.keys.where((k) => k.contains('fee')), isEmpty);
      expect(json.keys.where((k) => k.contains('rate')), isEmpty);
    });
  });
}
