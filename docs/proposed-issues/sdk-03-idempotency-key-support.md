**Title:** Resource methods (`transfers.create`, etc.) do not accept or forward an `Idempotency-Key`

**Repo / branch:** `Vysion-Software/puente-flutter-sdk` / `main`
**Severity:** P2 / api
**Labels:** `enhancement`, `area:api`, `cross-repo`

## Current behavior

`lib/src/resources/transfers_resource.dart`'s `create` does:

```dart
final response = await _client.post(
  '/transfers',
  body: { 'quote_id': quoteId, /* … */ },
);
```

No `Idempotency-Key` header is sent and the method does not accept an
`idempotencyKey` argument. The HTTP client in
`lib/src/http/puente_http_client.dart` does not generate one either.

Retrying a `POST /transfers` mid-flight could double-execute on the
server (issue: even if the server adds idempotency in #8, the client
still has to send a key for it to do anything).

## Expected behavior

Every money-moving resource method accepts an optional
`idempotencyKey` parameter. If omitted, the SDK generates a UUIDv4
(via `package:uuid` or equivalent) and uses it for the request. The
key is sent as the `Idempotency-Key` header.

Money-moving methods this affects:
- `TransfersResource.create`
- `TransfersResource.cancel`
- `QuotesResource.create` (probably — quotes are free to retry but
  the server should still treat them idempotently)
- `AccountsResource.create`

Read methods (`retrieve`, `list`) and `AccountsResource.update`
(PATCH) do not need one.

## Acceptance criteria

- [ ] Method signatures accept `String? idempotencyKey`.
- [ ] Default: SDK generates a UUIDv4 and forwards it.
- [ ] The key is sent on the wire as `Idempotency-Key`.
- [ ] At least one round-trip test confirms the header reaches the
  server.
- [ ] README "Quick Start" mentions the auto-generated key and shows
  how to override.

## Evidence

- `lib/src/resources/transfers_resource.dart`.
- `lib/src/http/puente_http_client.dart` — no header injection.

## Dependencies / related

- Puente proposed `puente-101-idempotency-cross-repo` — defines the
  server contract this implements.
- Puente #8 (server middleware) — actual enforcement.
