# syni

Flutter (Dart) wrapper for Syni. This package provides two ways to use Syni:

1. **Platform Channels** (default) - Delegates to native SDKs (syni-swift / syni-kotlin) via platform channels
2. **FFI Runtime** (new) - Direct FFI wrapper for `syni-runtime` Rust core engine

## Usage

Add the dependency:

```bash
flutter pub add syni
```

Initialize once at app start:

```dart
import 'package:flutter/widgets.dart';
import 'package:syni/syni.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Syni.initialize(const SyniConfig(
    appId: 'com.example.myapp',
    appVersion: '1.0.0',
  ));

  // runApp(...)
}
```

Generate a response:

```dart
final response = await Syni.generate(const SyniRequest(
  personaId: 'keyboard.v1',
  input: 'Hello, how are',
));

// Raw structured output
print(response.outputJson);
```

Typed helpers for known schemas live in `package:syni/models.dart`:

```dart
import 'package:syni/syni.dart';
import 'package:syni/models.dart';

final response = await Syni.generate(const SyniRequest(
  personaId: 'keyboard.v1',
  input: 'Hello, how are',
));

final suggestions = KeyboardSuggestionResponse.fromSyniResponse(response);
```

## FFI Runtime Wrapper (Direct syni-runtime)

For direct access to the Rust-based `syni-runtime` engine without platform channels:

```dart
import 'package:syni/src/runtime/runtime.dart';

final runtime = SyniRuntime();
runtime.initialize();

// Load a local GGUF model or download one
runtime.loadModel('/path/to/model.gguf');
// Or: final path = await runtime.downloadModel('https://.../model.gguf');

// Run inference
final response = runtime.run(
  SyniRuntimeRequest(instruction: 'Hello!'),
  preset: SyniPreset.chat,
);

print(response.rawJson);
runtime.dispose();
```

**Setup:**
1. Build `syni-runtime`: `cd syni-runtime && cargo build --features llama --release`
2. Make library accessible (see `lib/src/runtime/README.md` for details)
3. See `example/runtime_example.dart` for a complete example

**Benefits:**
- Direct access to Rust core engine
- No platform channel overhead
- Works with local GGUF models
- Model downloading built-in

See `lib/src/runtime/README.md` for detailed setup instructions.

## Platform Channels (Default)

This Flutter package can also communicate with native SDKs over a MethodChannel:

- Channel: `com.synheart.syni/sdk`
- Methods: `initialize`, `generate`, `getModels`, `downloadModel`, `deleteModel`

Native SDK integration (syni-swift / syni-kotlin) is expected to be provided via the iOS podspec and Android Gradle dependency when available.

## Docs

- Design RFC: `doc/rfc.md`
- Runtime Wrapper: `lib/src/runtime/README.md`