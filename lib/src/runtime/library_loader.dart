import 'dart:ffi';
import 'dart:io' show Platform;

/// Loads `libsyni_ffi` for the current platform.
///
/// Linkage layout matches what `syni-runtime/Makefile` produces and what the
/// Flutter plugin's podspec / gradle vendors:
///
/// - **iOS**: dynamic `SyniRuntime.framework` inside
///   `SyniRuntime.xcframework`, embedded into the app bundle via
///   `vendored_frameworks`. The iOS dynamic loader maps it at process
///   start under the framework's `@rpath` install_name; we open it
///   here by the framework's executable name (no path, no `.dylib`
///   suffix — Mach-O framework convention).
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
    // Mach-O lookup by framework executable name. Equivalent to
    // dlopen("SyniRuntime.framework/SyniRuntime", RTLD_NOW). Works
    // because CocoaPods auto-embeds the framework into the app
    // bundle's Frameworks/ dir and the dylib's install_name is
    // @rpath/SyniRuntime.framework/SyniRuntime.
    return DynamicLibrary.open('SyniRuntime.framework/SyniRuntime');
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
