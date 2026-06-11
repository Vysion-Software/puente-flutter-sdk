**Title:** `WebhookVerifier` uses plain string `!=` on HMAC compare — remote timing-attack vector

**Repo / branch:** `Vysion-Software/puente-flutter-sdk` / `main`
**Severity:** P1 / security
**Labels:** `bug`, `area:webhooks`, `security`

## Current behavior

`lib/src/webhooks/webhook_verifier.dart` ends with:

```dart
if (expectedSignature != v1Val) {
  throw const PuenteException('Webhook signature mismatch');
}
```

That's a plain Dart string compare. For Dart, string equality is
likely length-then-byte-compare, which has a measurable timing
gradient as the prefix matches. A remote attacker who can submit
many guesses and time the response can extract the valid HMAC byte by
byte.

Industry standard: constant-time compare on the decoded byte arrays
(or equivalent — `package:cryptography` exposes one; `package:crypto`
does not by default).

The Rust side in Puente (`crates/puente-offramp/src/webhook.rs`)
already does it correctly via `subtle::ConstantTimeEq`.

## Expected behavior

Replace the final compare with a constant-time byte-array compare.
The simplest portable implementation is:

```dart
bool _ctEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
```

Decode the hex first; never compare hex strings directly.

## Acceptance criteria

- [ ] `WebhookVerifier` decodes the provided `v1` hex into bytes and
  compares against the locally-computed digest bytes with a
  constant-time function.
- [ ] A test confirms two equal byte arrays succeed.
- [ ] A test confirms two unequal byte arrays fail (existing test
  covers this).
- [ ] The change ships in a patch release with a CHANGELOG security
  entry; consumers should bump.

## Evidence

- `lib/src/webhooks/webhook_verifier.dart` lines 52-54.
- `test/webhook_verifier_test.dart` — exercises pass/fail paths
  using string equality.

## Dependencies / related

- SDK `sdk-01-webhook-format-mismatch`. Land both together.
- Puente proposed `puente-103-outbound-webhook-format`.
