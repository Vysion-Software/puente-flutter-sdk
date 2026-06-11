**Title:** `WebhookVerifier` tests use `DateTime.now()` — flaky if clock drifts during test run

**Repo / branch:** `Vysion-Software/puente-flutter-sdk` / `main`
**Severity:** P3 / test
**Labels:** `test`

## Current behavior

`test/webhook_verifier_test.dart` repeatedly calls:

```dart
final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
final sig = generateSignature(payload, now, secret);
final event = verifier.constructEvent(payload: payload, signature: sig);
```

This is fine on a stable clock but assumes:
1. The clock advances no more than tolerance (5 min) between the
   `generateSignature` call and the `constructEvent` call.
2. The test process clock matches the SDK's internal clock.

Both are usually true. Both can fail on a slow CI runner or when the
test runs under a tracer / debugger that pauses execution. The
"stale timestamp throws" test explicitly subtracts 600 seconds, so it
crosses the tolerance — but a near-stale signature (e.g., 4m59s old)
could flap.

## Expected behavior

Inject a clock into `WebhookVerifier` so tests pin the timestamp.
Either:

1. Add a `DateTime Function()? clock` parameter to `WebhookVerifier`
   (defaults to `DateTime.now`).
2. Or accept a `now` parameter on `constructEvent` (less ergonomic
   but smaller diff).

Tests then pass deterministic timestamps via the injected clock.

## Acceptance criteria

- [ ] Clock injection added (option 1 preferred).
- [ ] Tests rewritten to use a fixed clock.
- [ ] Public API change documented in CHANGELOG; the new parameter
  is optional so existing consumers compile unchanged.

## Evidence

- `lib/src/webhooks/webhook_verifier.dart` line 42:
  `final now = DateTime.now().toUtc();`
- `test/webhook_verifier_test.dart` lines 19, 28, 38, 50 — all use
  `DateTime.now()`.

## Dependencies / related

- SDK `sdk-02-webhook-compare-timing` — touches the same file; land
  in the same release.
