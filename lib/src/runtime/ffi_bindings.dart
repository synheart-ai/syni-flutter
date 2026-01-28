import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// FFI bindings for syni-runtime C API
class SyniRuntimeFFI {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// Initialize the FFI library
  static DynamicLibrary initialize() {
    if (_initialized && _lib != null) {
      return _lib!;
    }

    DynamicLibrary? library;

    if (Platform.isMacOS) {
      // Try to load from common locations
      final paths = [
        'libsyni_ffi.dylib',
        '/usr/local/lib/libsyni_ffi.dylib',
      ];
      
      for (final path in paths) {
        try {
          library = DynamicLibrary.open(path);
          break;
        } catch (e) {
          // Try next path
        }
      }
    } else if (Platform.isIOS) {
      // iOS: Load from app bundle (Frameworks)
      try {
        library = DynamicLibrary.process();
      } catch (e) {
        // Fallback: try explicit path
        try {
          library = DynamicLibrary.open('Frameworks/libsyni_ffi.framework/libsyni_ffi');
        } catch (e2) {
          // Last resort: try just the library name
          try {
            library = DynamicLibrary.open('libsyni_ffi');
          } catch (e3) {
            // Will throw below
          }
        }
      }
    } else if (Platform.isLinux) {
      try {
        library = DynamicLibrary.open('libsyni_ffi.so');
      } catch (e) {
        // Try alternative
      }
    } else if (Platform.isWindows) {
      try {
        library = DynamicLibrary.open('syni_ffi.dll');
      } catch (e) {
        // Try alternative
      }
    } else if (Platform.isAndroid) {
      // Android: Load from jniLibs (packaged in APK)
      // The library should be in android/app/src/main/jniLibs/<abi>/libsyni_ffi.so
      try {
        library = DynamicLibrary.open('libsyni_ffi.so');
      } catch (e) {
        // Try alternative naming
        try {
          library = DynamicLibrary.open('syni_ffi');
        } catch (e2) {
          // Will throw below
        }
      }
    }

    if (library == null) {
      throw Exception(
        'Failed to load syni-runtime library. '
        'Make sure libsyni_ffi is built and available. '
        'Build syni-runtime first: cd syni-runtime && cargo build --release',
      );
    }

    _lib = library;
    _initialized = true;
    return _lib!;
  }

  static DynamicLibrary get lib {
    if (_lib == null) {
      return initialize();
    }
    return _lib!;
  }

  // Opaque pointer type for engine
  typedef SyniEngineNative = Pointer<Void>;

  // Preset enum
  enum SyniPreset {
    keyboard(0),
    coach(1),
    chat(2);

    final int value;
    const SyniPreset(this.value);
  }

  // Function signatures
  typedef SyniEngineNewNative = Pointer<Void> Function();
  typedef SyniEngineNewWithModelNative = Pointer<Void> Function(Pointer<Utf8>);
  typedef SyniEngineLoadModelNative = Bool Function(
      Pointer<Void>, Pointer<Utf8>);
  typedef SyniEngineFreeNative = Void Function(Pointer<Void>);
  typedef SyniStringFreeNative = Void Function(Pointer<Utf8>);
  typedef SyniEngineRunJsonNative = Pointer<Utf8> Function(
      Pointer<Void>, Int32, Uint64, Pointer<Utf8>);
  typedef SyniVersionNative = Pointer<Utf8> Function();

  // Dart function types
  typedef SyniEngineNew = Pointer<Void> Function();
  typedef SyniEngineNewWithModel = Pointer<Void> Function(Pointer<Utf8>);
  typedef SyniEngineLoadModel = bool Function(Pointer<Void>, Pointer<Utf8>);
  typedef SyniEngineFree = void Function(Pointer<Void>);
  typedef SyniStringFree = void Function(Pointer<Utf8>);
  typedef SyniEngineRunJson = Pointer<Utf8> Function(
      Pointer<Void>, int, int, Pointer<Utf8>);
  typedef SyniVersion = Pointer<Utf8> Function();

  // Lazy-loaded functions (initialized after library is loaded)
  static SyniEngineNew? _engineNew;
  static SyniEngineNewWithModel? _engineNewWithModel;
  static SyniEngineLoadModel? _engineLoadModel;
  static SyniEngineFree? _engineFree;
  static SyniStringFree? _stringFree;
  static SyniEngineRunJson? _engineRunJson;
  static SyniVersion? _version;

  static void _ensureFunctionsLoaded() {
    if (_engineNew != null) return;
    final l = lib;
    _engineNew =
        l.lookupFunction<SyniEngineNewNative, SyniEngineNew>('syni_engine_new');

    _engineNewWithModel = l.lookupFunction<SyniEngineNewWithModelNative,
        SyniEngineNewWithModel>('syni_engine_new_with_model');
    _engineLoadModel = l.lookupFunction<SyniEngineLoadModelNative,
        SyniEngineLoadModel>('syni_engine_load_model');
    _engineFree = l.lookupFunction<SyniEngineFreeNative, SyniEngineFree>(
        'syni_engine_free');
    _stringFree = l.lookupFunction<SyniStringFreeNative, SyniStringFree>(
        'syni_string_free');
    _engineRunJson = l.lookupFunction<SyniEngineRunJsonNative,
        SyniEngineRunJson>('syni_engine_run_json');
    _version =
        l.lookupFunction<SyniVersionNative, SyniVersion>('syni_version');
  }

  // Public API
  static Pointer<Void> engineNew() {
    _ensureFunctionsLoaded();
    return _engineNew!();
  }

  static Pointer<Void> engineNewWithModel(String modelPath) {
    _ensureFunctionsLoaded();
    final pathPtr = modelPath.toNativeUtf8();
    try {
      return _engineNewWithModel!(pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  static bool engineLoadModel(Pointer<Void> engine, String modelPath) {
    _ensureFunctionsLoaded();
    final pathPtr = modelPath.toNativeUtf8();
    try {
      return _engineLoadModel!(engine, pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  static void engineFree(Pointer<Void> engine) {
    _ensureFunctionsLoaded();
    _engineFree!(engine);
  }

  static void stringFree(Pointer<Utf8> str) {
    _ensureFunctionsLoaded();
    _stringFree!(str);
  }

  static String? engineRunJson(
    Pointer<Void> engine,
    SyniPreset preset,
    int seed,
    String requestJson,
  ) {
    _ensureFunctionsLoaded();
    final jsonPtr = requestJson.toNativeUtf8();
    try {
      final resultPtr = _engineRunJson!(engine, preset.value, seed, jsonPtr);
      if (resultPtr == nullptr) {
        return null;
      }
      final result = resultPtr.toDartString();
      _stringFree!(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
    }
  }

  static String? version() {
    _ensureFunctionsLoaded();
    final versionPtr = _version!();
    if (versionPtr == nullptr) {
      return null;
    }
    final version = versionPtr.toDartString();
    _stringFree!(versionPtr);
    return version;
  }
}
