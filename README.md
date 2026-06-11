# Puente Railway Flutter SDK

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Dart / Flutter SDK that **will** target the Puente Railway cross-border
payments API once that API is implemented. This package is the intended
client; the server it talks to is the
[`Vysion-Software/Puente`](https://github.com/Vysion-Software/Puente)
Rust workspace.

> **Status: pre-contract.** As of 2026-06-11 the routes this SDK
> calls (`/quotes`, `/transfers`, `/accounts`, `/clabe`) **do not exist
> in the live Puente backend**. The Puente server currently exposes only
> `/health`, `/balances`, and `/webhooks/etherfuse`. The webhook signature
> format this SDK verifies (`t=…,v1=…`) does **not** match what Puente's
> outbound webhook handler will emit (format TBD). See
> [`docs/contract-status.md`](docs/contract-status.md) for the full
> mismatch table.
>
> Treat the API in this README as a forward-looking design. Do not ship
> code against this SDK to production until the contract gap is closed.

## When this SDK will work

The cross-repo blockers — tracked in
[`Vysion-Software/Puente`](https://github.com/Vysion-Software/Puente/issues):

1. **Puente issue #14** — Puente emits an OpenAPI 3.1 spec.
2. Puente lands the v1 routes (issues #9, #10, #11).
3. Puente lands API authentication and idempotency-key middleware
   (issue #8).
4. Puente picks a signature format + event vocabulary for outbound
   merchant webhooks (issue #13).
5. This SDK is updated to match — either regenerated from the spec or
   manually realigned, with a constant-time HMAC compare added.

Until step 1, the public API in this package is **not a contract** —
it's a proposal.

## Installation

```bash
flutter pub add puente_railway
```

## Intended API (what the package implements today)

```dart
import 'package:puente_railway/puente_railway.dart';

void main() async {
  final client = PuenteClient(
    apiKey: 'sk_sandbox_demo',
    environment: PuenteEnvironment.sandbox,
  );

  try {
    final quote = await client.quotes.create(
      sourceAmount: Money(cents: 10000, currency: 'USD'),
      sourceCurrency: 'USD',
      targetCurrency: 'MXN',
    );

    final transfer = await client.transfers.create(
      quoteId: quote.id,
      senderAccountId: 'acct_123',
      receiverClabe: '646180110400000007',
      receiverName: 'María García López',
    );

    print('Transfer ${transfer.id} status: ${transfer.status.name}');
  } on PuenteException catch (e) {
    print('Error: ${e.message}');
  }
}
```

Against the current Puente backend this code will produce 404s on every
resource call.

## Environments

```dart
final sandboxClient = PuenteClient(
  apiKey: 'sk_sandbox_...',
  environment: PuenteEnvironment.sandbox,
);

final prodClient = PuenteClient(
  apiKey: 'sk_live_...',
  environment: PuenteEnvironment.production,
);
```

Base URLs (`lib/src/client/puente_config.dart`):
- Sandbox → `https://sandbox.api.puenterailway.com/v1`
- Production → `https://api.puenterailway.com/v1`

Neither hostname resolves to a deployed Puente service today.

## Exception hierarchy

| Exception | Triggered on |
|---|---|
| `AuthException` | HTTP 401 / 403 |
| `ValidationException` (with `fieldErrors`) | HTTP 422 |
| `RateLimitException` (with `retryAfter`) | HTTP 429, honors `Retry-After` |
| `ApiException` | Any other non-2xx (carries `statusCode`, `requestId`) |
| `PuenteException` | Transport / SDK-level failures (timeout, JSON decode) |

`RetryInterceptor` retries 429 + 5xx with exponential backoff (default 3
attempts, base 500ms, ±100ms jitter). Errors thrown after the retry
budget are surfaced to the caller verbatim.

## Webhook verification

```dart
final verifier = WebhookVerifier(secret: 'whsec_...');

try {
  final event = verifier.constructEvent(
    payload: rawBody,       // RAW HTTP request body string
    signature: sigHeader,   // header value
  );
  if (event.type == WebhookEventType.transferSettled) {
    // ...
  }
} on PuenteException catch (e) {
  print('Webhook verification failed: $e');
}
```

The verifier expects `t=<unix_seconds>,v1=<hex_hmac_sha256>` and
validates the timestamp inside a ±5 minute window.

> **Known issues with this implementation** — see
> [`docs/proposed-issues/sdk-02-webhook-compare-timing.md`](docs/proposed-issues/sdk-02-webhook-compare-timing.md):
> the final compare is a plain string `!=`, which is vulnerable to a
> remote timing attack. A constant-time compare is required before any
> webhook from a production Puente deployment is verified with this code.

## Models

| Model | Key fields |
|---|---|
| `Quote` | `id`, `sourceAmount`, `targetAmount`, `exchangeRate`, `fee`, `expiresAt` |
| `Transfer` | `id`, `status`, `createdAt` |
| `Account` | `id`, `firstName`, `lastName`, `email`, `phone` |
| `ClabeInfo` | `clabe`, `bankName`, `bankCode`, `valid` |
| `Money` | `cents`, `currency`, `amount` |
| `WebhookEvent` | `type`, `data`, `createdAt` |

JSON serialization is generated via `json_serializable`. After model
edits, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Contributing

1. Fork.
2. `dart pub get`.
3. `dart run build_runner build`.
4. `dart test`.
5. Read [`docs/contract-status.md`](docs/contract-status.md) before
   adding a new resource — any API surface must match a route that
   `Vysion-Software/Puente` is committed to serving (or that has an open
   issue committing to it).

## License

MIT. See [LICENSE](LICENSE).
