import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'ffi_bindings.dart';
import 'isolate_worker.dart';

/// Thrown when the runtime, model, or inference call fails.
class SyniRuntimeError implements Exception {
  SyniRuntimeError(this.message);
  final String message;

  @override
  String toString() => 'SyniRuntimeError: $message';
}

/// A single inference request.
///
/// [hsi] is an opaque conditioning payload — the runtime's `PromptBuilder`
/// reads it. For HSI 1.3 callers should pass the full HSI payload here; for
/// V1 callers that don't yet have HSI integration, a flat ad-hoc map works
/// too (Syni currently ignores unknown fields).
class SyniRuntimeRequest {
  const SyniRuntimeRequest({
    required this.instruction,
    this.hsi,
    this.schema,
  });

  final String instruction;
  final Map<String, dynamic>? hsi;
  final String? schema;

  Map<String, dynamic> toJson() => {
        'instruction': instruction,
        if (hsi != null) 'hsi': hsi,
        if (schema != null) 'schema': schema,
      };
}

/// Schema-validated response from the runtime.
class SyniRuntimeResponse {
  SyniRuntimeResponse(this.rawJson) : data = jsonDecode(rawJson);

  /// Raw JSON string returned by the runtime (already grammar-constrained
  /// and validated against the persona's output schema).
  final String rawJson;

  /// Parsed top-level map. Field set depends on the persona's response
  /// schema (`chat_response`, `coach_response`, `suggestions`, …).
  final dynamic data;

  factory SyniRuntimeResponse.fromJson(String json) =>
      SyniRuntimeResponse(json);
}

// ---------------------------------------------------------------------------
// SyniRuntime — high-level Dart wrapper around the worker isolate.
// ---------------------------------------------------------------------------

/// Async, isolate-backed wrapper around `libsyni_ffi`.
///
/// All inference calls run on a dedicated worker isolate so the caller (UI)
/// isolate is never blocked. Initialize once, load a model, then issue any
/// number of [run] calls.
///
/// **Breaking change from v1.0**: [run] is now asynchronous. Previous code
/// like:
///
/// ```dart
/// final r = runtime.run(req);
/// ```
///
/// must become:
///
/// ```dart
/// final r = await runtime.run(req);
/// ```
class SyniRuntime {
  SyniRuntimeWorker? _worker;
  String? _modelPath;

  bool get isInitialized => _worker != null;
  String? get modelPath => _modelPath;

  /// Spawn the worker isolate. Safe to call multiple times.
  Future<void> initialize() async {
    if (_worker != null) return;
    try {
      _worker = await SyniRuntimeWorker.spawn();
    } catch (e) {
      throw SyniRuntimeError('failed to spawn worker: $e');
    }
  }

  /// Runtime semver, or `null` if the call failed.
  Future<String?> getVersion() async {
    await initialize();
    return _worker!.version();
  }

  /// Load a GGUF model file. Idempotent for the same path; replaces the
  /// model on the existing engine when called with a different path.
  Future<bool> loadModel(String modelPath) async {
    await initialize();
    if (!File(modelPath).existsSync()) {
      throw SyniRuntimeError('Model file not found: $modelPath');
    }
    await _worker!.loadModel(modelPath);
    _modelPath = modelPath;
    return true;
  }

  /// Download a GGUF model from [url] into the app's documents directory.
  ///
  /// Returns the local filesystem path. Skips the download if the file
  /// already exists at the destination.
  ///
  /// **Note:** this method exists for development convenience. Production
  /// callers (synheart-core-flutter's SyniModule) should use the core SDK's
  /// model installer which performs SHA verification and consent gating.
  Future<String> downloadModel(String url, {String? filename}) async {
    await initialize();

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/syni_models');
    if (!modelsDir.existsSync()) {
      modelsDir.createSync(recursive: true);
    }

    final name = filename ?? url.split('/').last;
    final modelPath = '${modelsDir.path}/$name';

    if (File(modelPath).existsSync()) {
      return modelPath;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw SyniRuntimeError(
        'Failed to download model: HTTP ${response.statusCode}',
      );
    }
    await File(modelPath).writeAsBytes(response.bodyBytes);
    return modelPath;
  }

  /// Run a single inference.
  ///
  /// Returns a schema-validated [SyniRuntimeResponse]. Throws
  /// [SyniRuntimeError] on failure (no model loaded, runtime failure,
  /// schema-validation rejection without a fallback).
  Future<SyniRuntimeResponse> run(
    SyniRuntimeRequest request, {
    SyniPreset preset = SyniPreset.chat,
    int seed = 0,
  }) async {
    await initialize();
    if (_modelPath == null) {
      throw SyniRuntimeError(
        'Model not loaded. Call loadModel() or downloadModel() first.',
      );
    }
    try {
      final raw = await _worker!.runJson(
        preset.value,
        seed,
        jsonEncode(request.toJson()),
      );
      return SyniRuntimeResponse.fromJson(raw);
    } on Exception catch (e) {
      throw SyniRuntimeError(e.toString());
    }
  }

  /// Run inference and stream token chunks as they are generated.
  ///
  /// Returns a [Stream] of [SyniRuntimeStreamChunk]:
  /// - Zero or more [SyniRuntimeStreamDelta] events as tokens arrive.
  /// - Exactly one [SyniRuntimeStreamFinal] at the end carrying the
  ///   schema-validated final JSON.
  /// - On failure: a stream error.
  ///
  /// V1 does not support mid-stream cancellation — let the stream complete
  /// or close it on the consumer side and ignore further deltas.
  Stream<SyniRuntimeStreamChunk> runStream(
    SyniRuntimeRequest request, {
    SyniPreset preset = SyniPreset.chat,
    int seed = 0,
  }) async* {
    await initialize();
    if (_modelPath == null) {
      throw SyniRuntimeError(
        'Model not loaded. Call loadModel() or downloadModel() first.',
      );
    }
    yield* _worker!.runStream(
      preset.value,
      seed,
      jsonEncode(request.toJson()),
    );
  }

  /// Free the engine and terminate the worker isolate. The instance can be
  /// re-initialized after dispose by calling [initialize] again.
  Future<void> dispose() async {
    final w = _worker;
    _worker = null;
    _modelPath = null;
    await w?.dispose();
  }
}
