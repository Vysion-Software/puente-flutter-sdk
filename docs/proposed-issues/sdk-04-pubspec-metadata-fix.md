**Title:** `pubspec.yaml` URLs point at `github.com/puente-railway/…` which doesn't exist

**Repo / branch:** `Vysion-Software/puente-flutter-sdk` / `main`
**Severity:** P3 / hygiene
**Labels:** `documentation`, `bug`

## Current behavior

`pubspec.yaml`:

```yaml
homepage: https://github.com/puente-railway/puente_railway_flutter
repository: https://github.com/puente-railway/puente_railway_flutter
issue_tracker: https://github.com/puente-railway/puente_railway_flutter/issues
```

None of those URLs resolve to a real GitHub org — the SDK actually
lives at `Vysion-Software/puente-flutter-sdk`. A pub.dev visitor
clicking through any of these links lands on a 404.

The README's CI badge also points at `puente-railway/puente_railway_flutter`,
same problem.

## Expected behavior

```yaml
homepage: https://github.com/Vysion-Software/puente-flutter-sdk
repository: https://github.com/Vysion-Software/puente-flutter-sdk
issue_tracker: https://github.com/Vysion-Software/puente-flutter-sdk/issues
```

README badge updated to the real CI URL once CI is set up; for now,
remove the badge or point it at a workflow that exists.

## Acceptance criteria

- [ ] `pubspec.yaml` URLs corrected.
- [ ] README badge corrected or removed.
- [ ] CHANGELOG entry for the metadata fix.
- [ ] Ships in the next patch release (probably `0.1.1`).

## Evidence

- `pubspec.yaml` lines 4-6.
- `README.md` top — `[![Dart CI](https://github.com/puente-railway/puente_railway_flutter/workflows/…)]`.

## Dependencies / related

- None.
