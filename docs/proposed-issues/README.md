# Proposed Issues — puente-flutter-sdk (2026-06-11 audit)

> **STATUS: filed AND closed.** Every spec in this directory has been
> opened as a GitHub issue. **All five were closed as completed** by
> the v0.2.0 production rewrite (commit
> [`e112145`](https://github.com/Vysion-Software/puente-flutter-sdk/commit/e112145))
> in the same audit pass.

| Spec | Filed as | State | Title |
|---|---|---|---|
| `sdk-01-webhook-format-mismatch.md` | **#1** | ✅ closed | `WebhookVerifier` parses `t=…,v1=…` but Puente emits raw hex `X-Signature` — pick one with Puente |
| `sdk-02-webhook-compare-timing.md` | **#2** | ✅ closed (security) | `WebhookVerifier` uses plain string `!=` on HMAC compare — remote timing-attack vector |
| `sdk-03-idempotency-key-support.md` | **#3** | ✅ closed | Resource methods (`transfers.create`, etc.) do not accept or forward an `Idempotency-Key` |
| `sdk-04-pubspec-metadata-fix.md` | **#4** | ✅ closed | `pubspec.yaml` URLs point at `github.com/puente-railway/…` which doesn't exist |
| `sdk-05-deterministic-clock-in-tests.md` | **#5** | ✅ closed | `WebhookVerifier` tests use `DateTime.now()` — flaky if clock drifts during test run |

## What now

The spec markdown files are kept for audit-trail purposes. Future
contributors should:
1. Open new issues for new gaps directly via `gh issue create` (no need
   to write spec files first).
2. Reference the matching closed issue numbers in CHANGELOG entries.
3. If a regression appears in any of the closed areas, open a fresh
   issue referencing the original (`#1` … `#5`) — don't reopen the
   originals.
