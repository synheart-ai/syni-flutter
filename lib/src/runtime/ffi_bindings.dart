import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'library_loader.dart';

// ---------------------------------------------------------------------------
// Top-level types
// ---------------------------------------------------------------------------

/// Opaque engine handle. Matches `struct syni_engine_t` in `c_api.h`.
typedef SyniEngineNative = Pointer<Void>;

/// Performance preset (mirrors `syni_preset_t` in `c_api.h`).
enum SyniPreset {
  keyboard(0),
  coach(1),
  chat(2);

  const SyniPreset(this.value);
  final int value;

  static SyniPreset fromValue(int v) =>
      values.firstWhere((p) => p.value == v, orElse: () => SyniPreset.chat);
}

// ---------------------------------------------------------------------------
// C function signatures (native side)
// ---------------------------------------------------------------------------

typedef _SyniEngineNewC = Pointer<Void> Function();
typedef _SyniEngineNewWithModelC = Pointer<Void> Function(Pointer<Utf8>);
typedef _SyniEngineLoadModelC = Bool Function(Pointer<Void>, Pointer<Utf8>);
typedef _SyniEngineFreeC = Void Function(Pointer<Void>);
typedef _SyniStringFreeC = Void Function(Pointer<Utf8>);
typedef _SyniEngineRunJsonC = Pointer<Utf8> Function(
  Pointer<Void>,
  Int32,
  Uint64,
  Pointer<Utf8>,
);
typedef _SyniVersionC = Pointer<Utf8> Function();

// Streaming: callback returns false to stop early, true to continue.
typedef _SyniStreamCallbackC = Bool Function(Pointer<Utf8>, Pointer<Void>);

typedef _SyniEngineRunStreamJsonC = Pointer<Utf8> Function(
  Pointer<Void>,
  Int32,
  Uint64,
  Pointer<Utf8>,
  Pointer<NativeFunction<_SyniStreamCallbackC>>,
  Pointer<Void>,
);

// Dart function signatures (Dart side — see `lookupFunction` second type arg).
typedef _SyniEngineNewDart = Pointer<Void> Function();
typedef _SyniEngineNewWithModelDart = Pointer<Void> Function(Pointer<Utf8>);
typedef _SyniEngineLoadModelDart = bool Function(Pointer<Void>, Pointer<Utf8>);
typedef _SyniEngineFreeDart = void Function(Pointer<Void>);
typedef _SyniStringFreeDart = void Function(Pointer<Utf8>);
typedef _SyniEngineRunJsonDart = Pointer<Utf8> Function(
  Pointer<Void>,
  int,
  int,
  Pointer<Utf8>,
);
typedef _SyniVersionDart = Pointer<Utf8> Function();

typedef _SyniEngineRunStreamJsonDart = Pointer<Utf8> Function(
  Pointer<Void>,
  int,
  int,
  Pointer<Utf8>,
  Pointer<NativeFunction<_SyniStreamCallbackC>>,
  Pointer<Void>,
);

// ---------------------------------------------------------------------------
// SyniRuntimeFFI — static facade over the loaded library.
// ---------------------------------------------------------------------------
//
// Notes on isolate semantics:
// - Each Dart isolate has its own copy of these statics; they are lazy-loaded
//   per-isolate on first use.
// - In production the engine pointer is owned by a dedicated worker isolate
//   (see `isolate_worker.dart`). The main isolate never calls the
//   engine-touching methods (engineNewWithModel / engineRunJson / engineFree)
//   directly. Calling them from the main isolate works for tests and for
//   dart:io / dart:cli contexts but will block the UI thread for the full
//   inference duration when running under Flutter.

class SyniRuntimeFFI {
  SyniRuntimeFFI._();

  static DynamicLibrary? _lib;
  static _SyniEngineNewDart? _engineNew;
  static _SyniEngineNewWithModelDart? _engineNewWithModel;
  static _SyniEngineLoadModelDart? _engineLoadModel;
  static _SyniEngineFreeDart? _engineFree;
  static _SyniStringFreeDart? _stringFree;
  static _SyniEngineRunJsonDart? _engineRunJson;
  static _SyniEngineRunStreamJsonDart? _engineRunStreamJson;
  static _SyniVersionDart? _version;

  /// Force-load the native library and resolve function pointers.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops. Returns the
  /// loaded [DynamicLibrary] for callers that want direct access.
  static DynamicLibrary initialize() {
    final lib = _lib ??= loadSyniLibrary();
    if (_engineNew == null) _resolve(lib);
    return lib;
  }

