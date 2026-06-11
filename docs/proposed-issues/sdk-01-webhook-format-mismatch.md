**Title:** `WebhookVerifier` parses `t=…,v1=…` but Puente emits raw hex `X-Signature` — pick one with Puente

**Repo / branch:** `Vysion-Software/puente-flutter-sdk` / `main`
**Severity:** P1 / cross-repo
**Labels:** `bug`, `area:webhooks`, `cross-repo`

## Current behavior

`lib/src/webhooks/webhook_verifier.dart` `constructEvent` expects the
signature in the format:

```
t=<unix_seconds>,v1=<hex_hmac_sha256>
```

and signs `"<t>.<payload>"` — Stripe-style.

Puente's inbound webhook handler (`crates/puente-offramp/src/webhook.rs`
in `Vysion-Software/Puente`) accepts raw hex (or `sha256=<hex>`) in
the `X-Signature` header, signing the **raw request body bytes**.

The two protocols cannot interoperate. The SDK's verifier would reject
every real webhook Puente forwards.

## Expected behavior

Either (a) Puente picks a format for *outbound* merchant webhooks
(separate from the inbound Etherfuse channel) and the SDK matches, or
(b) the SDK is updated to match Puente's existing inbound format.

Recommendation (paired with Puente proposed
`puente-103-outbound-webhook-format`): keep the SDK's
Stripe-compatible format for outbound merchant webhooks (so the
parser logic stays put), have Puente emit the same.

## Acceptance criteria

- [ ] `Vysion-Software/Puente#13` (outbound webhooks) commits to a
  signature format.
- [ ] If the format chosen is Stripe-style: SDK's `WebhookVerifier`
  needs only the constant-time-compare fix (see `sdk-02`).
- [ ] If the format chosen is bare-hex: SDK's `WebhookVerifier` is
  rewritten to accept either a positional header arg or a typed
  header bag.
- [ ] Round-trip integration test against a Puente test fixture
  passes.

## Evidence

- `lib/src/webhooks/webhook_verifier.dart`.
- `Vysion-Software/Puente/crates/puente-offramp/src/webhook.rs`.

## Dependencies / related

- Puente #13 (outbound webhooks impl).
- Puente proposed `puente-103-outbound-webhook-format`.
- SDK `sdk-02-webhook-compare-timing`.
