# Contributing to syni

Thanks for your interest in `syni`. This is the Dart/Flutter side of the
Synheart on-device LLM stack — for issues with model behavior or runtime
crashes the right place is usually the bug template here, but for persona
content changes see
[`syni-spec`](https://github.com/synheart-ai/syni-spec).

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

## Pull requests

- Keep changes focused; one concern per PR.
- Run `dart format` before committing.
- `dart analyze` must be clean — the package targets zero analyzer
  warnings.
- New public APIs need dartdoc.
- New behavior needs at least one test under `test/`.
- Update [`CHANGELOG.md`](CHANGELOG.md) under the **Unreleased**
  section using [Keep a Changelog](https://keepachangelog.com/) style
  (`Added` / `Changed` / `Fixed` / `Removed`).

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
