# Puente Railway Flutter SDK

[![pub package](https://img.shields.io/pub/v/puente_railway.svg)](https://pub.dev/packages/puente_railway)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart CI](https://github.com/puente-railway/puente_railway_flutter/workflows/Dart%20CI/badge.svg)](https://github.com/puente-railway/puente_railway_flutter/actions)

Official Flutter/Dart SDK for the Puente Railway cross-border payments API. Puente Railway is the infrastructure layer for cross-border USD→MXN transfers, powering the US-to-Mexico remittance corridor over USDC-CETES-on-Solana rails with SPEI/CLABE settlement in Mexico.

## Installation

```bash
flutter pub add puente_railway
```

## Quick Start

```dart
import 'package:puente_railway/puente_railway.dart';

void main() async {
  // 1. Initialize the client
  final client = PuenteClient(
    apiKey: 'sk_sandbox_demo',
    environment: PuenteEnvironment.sandbox,
  );

  try {
    // 2. Get a live exchange rate quote
    final quote = await client.quotes.create(
      sourceAmount: Money(cents: 10000, currency: 'USD'),
      sourceCurrency: 'USD',
      targetCurrency: 'MXN',
    );

    // 3. Initiate a transfer
    final transfer = await client.transfers.create(
      quoteId: quote.id,
      senderAccountId: 'acct_123',
      receiverClabe: '646180110400000007',
      receiverName: 'María García López',
    );

    // 4. Check status
    print('Transfer ${transfer.id} status: ${transfer.status.name}');
  } on PuenteException catch (e) {
    print('Error: ${e.message}');
  }
}
```

## Environments

The SDK supports both `sandbox` and `production` environments.

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

## Error Handling

All resource methods throw typed exceptions for predictable error handling:

```dart
try {
  final transfer = await client.transfers.create(...);
} on AuthException catch (e) {
  print('Invalid API key: ${e.message}');
} on RateLimitException catch (e) {
  print('Rate limited! Retry after: ${e.retryAfter}');
} on ValidationException catch (e) {
  print('Validation failed: ${e.fieldErrors}');
} on ApiException catch (e) {
  print('HTTP error [${e.statusCode}]: ${e.message}');
} on PuenteException catch (e) {
  print('Network or SDK error: ${e.message}');
}
```

## Webhook Verification

Verify signed payloads from Puente webhooks using `WebhookVerifier`:

```dart
final verifier = WebhookVerifier(secret: 'whsec_...');

try {
  final event = verifier.constructEvent(
    payload: rawBody,       // Raw HTTP request body string
    signature: sigHeader,   // Puente-Signature header value
  );
  
  if (event.type == WebhookEventType.transferSettled) {
    print('Transfer settled!');
  }
} on PuenteException catch (e) {
  print('Webhook verification failed: $e');
}
```

## Models Reference

| Model | Key Fields |
|---|---|
| `Quote` | `id`, `sourceAmount`, `targetAmount`, `exchangeRate`, `fee`, `expiresAt` |
| `Transfer` | `id`, `status`, `createdAt` |
| `Account` | `id`, `firstName`, `lastName`, `email`, `phone` |
| `ClabeInfo` | `clabe`, `bankName`, `bankCode`, `valid` |
| `Money` | `cents`, `currency`, `amount` |
| `WebhookEvent`| `type`, `data`, `createdAt` |

## Contributing

1. Fork the repository
2. Run `dart pub get`
3. Run `dart run build_runner build` (for JSON serialization)
4. Run tests with `dart test`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
