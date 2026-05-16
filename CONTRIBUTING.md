# Contributing to syni

Thanks for your interest in `syni`. This is the Dart/Flutter side of the
Synheart on-device LLM stack — for issues with model behavior or runtime
crashes the right place is usually the bug template here, but for persona
content questions see the
[Syni Spec documentation](https://docs.synheart.ai/syni-spec/overview).

## Local dev loop

```bash
# 1. Clone the repo
git clone https://github.com/synheart-ai/syni-flutter
cd syni-flutter

# 2. Install dependencies
flutter pub get

# 3. Install the runtime binaries (drops them into the example app's
#    vendor tree so the example can run end-to-end on a device)
synheart install syni

# 4. Lint + test
dart analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

Run the example app on a connected device:

```bash
cd example
flutter pub get
flutter run
```

## Tests

The test surface and what's testable from Dart vs what needs the FFI runtime
is documented in [`test/README.md`](test/README.md). Short version:

- **Pure-Dart layer** (errors, request/response maps, persona/model JSON
  parsing) — testable here with `flutter_test`.
- **Worker isolate + FFI runtime** — not unit-testable; exercised by
  `example_mobile/` on a real device.
- **Network / SSE streaming** — add an `http`-mock seam to `SyniCloudClient`
  when a bug or feature warrants it; don't add it preemptively.

CI runs `dart format`, `flutter analyze --no-fatal-infos`,
`dart pub publish --dry-run`, and `flutter test` on every push and PR.
All four must be green.

## Why we do not accept pull requests

This SDK is developed in an internal monorepo and mirrored to GitHub for
transparency. The public repository is source-available so anyone can read,
audit, and learn from the code that runs on their device — but the project is
not yet ready to absorb external code contributions.

Specifically:

- **Spec stability.** The Syni runtime contract and the persona/safety
  schemas in `syni-spec` are still evolving against internal RFCs.
  Accepting external changes before the spec settles would create churn
  for everyone, including contributors.
- **Review capacity.** A small team maintains this code. We would rather
  invest review time in stabilizing the runtime than in bouncing PRs back
  for rework.
- **Provenance.** We avoid contributor licensing overhead (CLAs, copyright
  assignment) by sourcing all code internally.

External pull requests are auto-closed by the
[`close-external-prs`](.github/workflows/close-external-prs.yml) workflow.
This is a temporary policy and may relax once the spec is stable. Until
then, issues are the supported way to influence the direction of the SDK.

## What about typo / docs fixes?

Even small documentation fixes are best filed as an issue. Quote the section,
suggest the change, and we will roll it into the next internal sync. This
keeps a single contribution path and avoids ambiguity about what is in scope.

## Internal dev style notes

For Synheart team members working in the internal monorepo, the gates the CI
workflow checks before any commit lands:

- `dart format` clean (CI runs `dart format --output=none --set-exit-if-changed .`)
- `flutter analyze --no-fatal-infos` clean
- `dart pub publish --dry-run` clean (catches LICENSE/pubspec regressions)
- `flutter test` green
- New public APIs need dartdoc; new behavior needs a test under `test/`.
- CHANGELOG updated under the **Unreleased** section using
  [Keep a Changelog](https://keepachangelog.com/) style.

## Reporting issues

Please open issues at
[github.com/synheart-ai/syni-flutter/issues](https://github.com/synheart-ai/syni-flutter/issues).

For inference / runtime bugs (model load, generation quality, native
crashes), include:

- Flutter version (`flutter --version`)
- Device + OS version
- Model spec id (e.g. `qwen2.5-1.5b-instruct-q4_k_m`)
- Relevant log lines (the runtime tags its logs with `[synheart]`)

For suspected security issues, follow [`SECURITY.md`](SECURITY.md) instead
of opening a public issue.
