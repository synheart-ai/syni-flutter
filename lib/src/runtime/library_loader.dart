import 'dart:ffi';
import 'dart:io' show Platform;

/// Loads `libsyni_ffi` for the current platform.
///
/// Linkage layout matches what `syni-runtime/Makefile` produces and what the
/// Flutter plugin's podspec / gradle vendors:
///
/// - **iOS**: static `.a` inside `SyniRuntime.xcframework`, linked into the
///   app binary via the Flutter plugin podspec → `DynamicLibrary.process()`.
/// - **macOS**: dev workflow prefers `DynamicLibrary.open` so the dylib can
///   be picked up via `DYLD_LIBRARY_PATH`; falls back to `process()` when a
///   Flutter macOS plugin links the static lib into the app.
/// - **Android**: `libsyni_ffi.so` packaged per ABI under
///   `android/src/main/jniLibs/<abi>/` → `DynamicLibrary.open(...)`.
/// - **Linux / Windows**: dev-only — opens by filename relative to the
///   process working directory.
///
/// Throws [UnsupportedError] for unsupported platforms.
DynamicLibrary loadSyniLibrary() {
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    for (final path in const [
      'libsyni_ffi.dylib',
      '/usr/local/lib/libsyni_ffi.dylib',
    ]) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {/* try next */}
    }
    return DynamicLibrary.process();
  }
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libsyni_ffi.so');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libsyni_ffi.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('syni_ffi.dll');
  }
  throw UnsupportedError(
    'syni-flutter does not support ${Platform.operatingSystem}',
  );
}
