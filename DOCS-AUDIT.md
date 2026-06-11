# puente-flutter-sdk — Documentation Audit (2026-06-11)

## Summary

The SDK README claimed parity with a Puente Railway API that does not
exist; the implementation has two security/correctness defects (timing-
attackable webhook compare, fragile retry-interceptor exception swallow)
and one metadata defect (fake `pubspec.yaml` repository URLs). Docs
rewritten to be truthful; gaps tracked as proposed issues.

## Changes shipped

| File | Change |
|---|---|
| `README.md` | Rewritten to lead with **"Status: pre-contract"**. Spells out that resource methods do not work against the live backend, that the webhook format does not match Puente, and what has to happen in Puente before the SDK is usable. Old README marketed the package as production-ready. |
| `docs/contract-status.md` (new) | Authoritative SDK ↔ Puente mismatch table covering routes, webhook signature, base URLs, and recommended rewrite list. |
| `docs/proposed-issues/*.md` (new dir) | Five issue specs (`sdk-01` … `sdk-05`) for gaps not currently tracked anywhere. |
| `DOCS-AUDIT.md` (this file) | Audit trail. |

## Verified accurate, kept as-is

| File | Verification |
|---|---|
| `pubspec.yaml` (everything except `homepage` / `repository` / `issue_tracker`) | Versions match `pubspec.lock`. |
| `CHANGELOG.md` | Single `0.1.0` entry, matches the public-API surface exported from `lib/puente_railway.dart`. |
| `lib/src/exceptions/*.dart` (rustdoc-style header comments) | Match the actual class hierarchy. |
| `lib/src/http/interceptors/auth_interceptor.dart` | The `Authorization`/`Content-Type`/`Accept`/`X-SDK-Version` header set is accurate. |

## Gaps flagged but NOT shipped as code changes

- `pubspec.yaml` URLs (`homepage`, `repository`, `issue_tracker`) all
  point at `https://github.com/puente-railway/puente_railway_flutter`,
  which is not the real repo. The fix is mechanical but should land
  with a deliberate version bump (this audit cannot bump the published
  package version unilaterally) — proposed issue
  `sdk-04-pubspec-metadata-fix`.
- The webhook timing-attack fix likewise requires a version bump and
  a security note in the changelog — proposed issue
  `sdk-02-webhook-compare-timing`.
- Tests using `DateTime.now()` for time-bound assertions are flaky;
  proposed issue `sdk-05-deterministic-clock-in-tests`.

## Existing tracker coverage

`gh issue list` on the SDK repo returns **zero issues**. Every gap in
this audit is new.

## Audit method

- Read `pubspec.yaml`, `lib/puente_railway.dart`, every file in
  `lib/src/`, every test in `test/`.
- Cross-referenced route table + webhook signature format against
  `Vysion-Software/Puente` (`crates/puente-api/src/routes.rs`,
  `crates/puente-offramp/src/webhook.rs`).
- Verified the SDK is not referenced anywhere in
  `Vysion-Software/pesito` (zero `grep` hits in `mobile/` or
  `functions/`).
