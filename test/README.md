# Tests

The Syni Flutter SDK has three rough categories of code, each with its own testability profile:

| Layer | Examples | Testable here? |
|---|---|---|
| **Pure-Dart** | `SyniRequest`/`SyniResponse` map round-trips, `SyniError`, `SyniSpecPersona` JSON parsing, model catalog | ✅ yes — flutter_test in this directory |
| **Flutter platform plumbing** | `SyniSpecPersona.load` (reads from `rootBundle`), Method/Event channel handlers | ⚠️ partial — `TestWidgetsFlutterBinding.ensureInitialized()` + mock channels |
| **FFI + isolate runtime** | `SyniRuntime` (worker isolate over GGUF inference), `library_loader`, `ffi_bindings` | ❌ no — exercised by `example_mobile/` on-device and by integration tests against a real bundled engine |

## What to test here

The default landing pattern when a bug arrives or a contributor adds a feature:

1. **Map serialization** — both directions. `toMap` then `fromMap` should round-trip without information loss. See `smoke_test.dart`'s `SyniRequest` test for the reference shape.
2. **Error mapping** — every `SyniError` factory or platform exception path. See `errors_test.dart`.
3. **Typed response projections** — every `KeyboardSuggestionResponse`, `CoachStepsResponse`, etc. that wraps a raw `SyniResponse`. Test happy path + a malformed-input fallback.
4. **Persona / model spec loading** — schema-shape assertions on the parsed JSON. (`SyniSpecPersona.load` itself needs `rootBundle`, so isolate the parser if you can; otherwise mock with `ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', …)`.)

## What's NOT tested here

- **Worker-isolate behavior** — the runtime spins up a real isolate, loads a real GGUF, and runs real inference. That's covered by manual runs of `example_mobile/`.
- **Network / SSE streaming** — `SyniCloudClient` makes real HTTP calls. When a bug arrives, the right harness is `http`'s `MockClient` injected through a test-seam constructor on `SyniCloudClient` (add the seam when needed; don't add it preemptively).
- **FFI bindings** — the native lib has to actually exist on the test platform. Skipped in CI; verified by running `example_mobile/` on a real device.

## CI gates

The `.github/workflows/ci.yml` workflow runs three things on every push and PR:

```
dart format --output=none --set-exit-if-changed .
flutter analyze --no-fatal-infos
dart pub publish --dry-run        # blocks publish-breaking changes (LICENSE, pubspec, etc.)
flutter test                      # runs everything in this directory
```

If you push a commit, all four need to pass. The format check is strict — `dart format .` before committing.

## Running locally

```bash
flutter test                          # all tests
flutter test test/errors_test.dart    # one file
flutter test --name 'SyniError'       # filter by description
flutter test --coverage               # produces coverage/lcov.info
```
