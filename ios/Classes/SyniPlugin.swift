import Flutter
import UIKit

/// Flutter plugin shell for Syni on iOS.
///
/// **Intentionally a no-op.** All Syni functionality is implemented in Dart
/// via `dart:ffi` against the static `libsyni_ffi` symbols linked into the
/// app binary through `SyniRuntime.xcframework` (built by `syni-runtime`'s
/// Makefile and vendored via this package's podspec). This class exists
/// only so Flutter's plugin registration system recognizes the package.
///
/// The previous platform-channel-based bridge to `syni-swift` was removed
/// when this package moved to a Dart-FFI-first architecture (see RFC-0001
/// §6.7 and the FFI refactor on `feat/ffi-isolate-worker`).
public class SyniPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {}
}