  static void _resolve(DynamicLibrary lib) {
    _engineNew = lib
        .lookupFunction<_SyniEngineNewC, _SyniEngineNewDart>('syni_engine_new');
    _engineNewWithModel = lib.lookupFunction<_SyniEngineNewWithModelC,
        _SyniEngineNewWithModelDart>('syni_engine_new_with_model');
    _engineLoadModel =
        lib.lookupFunction<_SyniEngineLoadModelC, _SyniEngineLoadModelDart>(
            'syni_engine_load_model');
    _engineFree = lib.lookupFunction<_SyniEngineFreeC, _SyniEngineFreeDart>(
        'syni_engine_free');
    _stringFree = lib.lookupFunction<_SyniStringFreeC, _SyniStringFreeDart>(
        'syni_string_free');
    _engineRunJson =
        lib.lookupFunction<_SyniEngineRunJsonC, _SyniEngineRunJsonDart>(
            'syni_engine_run_json');
    _engineRunStreamJson = lib.lookupFunction<_SyniEngineRunStreamJsonC,
        _SyniEngineRunStreamJsonDart>('syni_engine_run_stream_json');
    _version =
        lib.lookupFunction<_SyniVersionC, _SyniVersionDart>('syni_version');
  }

  // -------------------------------------------------------------------------
  // Engine lifecycle
  // -------------------------------------------------------------------------

  static SyniEngineNative engineNew() {
    initialize();
    return _engineNew!();
  }

  /// Returns [nullptr] on failure (e.g. file not found, invalid GGUF).
  static SyniEngineNative engineNewWithModel(String modelPath) {
    initialize();
    final pathPtr = modelPath.toNativeUtf8();
    try {
      return _engineNewWithModel!(pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Replaces the model on an existing engine. Returns `true` on success.
  static bool engineLoadModel(SyniEngineNative engine, String modelPath) {
    initialize();
    final pathPtr = modelPath.toNativeUtf8();
    try {
      return _engineLoadModel!(engine, pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  static void engineFree(SyniEngineNative engine) {
    initialize();
    _engineFree!(engine);
  }

  // -------------------------------------------------------------------------
  // Inference
  // -------------------------------------------------------------------------

  /// Runs a synchronous inference. Returns the JSON response as a Dart
  /// string, or `null` on failure. The native string buffer is freed
  /// internally — callers do not need to call [stringFree].
  static String? engineRunJson(
    SyniEngineNative engine,
    SyniPreset preset,
    int seed,
    String requestJson,
  ) {
    initialize();
    final jsonPtr = requestJson.toNativeUtf8();
    try {
      final resultPtr = _engineRunJson!(engine, preset.value, seed, jsonPtr);
      if (resultPtr == nullptr) return null;
      final result = resultPtr.cast<Utf8>().toDartString();
      _stringFree!(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
    }
  }

  /// Streaming inference. Same shape as [engineRunJson] but fires [onChunk]
  /// for each emitted token chunk. Returns the final accumulated JSON.
  ///
  /// [onChunk] runs synchronously on the worker isolate's thread (via
  /// `NativeCallable.isolateLocal`). It should be fast and non-blocking —
  /// typically just `streamPort.send(chunk)` to forward the chunk to the
  /// main isolate. Returning `false` from [onChunk] signals the runtime to
  /// stop generating early (cancellation).
  ///
  /// MUST be called from the isolate that loaded the library — passing the
  /// resulting `NativeCallable` across isolate boundaries is unsupported.
  static String? engineRunStreamJson(
    SyniEngineNative engine,
    SyniPreset preset,
    int seed,
    String requestJson,
    bool Function(String chunk) onChunk,
  ) {
    initialize();

    final callable = NativeCallable<_SyniStreamCallbackC>.isolateLocal(
      (Pointer<Utf8> chunkPtr, Pointer<Void> _) {
        // chunkPtr is owned by the runtime — do NOT free.
        final s = chunkPtr.toDartString();
        return onChunk(s);
      },
      exceptionalReturn: false,
    );

    final jsonPtr = requestJson.toNativeUtf8();
    try {
      final resultPtr = _engineRunStreamJson!(
        engine,
        preset.value,
        seed,
        jsonPtr,
        callable.nativeFunction,
        nullptr,
      );
      if (resultPtr == nullptr) return null;
      final result = resultPtr.cast<Utf8>().toDartString();
      _stringFree!(resultPtr);
      return result;
    } finally {
      malloc.free(jsonPtr);
      callable.close();
    }
  }

  // -------------------------------------------------------------------------
  // Misc
  // -------------------------------------------------------------------------

  /// Runtime semver string, or `null` if the call failed.
  static String? version() {
    initialize();
    final ptr = _version!();
    if (ptr == nullptr) return null;
    final s = ptr.cast<Utf8>().toDartString();
    _stringFree!(ptr);
    return s;
  }

  /// Free a string that was allocated by `syni_string_free` (rare — usually
  /// the high-level methods handle this for callers).
  static void stringFree(Pointer<Utf8> ptr) {
    initialize();
    _stringFree!(ptr);
  }
}
