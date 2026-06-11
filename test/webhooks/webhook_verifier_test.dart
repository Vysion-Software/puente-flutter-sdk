import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

/// Regression suite for `sdk-01-webhook-format-mismatch`,
/// `sdk-02-webhook-compare-timing`, and `sdk-05-deterministic-clock-in-tests`.
void main() {
  const secret = 'whsec_test_secret';
  const verifier = WebhookVerifier(secret: secret);
  final fixedNow = DateTime.parse('2026-06-11T12:00:00Z');

  String stripeSig(String payload, {DateTime? at, String? overrideSecret}) {
    final ts = (at ?? fixedNow).toUtc().millisecondsSinceEpoch ~/ 1000;
    final signed = '$ts.$payload';
    final mac = Hmac(sha256, utf8.encode(overrideSecret ?? secret));
    final hex = mac.convert(utf8.encode(signed)).toString();
    return 't=$ts,v1=$hex';
  }

  String rawHexSig(String payload, {String? overrideSecret}) {
    final mac = Hmac(sha256, utf8.encode(overrideSecret ?? secret));
    return mac.convert(utf8.encode(payload)).toString();
  }

  group('Stripe-style', () {
    test('valid signature passes', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload =
            '{"type":"transfer.settled","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        final sig = stripeSig(payload);
        final event = verifier.constructEvent(payload: payload, signature: sig);
        expect(event.type, WebhookEventType.transferSettled);
      });
    });

    test('tampered payload fails', () {
      withClock(Clock.fixed(fixedNow), () {
        const original =
            '{"type":"transfer.settled","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        const tampered =
            '{"type":"transfer.failed","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        final sig = stripeSig(original);
        expect(
          () => verifier.constructEvent(payload: tampered, signature: sig),
          throwsA(isA<WebhookException>().having(
            (e) => e.reason,
            'reason',
            WebhookFailureReason.signatureMismatch,
          )),
        );
      });
    });

    test('stale timestamp fails', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload =
            '{"type":"transfer.settled","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        final sig = stripeSig(
          payload,
          at: fixedNow.subtract(const Duration(minutes: 10)),
        );
        expect(
          () => verifier.constructEvent(payload: payload, signature: sig),
          throwsA(isA<WebhookException>().having(
            (e) => e.reason,
            'reason',
            WebhookFailureReason.staleTimestamp,
          )),
        );
      });
    });

    test('wrong secret fails', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload =
            '{"type":"transfer.settled","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        final sig = stripeSig(payload, overrideSecret: 'whsec_other');
        expect(
          () => verifier.constructEvent(payload: payload, signature: sig),
          throwsA(isA<WebhookException>().having(
            (e) => e.reason,
            'reason',
            WebhookFailureReason.signatureMismatch,
          )),
        );
      });
    });

    test('malformed header fails fast', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload = '{"type":"transfer.settled","data":{}}';
        expect(
          () => verifier.constructEvent(
              payload: payload, signature: 't=,v1=garbage'),
          throwsA(isA<WebhookException>().having(
            (e) => e.reason,
            'reason',
            WebhookFailureReason.malformedHeader,
          )),
        );
      });
    });
  });

  group('Raw-hex (Etherfuse-style)', () {
    test('valid raw-hex passes', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload =
            '{"type":"transfer.settled","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        final sig = rawHexSig(payload);
        final event = verifier.constructEvent(payload: payload, signature: sig);
        expect(event.type, WebhookEventType.transferSettled);
      });
    });

    test('sha256= prefix accepted', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload =
            '{"type":"transfer.settled","data":{},"created_at":"2026-01-01T00:00:00Z"}';
        final sig = 'sha256=${rawHexSig(payload)}';
        final event = verifier.constructEvent(payload: payload, signature: sig);
        expect(event.type, WebhookEventType.transferSettled);
      });
    });

    test('tampered payload fails', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload = '{"type":"transfer.settled"}';
        const tampered = '{"type":"transfer.failed"}';
        final sig = rawHexSig(payload);
        expect(
          () => verifier.constructEvent(payload: tampered, signature: sig),
          throwsA(isA<WebhookException>().having(
            (e) => e.reason,
            'reason',
            WebhookFailureReason.signatureMismatch,
          )),
        );
      });
    });
  });

  group('Constant-time compare (sdk-02 regression)', () {
    test('mismatched lengths fail fast (no oracle)', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload = '{}';
        // Provide a hex string that decodes to fewer bytes than sha256
        // (32). A correct constant-time path returns false without
        // looking at content.
        expect(
          () => verifier.constructEvent(payload: payload, signature: 'aa'),
          throwsA(isA<WebhookException>()),
        );
      });
    });

    test('signature mismatch returns WebhookException, never leaks bytes', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload = '{}';
        // Same length as a valid sha256 hex (64 chars) but all zeros.
        final allZeros = '0' * 64;
        try {
          verifier.constructEvent(payload: payload, signature: allZeros);
          fail('expected WebhookException');
        } on WebhookException catch (e) {
          // The message is intentionally constant — no byte-position leak.
          expect(e.message, 'webhook HMAC mismatch');
        }
      });
    });
  });

  group('Misconfiguration', () {
    test('empty secret throws WebhookException', () {
      const empty = WebhookVerifier(secret: '');
      expect(
        () => empty.constructEvent(payload: '{}', signature: 'aa'),
        throwsA(isA<WebhookException>().having(
          (e) => e.reason,
          'reason',
          WebhookFailureReason.misconfigured,
        )),
      );
    });

    test('non-JSON payload throws WebhookException(invalidJson)', () {
      withClock(Clock.fixed(fixedNow), () {
        const payload = 'not-json-at-all';
        final sig = rawHexSig(payload);
        expect(
          () => verifier.constructEvent(payload: payload, signature: sig),
          throwsA(isA<WebhookException>().having(
            (e) => e.reason,
            'reason',
            WebhookFailureReason.invalidJson,
          )),
        );
      });
    });
  });
}
