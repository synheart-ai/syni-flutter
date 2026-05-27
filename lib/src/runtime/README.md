# Syni Runtime Wrapper (FFI)

Dart FFI bindings for `syni-runtime`, the Synheart on-device inference
engine. The engine runs on a **dedicated worker isolate** so inference
never blocks the caller (UI) thread.

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

## How the native runtime gets there

`syni-runtime` is shipped by the `synheart` CLI, not by
pub.dev. Run once per consumer app:

```bash
curl -fsSL https://synheart.sh/install | sh
synheart install runtime syni
```

That writes the platform binaries into the consumer app's vendor tree:

```
<app>/synheart/vendor/syni/android/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/libsyni_ffi.so
<app>/synheart/vendor/syni-runtime/SyniRuntime.xcframework/
```

The plugin's `android/build.gradle` reaches into the consumer app
(`rootProject.projectDir.parentFile/synheart/vendor/syni/...`) and
`ios/syni.podspec` walks up from `POD_DIR` (or honors `SYNHEART_APP_ROOT`)
to find them.

## Quick start

```dart
import 'package:syni/src/runtime/runtime.dart';

Future<void> main() async {
  final runtime = SyniRuntime();
  await runtime.initialize();                    // spawns worker isolate
  await runtime.loadModel('/path/to/model.gguf'); // happens on worker

  final response = await runtime.run(
    SyniRuntimeRequest(
      instruction: 'Hello',
      hsi: { /* HSI payload or ad-hoc map */ },
    ),
    preset: SyniPreset.chat,
    seed: 42,
  );

  print(response.rawJson);
  await runtime.dispose();
}
```

## Async surface

All entry points are asynchronous — the engine pointer lives on a worker
isolate, so calls don't block the UI thread:

```dart
await runtime.initialize();
await runtime.getVersion();
await runtime.loadModel(path);
await runtime.run(request);
await runtime.dispose();
```

Chat-preset inference takes 2–5 seconds; without the isolate it would
freeze the calling thread for the full duration.

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
