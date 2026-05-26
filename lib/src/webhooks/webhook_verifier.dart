import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../exceptions/puente_exception.dart';
import '../models/webhook_event.dart';

class WebhookVerifier {
  final String secret;
  final Duration tolerance;

  WebhookVerifier({
    required this.secret,
    this.tolerance = const Duration(minutes: 5),
  });

  WebhookEvent constructEvent({
    required String payload,
    required String signature,
  }) {
    // Expected signature format: "t=1234567890,v1=abc123def456..."
    final parts = signature.split(',');
    String? tVal;
    String? v1Val;

    for (final part in parts) {
      if (part.startsWith('t=')) {
        tVal = part.substring(2);
      } else if (part.startsWith('v1=')) {
        v1Val = part.substring(3);
      }
    }

    if (tVal == null || v1Val == null) {
      throw const PuenteException('Invalid webhook signature format');
    }

    final timestampSeconds = int.tryParse(tVal);
    if (timestampSeconds == null) {
      throw const PuenteException('Invalid webhook signature timestamp');
    }

    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000, isUtc: true);
    final now = DateTime.now().toUtc();
    if (now.difference(timestamp).abs() > tolerance) {
      throw const PuenteException('Webhook signature is stale');
    }

    final signedPayload = '$tVal.$payload';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(signedPayload));
    final expectedSignature = digest.toString();

    if (expectedSignature != v1Val) {
      throw const PuenteException('Webhook signature mismatch');
    }

    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return WebhookEvent.fromJson(json);
    } catch (e) {
      throw const PuenteException('Invalid webhook payload JSON');
    }
  }
}
