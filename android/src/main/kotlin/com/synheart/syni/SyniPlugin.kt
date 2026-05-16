package com.synheart.syni

import io.flutter.embedding.engine.plugins.FlutterPlugin

/// Flutter plugin shell for Syni on Android.
///
/// **Intentionally a no-op.** All Syni functionality is implemented in Dart
/// via `dart:ffi` against `libsyni_ffi.so` (built by `syni-runtime`'s
/// Makefile and packaged in `android/src/main/jniLibs/<abi>/`). This class
/// exists only so Flutter's plugin registration system recognizes the
/// package and wires up Android-side build steps (manifest merging, jniLibs
/// packaging into the APK).
///
/// The previous platform-channel-based bridge to `syni-kotlin` was removed
/// when this package moved to a Dart-FFI-first architecture (see RFC-0001
/// §6.7 and the FFI refactor on `feat/ffi-isolate-worker`).
class SyniPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
