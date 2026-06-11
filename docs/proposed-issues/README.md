# Proposed Issues — puente-flutter-sdk (2026-06-11 audit)

Each `sdk-NN-*.md` file in this directory is a fully-specced GitHub
issue, ready to be filed with `gh issue create --title "<title>"
--body "$(cat sdk-NN-…md)" --label …`.

This repo had **0 existing issues** at audit time. Every gap below is
new.

| File | Severity | Title |
|---|---|---|
| `sdk-01-webhook-format-mismatch.md` | P1 / cross-repo | `WebhookVerifier` parses `t=…,v1=…` but Puente emits raw `X-Signature` — pick one with Puente |
| `sdk-02-webhook-compare-timing.md` | P1 / security | `WebhookVerifier` uses plain string `!=` — remote timing-attack vector |
| `sdk-03-idempotency-key-support.md` | P2 / api | Resource methods (`transfers.create`, etc.) do not accept or forward an `Idempotency-Key` |
| `sdk-04-pubspec-metadata-fix.md` | P3 / hygiene | `pubspec.yaml` URLs point at `github.com/puente-railway/…` which doesn't exist; correct org is `Vysion-Software/puente-flutter-sdk` |
| `sdk-05-deterministic-clock-in-tests.md` | P3 / test | `WebhookVerifier` tests use `DateTime.now()` — flaky if clock drifts during test run |

## Dedup notes

There are no existing issues to dedup against on this repo.

See also `Vysion-Software/Puente/docs/proposed-issues/`:
- `puente-101-idempotency-cross-repo` pairs with `sdk-03`.
- `puente-102-define-product-events` pairs with `sdk-01`.
- `puente-103-outbound-webhook-format` pairs with `sdk-01` + `sdk-02`.
