# Puente Railway Flutter SDK

[![pub package](https://img.shields.io/pub/v/puente_railway.svg)](https://pub.dev/packages/puente_railway)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Official Dart/Flutter SDK for **Puente Railway** — the Solana + Etherfuse
settlement rail behind [Pesito](https://github.com/Vysion-Software/pesito).
Send USD → MXN remittances, fetch quotes, look up CLABE bank routing,
verify webhooks, and stream transfer state from one clean Dart API.

Pure-Dart core: works in Flutter (mobile + web + desktop), in pure-Dart
servers (CLI tooling, Cloud Functions), and in tests with **no
network**.

```dart
final puente = PuenteClient.mock();  // or PuenteConfig.testnet(...)
final result = await puente.remittance.send(
  sourceAmount: Money.fromDecimal('100.00', Currency.usd),
  targetCurrency: Currency.mxn,
  receiverClabe: '012180012345678901',
  receiverName: 'María García López',
);
await for (final t in puente.remittance.watch(result.transfer.id)) {
  print('${t.id}: ${t.status.wire}');
}
```

## Why this SDK

The SDK's design takes inspiration from
[`flutter_rust_bridge`](https://pub.dev/packages/flutter_rust_bridge):

* **Clean typed boundary** between Flutter/Dart and the Puente Rust
  backend. Every model mirrors a Rust type 1:1 — `Currency`, `Money`,
  `Transfer`, `Quote`, `Account`, `ClabeInfo`.
* **Async-first, stream-based.** Resource methods return `Future`s;
  long-running operations (transfer lifecycle) return `Stream`s.
* **Strong type safety.** No `dynamic` in the public API. Currency
  mismatches throw at compile-time-ish (instant `StateError`).
* **Predictable error mapping.** Every failure path is a subclass of
  `PuenteException`; one `catch` covers them all.
* **Tested.** 62 unit + integration tests under `dart test`. The
  `MockTransport` runs the entire `quote → transfer → watch` flow
  offline, deterministically, in milliseconds.

## Install

```bash
flutter pub add puente_railway
```

## Quick start

### Offline demo (no API key, no network)

```dart
import 'package:puente_railway/puente_railway.dart';

void main() async {
  final puente = PuenteClient.mock();

  // CLABE lookup
  final bank = await puente.clabe.lookup('012180012345678901');
  print('${bank.bankName} (valid=${bank.valid})');

  // Quote
  final quote = await puente.quotes.create(
    sourceAmount: Money.fromDecimal('100.00', Currency.usd),
    targetCurrency: Currency.mxn,
  );
  print('${quote.sourceAmount} → ${quote.targetAmount}');

  // Transfer
  final transfer = await puente.transfers.create(
    quoteId: quote.id,
    receiverClabe: bank.clabe,
    receiverName: 'María García López',
    memo: 'Para la familia',
  );

  // Watch lifecycle
  await for (final t in puente.transfers.watch(transfer.id)) {
    print('${t.id}: ${t.status.wire}');
    if (t.status.isTerminal) break;
  }

  puente.close();
}
```

### Real backend (testnet)

```dart
final puente = PuenteClient(
  config: PuenteConfig.testnet(
    apiKey: 'sk_testnet_…',
    merchantId: 'merchant_pesito',
  ),
);
```

The four `PuenteEnvironment` values map to:

| Environment   | Base URL                                       | Purpose                                  |
|---------------|------------------------------------------------|------------------------------------------|
| `mock`        | n/a (in-memory)                                | Offline demos, unit tests                |
| `testnet`     | `https://api-testnet.puenterailway.com/v1`     | Puente devnet — Solana devnet + Etherfuse sandbox |
| `sandbox`     | `https://api-sandbox.puenterailway.com/v1`     | Stable staging                           |
| `production`  | `https://api.puenterailway.com/v1`             | Real money                               |

Override the base URL with `PuenteConfig(baseUrlOverride: ...)` when
pointing at a local `puente-api` binary (set
`PUENTE_ENABLE_DEMO_ROUTES=1` on the server to mount the demo
routes).

## Money + currency

```dart
const tenBucks = Money.fromMinor(1000, Currency.usd);   // 10.00 USD
final fifty = Money.major(50, Currency.usd);             // 50.00 USD
final fee = Money.fromDecimal('1.99', Currency.usd);     // 1.99 USD

print(tenBucks + fifty);            // "60.00 USD"
print(tenBucks - fee);              // "8.01 USD"
print(tenBucks + Money.major(50, Currency.mxn));  // throws StateError
```

`Money` uses **integer minor units only**. Decimal strings are parsed
with integer math, never `double.parse`, so `0.1 + 0.2` is exactly
`0.30`.

## Webhook verification

`WebhookVerifier` accepts both signature formats Puente uses on the
wire:

* **Stripe-style** (`t=<unix_seconds>,v1=<hex>`) — Puente's outbound
  merchant webhooks.
* **Raw hex** (`X-Signature: <hex>`, optionally `sha256=` prefixed) —
  Puente's inbound Etherfuse events.

```dart
const verifier = WebhookVerifier(secret: 'whsec_...');

try {
  final event = verifier.constructEvent(
    payload: rawBody,
    signature: signatureHeader,
  );
  if (event.type == WebhookEventType.transferSettled) {
    // ...
  }
} on WebhookException catch (e) {
  switch (e.reason) {
    case WebhookFailureReason.staleTimestamp:
      // skewed clock or replay attempt
    case WebhookFailureReason.signatureMismatch:
      // bad HMAC
    default:
      // log + 400
  }
}
```

The compare is **constant-time** on the decoded byte arrays — no
timing oracle. The `t` timestamp window is configurable via
`tolerance:` (default 5 min). Inject `package:clock` for deterministic
tests:

```dart
withClock(Clock.fixed(DateTime.parse('2026-01-01T00:00:00Z')), () {
  final event = verifier.constructEvent(payload: body, signature: sig);
});
```

## Idempotency

Every money-moving call accepts an optional `idempotencyKey`. When
omitted, the SDK generates a UUIDv4 and forwards it as the
`Idempotency-Key` header. Puente caches the response keyed on
`(merchantId, idempotencyKey)` so retries don't double-charge.

```dart
// First call — SDK generates a key.
final a = await puente.transfers.create(...);

// Retry with the same key — server returns the cached response.
final b = await puente.transfers.create(
  quoteId: ...,
  receiverClabe: ...,
  receiverName: ...,
  idempotencyKey: 'my-stable-key',
);
```

## Errors

| Class                  | Triggered on                                            |
|------------------------|---------------------------------------------------------|
| `AuthException`        | HTTP 401 / 403                                          |
| `ValidationException`  | HTTP 422 (with `fieldErrors` map)                       |
| `RateLimitException`   | HTTP 429 (with `retryAfter`)                            |
| `ApiException`         | Any other non-2xx                                       |
| `TransportException`   | Request never reached the server (timeout, DNS, TLS)    |
| `WebhookException`     | Signature verification failed                           |
| `PuenteException`      | Root of the hierarchy — catch this to cover all paths   |

`RetryInterceptor` retries 429 + 5xx with exponential backoff +
jitter, honoring `Retry-After`. Errors thrown after the retry budget
exhausts are surfaced verbatim — never swallowed.

## Observability

```dart
class StdoutObserver extends PuenteObserver {
  const StdoutObserver();
  @override
  void onResponse(PuenteResponseEvent e) {
    print('${e.method} ${e.url} → ${e.statusCode} '
        '(${e.elapsed.inMilliseconds}ms, attempt ${e.attempt})');
  }
}

final puente = PuenteClient(
  config: PuenteConfig.testnet(apiKey: '...'),
  observer: const StdoutObserver(),
);
```

`Authorization` and `Idempotency-Key` headers are masked before they
reach the observer.

## Architecture

```
PuenteClient (facade)
 ├── PuenteConfig (env + apiKey + merchantId + timeout + retry)
 ├── PuenteTransport (abstract) ── HttpTransport | MockTransport | <custom>
 ├── Resources (typed)
 │    ├── QuotesResource
 │    ├── TransfersResource
 │    ├── AccountsResource
 │    └── ClabeResource
 ├── PuenteRemittance (high-level: quote → transfer → watch)
 ├── WebhookVerifier
 └── PuenteObserver (logging + tracing hooks)
```

The transport layer is fully abstract — write your own
`PuenteTransport` to record real traffic for golden tests, or to
swap in a proxy. See [`docs/contract-status.md`](docs/contract-status.md)
for what each Puente backend route currently serves.

## Contributing

```bash
dart pub get
dart analyze
dart test
dart format .
```

The `MockTransport` is deterministic given a fixed `seed:` — useful
for reproducing test failures. Open issues at
<https://github.com/Vysion-Software/puente-flutter-sdk/issues>.

## License

MIT. See [LICENSE](LICENSE).
