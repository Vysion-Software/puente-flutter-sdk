import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';

import '../exceptions/webhook_exception.dart';
import '../models/webhook_event.dart';

/// Verifies HMAC-SHA256 signatures on inbound webhook deliveries from
/// Puente Railway.
///
/// Supports two wire formats so the same verifier works across the
/// product-shaped outbound webhooks (Stripe-style `t=<ts>,v1=<hex>`) and
/// the raw-hex format Puente forwards from Etherfuse:
///
/// 1. **Stripe-style** — header value `t=<unix_seconds>,v1=<hex>`. The
///    timestamp is checked against [tolerance], then `<unix_seconds>.<payload>`
///    is HMAC-signed and compared to `<hex>`.
/// 2. **Raw hex** — header value is just the HMAC of the raw payload
///    (with optional `sha256=` prefix). No timestamp.
///
/// The format is detected from the header shape — callers don't have to
/// pick. Both comparisons use a constant-time byte-array compare to
/// avoid the timing-attack class of bugs.
///
/// Inject a custom [Clock] for deterministic tests:
///
/// ```dart
/// withClock(Clock.fixed(DateTime.parse('2026-01-01T00:00:00Z')), () {
///   final event = verifier.constructEvent(payload: body, signature: sig);
/// });
/// ```
class WebhookVerifier {
  /// HMAC secret. Provided to the verifier directly (never compared on
  /// the wire). Treat with the same care as an API key.
  final String secret;

  /// Maximum age of a Stripe-style signature timestamp. Defaults to 5
  /// minutes. Ignored for raw-hex format (which has no timestamp).
  final Duration tolerance;

  /// Build a [WebhookVerifier].
  const WebhookVerifier({
    required this.secret,
    this.tolerance = const Duration(minutes: 5),
  });

  /// Parse [payload] (the raw HTTP body, byte-for-byte) and verify it
  /// against [signature] (the header value the webhook delivery
  /// carried).
  ///
  /// Returns the typed [WebhookEvent] on success. Throws
  /// [WebhookException] with a typed [WebhookFailureReason] when
  /// verification fails for any reason — missing header, stale
  /// timestamp, bad HMAC, malformed JSON.
  WebhookEvent constructEvent({
    required String payload,
    required String signature,
  }) {
    if (secret.isEmpty) {
      throw const WebhookException(
        'webhook secret not configured',
        reason: WebhookFailureReason.misconfigured,
      );
    }

    final trimmedSig = signature.trim();
    if (trimmedSig.isEmpty) {
      throw const WebhookException(
        'empty signature header',
        reason: WebhookFailureReason.malformedHeader,
      );
    }

    // Branch on shape: `t=…,v1=…` is Stripe-style; everything else is
    // treated as raw hex (with optional `sha256=` prefix).
    if (trimmedSig.contains('t=') && trimmedSig.contains('v1=')) {
      _verifyStripeStyle(payload: payload, signature: trimmedSig);
    } else {
      _verifyRawHex(payload: payload, signature: trimmedSig);
    }

    // Signature OK — decode the event.
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const WebhookException(
          'webhook payload is not a JSON object',
          reason: WebhookFailureReason.invalidJson,
        );
      }
      return WebhookEvent.fromJson(decoded.cast<String, dynamic>());
    } on FormatException catch (e) {
      throw WebhookException(
        'webhook payload is not valid JSON: ${e.message}',
        reason: WebhookFailureReason.invalidJson,
      );
    }
  }

  void _verifyStripeStyle({
    required String payload,
    required String signature,
  }) {
    String? tStr;
    String? v1Str;
    for (final part in signature.split(',')) {
      final p = part.trim();
      if (p.startsWith('t=')) tStr = p.substring(2);
      if (p.startsWith('v1=')) v1Str = p.substring(3);
    }
    if (tStr == null || v1Str == null) {
      throw const WebhookException(
        'Stripe-style signature missing t= or v1=',
        reason: WebhookFailureReason.malformedHeader,
      );
    }

    final tsSeconds = int.tryParse(tStr);
    if (tsSeconds == null) {
      throw const WebhookException(
        'Stripe-style signature timestamp is not an integer',
        reason: WebhookFailureReason.malformedHeader,
      );
    }
    final ts = DateTime.fromMillisecondsSinceEpoch(
      tsSeconds * 1000,
      isUtc: true,
    );
    final now = clock.now().toUtc();
    if (now.difference(ts).abs() > tolerance) {
      throw WebhookException(
        'webhook signature timestamp is stale '
        '(skew=${now.difference(ts).inSeconds}s, tolerance=${tolerance.inSeconds}s)',
        reason: WebhookFailureReason.staleTimestamp,
      );
    }

    final signedBody = '$tStr.$payload';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final expectedDigest = hmac.convert(utf8.encode(signedBody)).bytes;
    final provided = _decodeHex(v1Str);
    if (provided == null) {
      throw const WebhookException(
        'Stripe-style v1 value is not valid hex',
        reason: WebhookFailureReason.malformedHeader,
      );
    }
    if (!_constantTimeEq(provided, expectedDigest)) {
      throw const WebhookException(
        'webhook HMAC mismatch',
        reason: WebhookFailureReason.signatureMismatch,
      );
    }
  }

  void _verifyRawHex({
    required String payload,
    required String signature,
  }) {
    var sig = signature;
    if (sig.startsWith('sha256=')) sig = sig.substring(7);
    final provided = _decodeHex(sig);
    if (provided == null) {
      throw const WebhookException(
        'raw-hex signature is not valid hex',
        reason: WebhookFailureReason.malformedHeader,
      );
    }
    final hmac = Hmac(sha256, utf8.encode(secret));
    final expectedDigest = hmac.convert(utf8.encode(payload)).bytes;
    if (!_constantTimeEq(provided, expectedDigest)) {
      throw const WebhookException(
        'webhook HMAC mismatch',
        reason: WebhookFailureReason.signatureMismatch,
      );
    }
  }

  /// Constant-time byte-array comparison.
  ///
  /// Always reads every byte regardless of mismatch position, so a remote
  /// attacker can't size-trade against response timing to extract bits
  /// of the expected HMAC. Length is checked outside the loop on
  /// purpose: a length mismatch is fast-fail (the attacker already knows
  /// the expected length from the algorithm — sha256 = 32 bytes).
  static bool _constantTimeEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Decode a hex string into bytes; returns null on bad characters.
  static List<int>? _decodeHex(String s) {
    if (s.length.isOdd) return null;
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final hi = _hexNibble(s.codeUnitAt(i * 2));
      final lo = _hexNibble(s.codeUnitAt(i * 2 + 1));
      if (hi < 0 || lo < 0) return null;
      out[i] = (hi << 4) | lo;
    }
    return out;
  }

  static int _hexNibble(int c) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30; // '0'-'9'
    if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10; // 'a'-'f'
    if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10; // 'A'-'F'
    return -1;
  }
}
