# Syni Runtime Wrapper (FFI)

This module provides a Dart FFI wrapper for `syni-runtime`, allowing direct use of the Rust-based LLM inference engine from Dart/Flutter.

## Setup

### 1. Build syni-runtime

First, build the `syni-runtime` library:

```bash
cd syni-runtime
cargo build --features llama --release
```

This will create:
- **macOS**: `target/release/libsyni_ffi.dylib`
- **Linux**: `target/release/libsyni_ffi.so`
- **Windows**: `target\release\syni_ffi.dll`

### 2. Copy library to accessible location

For development, copy the library to a location where Dart can find it:

**macOS:**
```bash
cp syni-runtime/target/release/libsyni_ffi.dylib /usr/local/lib/
# Or use DYLD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=$PWD/syni-runtime/target/release:$DYLD_LIBRARY_PATH
```

**Linux:**
```bash
cp syni-runtime/target/release/libsyni_ffi.so /usr/local/lib/
# Or use LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$PWD/syni-runtime/target/release:$LD_LIBRARY_PATH
```

**For Flutter apps**, you'll need to bundle the library with your app (see platform-specific instructions below).

## Usage

```dart
import 'package:syni/src/runtime/runtime.dart';

void main() async {
  final runtime = SyniRuntime();
  
  // Initialize
  runtime.initialize();
  
  // Load a model
  runtime.loadModel('/path/to/model.gguf');
  
  // Or download a model
  final modelPath = await runtime.downloadModel(
    'https://huggingface.co/.../model.gguf'
  );
  runtime.loadModel(modelPath);
  
  // Run inference
  final request = SyniRuntimeRequest(
    instruction: 'Hello! How are you?',
    hsi: {'coherence': 0.8},
  );
  
  final response = runtime.run(
    request,
    preset: SyniPreset.chat,
    seed: 42,
  );
  
  print(response.rawJson);
  
  // Cleanup
  runtime.dispose();
}
```

## Example

See `example/runtime_example.dart` for a complete example using a local GGUF model.

## Platform Integration

### Flutter iOS

1. Build `syni-runtime` for iOS (requires cross-compilation)
2. Add the `.framework` or `.a` to your iOS project
3. Update `ios/Podfile` if needed

### Flutter Android

1. Build `syni-runtime` for Android (arm64-v8a, x86_64)
2. Place `.so` files in `android/app/src/main/jniLibs/<arch>/`
3. Update `android/build.gradle` if needed

## Notes

- The FFI wrapper requires the native library to be built and accessible
- Model files (GGUF) can be local or downloaded
- All inference is handled by the Rust core via FFI
- This is a lower-level API compared to the platform channel approach
