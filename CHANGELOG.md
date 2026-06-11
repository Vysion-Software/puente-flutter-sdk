# Changelog

## 0.2.0 — 2026-06-11

**Production-grade rewrite.** Breaking API changes; existing 0.1.x
callers will need to update.

### Architecture
- New layered design: `PuenteClient` → `PuenteTransport` (abstract)
  → resources / models. Transport options are `HttpTransport` (real),
  `MockTransport` (in-memory, deterministic), and a swap-in slot for
  custom transports (golden tests, record/replay).
- New `PuenteRemittance` high-level facade for the
  `quote → transfer → watch` flow Pesito's demo uses.
- New `PuenteEnvironment` values: `mock`, `testnet`, `sandbox`,
  `production`. `PuenteClient.mock()` works fully offline.

### Money + currency
- `Currency` is now an `enum` with `decimals` and ISO-style `code`,
  mirroring `puente_core::Currency` in the Rust workspace.
- `Money` now uses `minorUnits` + `Currency` (was `cents` + `String`).
  Currency mismatch on arithmetic throws `StateError`. New
  `Money.fromMinor`, `Money.major`, `Money.fromDecimal` constructors;
  the decimal parser uses integer math (no floating-point loss).

### Webhooks
- `WebhookVerifier` now accepts **both** signature formats Puente
  emits: Stripe-style `t=…,v1=…` (product-shaped outbound) and raw
  hex `X-Signature` (Etherfuse-shaped inbound).
- **Security fix:** HMAC compare is now constant-time on the decoded
  byte arrays (was `!=` on hex strings — timing-attackable). Closes
  proposed issue `sdk-02-webhook-compare-timing`.
- Inject a `Clock` via `package:clock` for deterministic tests. The
  test suite uses `withClock(Clock.fixed(...))` so timestamp checks no
  longer flake.
- `WebhookException` now carries a typed `WebhookFailureReason` so
  callers can branch on `malformedHeader` / `staleTimestamp` /
  `signatureMismatch` / `invalidJson` / `misconfigured`.

### Resources + idempotency
- Every money-moving resource method (`quotes.create`,
  `transfers.create`, `transfers.cancel`, `accounts.create`) accepts
  an optional `idempotencyKey`. The SDK auto-generates a UUIDv4 when
  the caller doesn't supply one. Header is `Idempotency-Key`. Closes
  proposed issue `sdk-03-idempotency-key-support`.
- `transfers.watch(id)` streams lifecycle updates as a
  `Stream<Transfer>` until a terminal state — polling logic moves out
  of UI code.

### Errors
- `TransportException` is a new typed exception for "request never
  reached the server" (timeout, DNS, TLS). Distinct from
  `ApiException` (which is "server answered, status was bad"). UX can
  finally tell those two cases apart.
- `RetryInterceptor`'s silent exception swallow is gone; the new
  `HttpTransport` reports every retry attempt to a `PuenteObserver`
  and surfaces a `TransportException` after the retry budget is
  exhausted.

### Observability
- New `PuenteObserver` hook for `onRequest` / `onResponse` /
  `onRetry` / `onError`. Defaults to silent; pass a subclass to wire
  Sentry / OpenTelemetry / print logging.
- `Authorization` and `Idempotency-Key` are masked in observer events.

### Metadata fixes
- `pubspec.yaml` `homepage` / `repository` / `issue_tracker` now point
  at `github.com/Vysion-Software/puente-flutter-sdk`. Closes proposed
  `sdk-04-pubspec-metadata-fix`.
- Dropped `flutter_test` for unit tests; the SDK now uses
  `package:test` so the core works in pure Dart (server, CLI). Flutter
  widget tests can still consume the package — they just go in the
  example app, not the SDK itself.
- Dropped the `json_serializable` build step. Models are hand-written
  with explicit `fromJson`/`toJson` — fewer moving parts at install
  time, generated `.g.dart` files no longer churn in PRs.

### Tests
- 62 unit + integration tests, all passing under `dart test`.
- Webhook verifier suite covers Stripe-style, raw-hex, tampered
  payloads, stale timestamps, malformed headers, constant-time
  compare, misconfiguration, and the `sdk-02` timing-attack regression.
- New `test/integration/demo_flow_test.dart` end-to-end test that
  walks the exact "CLABE lookup → quote → transfer → watch lifecycle
  → idempotent retry" flow Pesito's testnet demo will run.

### Companion Puente changes
- `Vysion-Software/Puente` adds opt-in in-memory `/v1/{quotes,transfers,
  accounts,clabe}` routes behind `PUENTE_ENABLE_DEMO_ROUTES=1`. Lets
  the SDK's `HttpTransport` integration-test against a real
  `puente-api` binary while the production routes are still being
  built (Puente issues #9, #10, #11).

### Breaking changes summary
- `Money({cents, currency: String})` → `Money.fromMinor(int, Currency)`.
- `PuenteClient(apiKey: …, environment: …)` →
  `PuenteClient(config: PuenteConfig(...))`. A `PuenteClient.mock()`
  helper covers the common no-config case.
- `QuotesResource.create(sourceAmount, sourceCurrency, targetCurrency)`
  → `QuotesResource.create(sourceAmount, targetCurrency)`. The source
  currency now comes from `sourceAmount.currency` — eliminates the
  duplicate-source-currency footgun.

## 0.1.0

- Initial release
- QuotesResource: create
- TransfersResource: create, retrieve, list, cancel
- AccountsResource: create, retrieve, update
- ClabeResource: lookup
- WebhookVerifier with HMAC-SHA256
- Sandbox + production environments
- Exponential backoff retry
