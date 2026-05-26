import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puente_railway/puente_railway.dart';

void main() {
  group('WebhookVerifier', () {
    const secret = 'whsec_test_secret';
    final verifier = WebhookVerifier(secret: secret);

    String generateSignature(String payload, int timestamp, String testSecret) {
      final signedPayload = '$timestamp.$payload';
      final hmac = Hmac(sha256, utf8.encode(testSecret));
      final digest = hmac.convert(utf8.encode(signedPayload));
      return 't=$timestamp,v1=${digest.toString()}';
    }

    test('Valid signature passes', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payload = '{"type": "transferSettled", "data": {}, "created_at": "2024-01-01T00:00:00Z"}';
      final sig = generateSignature(payload, now, secret);

      final event = verifier.constructEvent(payload: payload, signature: sig);
      expect(event.type, WebhookEventType.transferSettled);
    });

    test('Wrong secret throws', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payload = '{"type": "transferSettled", "data": {}, "created_at": "2024-01-01T00:00:00Z"}';
      final sig = generateSignature(payload, now, 'wrong_secret');

      expect(
        () => verifier.constructEvent(payload: payload, signature: sig),
        throwsA(isA<PuenteException>().having((e) => e.message, 'msg', 'Webhook signature mismatch')),
      );
    });

    test('Stale timestamp throws', () {
      final old = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) - 600; // 10 mins ago
      final payload = '{"type": "transferSettled", "data": {}, "created_at": "2024-01-01T00:00:00Z"}';
      final sig = generateSignature(payload, old, secret);

      expect(
        () => verifier.constructEvent(payload: payload, signature: sig),
        throwsA(isA<PuenteException>().having((e) => e.message, 'msg', 'Webhook signature is stale')),
      );
    });

    test('Tampered payload throws', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payload = '{"type": "transferSettled", "data": {}, "created_at": "2024-01-01T00:00:00Z"}';
      final sig = generateSignature(payload, now, secret);

      final tamperedPayload = '{"type": "transferFailed", "data": {}, "created_at": "2024-01-01T00:00:00Z"}';

      expect(
        () => verifier.constructEvent(payload: tamperedPayload, signature: sig),
        throwsA(isA<PuenteException>().having((e) => e.message, 'msg', 'Webhook signature mismatch')),
      );
    });
  });
}
