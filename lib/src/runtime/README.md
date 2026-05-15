# Syni Runtime Wrapper (FFI)

Dart bindings for `syni-runtime`, the Rust-based LLM inference engine. The
engine runs on a **dedicated worker isolate** so inference never blocks the
caller (UI) thread.

> **Internal package.** App developers should not depend on `package:syni`
> directly. The consumer-facing API lives in `package:synheart_core` as
> `Synheart.syni.*`, which gates installation, consent, and capability before
> talking to this runtime. See [syni RFC-0001 §6](../../../doc/rfc.md) and
> `synheart_feature.dart` in `synheart-core-flutter`.

## Module layout

```
lib/src/runtime/
├── library_loader.dart     # DynamicLibrary resolution per platform
├── ffi_bindings.dart       # SyniRuntimeFFI — static facade over libsyni_ffi
├── isolate_worker.dart     # SyniRuntimeWorker — engine pointer owned on a worker isolate
├── syni_runtime.dart       # SyniRuntime — high-level async API for app code
├── runtime.dart            # Re-export barrel
└── README.md               # this file
```

## Build flow

The native artifact is built by `syni-runtime`'s Makefile and vendored
**into the consumer app** (not into this package — mirrors how
synheart-core-runtime is provisioned):

```bash
cd ../syni-runtime
make prereqs              # one-time toolchain check
make targets-install      # install missing rustup targets

# Build + vendor into the consumer app in one shot:
make vendor-app APP_DIR=/path/to/consumer-app
# or per-platform:
make vendor-app-android APP_DIR=/path/to/consumer-app
make vendor-app-ios     APP_DIR=/path/to/consumer-app
```

Vendoring lands the artifacts here, inside the consumer app:

```
<app>/synheart/vendor/syni/android/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/libsyni_ffi.so
<app>/synheart/vendor/syni/ios/SyniRuntime.xcframework/
```

This package's `android/build.gradle` reaches up into the app
(`rootProject.projectDir.parentFile/synheart/vendor/syni/...`) and
`ios/syni.podspec` reaches up via `${PODS_ROOT}/../../` to find them.
The consumer app also lists the jniLibs path in its own
`jniLibs.srcDirs`. Keep all three in sync if the `synheart/vendor/syni/`
layout changes.

## Quick start (development)

```dart
import 'package:syni/src/runtime/runtime.dart';

Future<void> main() async {
  final runtime = SyniRuntime();
  await runtime.initialize();                    // spawns worker isolate
  await runtime.loadModel('/path/to/model.gguf'); // happens on worker

  final response = await runtime.run(
    SyniRuntimeRequest(
      instruction: 'Hello',
      hsi: { /* HSI 1.3 payload or ad-hoc map */ },
    ),
    preset: SyniPreset.chat,
    seed: 42,
  );

  print(response.rawJson);
  await runtime.dispose();
}
```

## Breaking change vs. v1.0

`SyniRuntime.run()` was synchronous in v1.0 and blocked the calling isolate
for the duration of inference (which on chat preset is 2–5 seconds — long
enough to freeze the UI thread).

In this version, the engine runs on a worker isolate spawned by
`SyniRuntime.initialize()`, and **all entry points are asynchronous**:

| v1.0 | This version |
|---|---|
| `runtime.initialize()` | `await runtime.initialize()` |
| `runtime.getVersion()` | `await runtime.getVersion()` |
| `runtime.loadModel(p)` | `await runtime.loadModel(p)` |
| `runtime.run(req)` | `await runtime.run(req)` |
| `runtime.dispose()` | `await runtime.dispose()` |

Note that v1.0 also did not compile (nested typedefs / enums are invalid
Dart), so there are no production v1.0 deployments to migrate. This is
effectively the first working release.

## What's intentionally not here

The following capabilities exist in `libsyni_ffi`'s C ABI but are not yet
exposed at the Dart layer. Follow-up PRs:

- **Streaming** (`syni_engine_run_stream_json`, `syni_inference_async`,
  `syni_inference_cancel`) — wire via `NativeCallable.listener` (Dart 3.1+).
- **Tokenization** (`syni_tokenize`, `syni_token_count`,
  `syni_chat_template_get`, `syni_eos_token_get`, `syni_bos_token_get`).
- **Telemetry & introspection** (`syni_engine_healthcheck`,
  `syni_telemetry_json`, `syni_queue_pending_count`,
  `syni_model_cache_count`, `syni_model_cache_clear`).
- **ffigen migration** — bindings are currently hand-written; a follow-up
  generates them from `../syni-runtime/ffi/c_api.h` for drift safety.
