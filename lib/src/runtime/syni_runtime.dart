import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'ffi_bindings.dart';
import 'isolate_worker.dart';
import 'telemetry.dart';

/// Thrown when the runtime, model, or inference call fails.
///
/// When the failure originated from the native runtime's structured failure
/// envelope (`{"ok":false,"error":{"code","message","retryable"}}`), [code] and
/// [retryable] carry the machine-readable classification so callers can branch
/// (e.g. re-authenticate, offer a Retry) instead of pattern-matching [message].
class SyniRuntimeError implements Exception {
  SyniRuntimeError(this.message, {this.code, this.retryable = false});

  /// Build from a runtime failure envelope's `error` object. Defensive against
  /// a malformed envelope: a non-string `message`/`code` becomes null (→ a
  /// generic message / `UNKNOWN`), and any non-`true` `retryable` is false.
  factory SyniRuntimeError.fromEnvelope(Map<String, dynamic> error) =>
      SyniRuntimeError(
        _asString(error['message']) ?? 'unknown runtime error',
        code: _asString(error['code']) ?? 'UNKNOWN',
        retryable: error['retryable'] == true,
      );

  /// A client-side protocol failure: the native output could not be parsed as
  /// the documented envelope (malformed JSON, non-object, etc.). Distinct from
  /// a runtime *domain* failure — never a successful response.
  factory SyniRuntimeError.protocol(String detail) =>
      SyniRuntimeError(detail, code: 'MALFORMED_RESPONSE');

  /// Human-readable, safe to show to users.
  final String message;

  /// Stable machine-readable code (`MODEL_UNAVAILABLE`, `TIMEOUT`,
  /// `INVALID_ARGUMENT`, …), or null when the error did not come from a runtime
  /// failure envelope. Treat an unrecognized value as `UNKNOWN`.
  final String? code;

  /// True only for transient failures the runtime marked retryable
  /// (`TIMEOUT`, `INVALID_JSON`, `SCHEMA`).
  final bool retryable;

  @override
  String toString() =>
      'SyniRuntimeError: $message${code != null ? ' ($code)' : ''}';
}

enum SyniRuntimeMessageRole { user, assistant }

/// One prior dialogue turn. System authority is carried separately by
/// [SyniRuntimeRequest.system] so dialogue can never silently become policy.
class SyniRuntimeMessage {
  const SyniRuntimeMessage({required this.role, required this.content});

  final SyniRuntimeMessageRole role;
  final String content;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
      };
}

/// Per-turn native generation controls. All fields are optional; absence keeps
/// the runtime's tuned preset defaults.
class SyniRuntimeGenerationConfig {
  const SyniRuntimeGenerationConfig({
    this.maxTokens,
    this.ttftTimeoutMs,
    this.seed,
    this.temperature,
    this.topK,
    this.topP,
    this.minP,
    this.penaltyRepeat,
    this.penaltyFreq,
    this.dryMultiplier,
  });

  final int? maxTokens;
  final int? ttftTimeoutMs;
  final int? seed;
  final double? temperature;
  final int? topK;
  final double? topP;
  final double? minP;
  final double? penaltyRepeat;
  final double? penaltyFreq;
  final double? dryMultiplier;

  Map<String, dynamic> toJson() => {
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (ttftTimeoutMs != null) 'ttft_timeout_ms': ttftTimeoutMs,
        if (seed != null) 'seed': seed,
        if (temperature != null) 'temperature': temperature,
        if (topK != null) 'top_k': topK,
        if (topP != null) 'top_p': topP,
        if (minP != null) 'min_p': minP,
        if (penaltyRepeat != null) 'penalty_repeat': penaltyRepeat,
        if (penaltyFreq != null) 'penalty_freq': penaltyFreq,
        if (dryMultiplier != null) 'dry_multiplier': dryMultiplier,
      };
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
    this.apiVersion,
    this.requestId,
    this.hsi,
    this.schema,
    this.system,
    this.messages = const [],
    this.generation,
  });

  final String instruction;
  final String? apiVersion;
  final String? requestId;
  final Map<String, dynamic>? hsi;
  final String? schema;
  final String? system;
  final List<SyniRuntimeMessage> messages;
  final SyniRuntimeGenerationConfig? generation;

  Map<String, dynamic> toJson() => {
        if (apiVersion != null) 'api_version': apiVersion,
        if (requestId != null) 'request_id': requestId,
        'instruction': instruction,
        if (hsi != null) 'hsi': hsi,
        if (schema != null) 'schema': schema,
        if (system != null) 'system': system,
        if (messages.isNotEmpty)
          'messages': messages.map((message) => message.toJson()).toList(),
        if (generation != null) 'generation': generation!.toJson(),
      };
}

class SyniRuntimeProvenance {
  const SyniRuntimeProvenance({
    required this.backend,
    required this.accelerator,
    required this.runtimeVersion,
    this.modelId,
  });

  final String backend;
  final String accelerator;
  final String runtimeVersion;
  final String? modelId;

  factory SyniRuntimeProvenance.fromMap(Map<dynamic, dynamic> map) =>
      SyniRuntimeProvenance(
        backend: _asString(map['backend']) ?? 'unknown',
        accelerator: _asString(map['accelerator']) ?? 'unknown',
        runtimeVersion: _asString(map['runtime_version']) ?? 'unknown',
        modelId: _asString(map['model_id']),
      );
}

class SyniRuntimeCapabilities {
  const SyniRuntimeCapabilities({
    required this.apiVersions,
    required this.backend,
    required this.accelerator,
    required this.supportsSystemRole,
    required this.generationControls,
    required this.supportsStructuredDecoding,
    required this.supportsStreaming,
    required this.streamsDisplayText,
    required this.supportsProvenance,
    required this.isLegacy,
  });

  final List<String> apiVersions;
  final String backend;
  final String accelerator;
  final bool supportsSystemRole;
  final Set<String> generationControls;
  final bool supportsStructuredDecoding;
  final bool supportsStreaming;
  final bool streamsDisplayText;
  final bool supportsProvenance;
  final bool isLegacy;

  factory SyniRuntimeCapabilities.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw SyniRuntimeError.protocol(
          'runtime capabilities were not an object');
    }
    final versions = decoded['api_versions'];
    final roles = decoded['roles'];
    final generation = decoded['generation'];
    final streaming = decoded['streaming'];
    return SyniRuntimeCapabilities(
      apiVersions: versions is List
          ? versions.whereType<String>().toList(growable: false)
          : const [],
      backend: _asString(decoded['backend']) ?? 'unknown',
      accelerator: _asString(decoded['accelerator']) ?? 'unknown',
      supportsSystemRole: roles is Map && roles['system'] == true,
      generationControls: generation is Map
          ? generation.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key.toString())
              .toSet()
          : const {},
      supportsStructuredDecoding: decoded['structured_decoding'] == true,
      supportsStreaming: streaming is Map && streaming['supported'] == true,
      streamsDisplayText:
          streaming is Map && streaming['display_text_deltas'] == true,
      supportsProvenance: decoded['provenance'] == true,
      isLegacy: false,
    );
  }

  static const legacy = SyniRuntimeCapabilities(
    apiVersions: ['1.0'],
    backend: 'unknown',
    accelerator: 'unknown',
    supportsSystemRole: false,
    generationControls: {},
    supportsStructuredDecoding: true,
    supportsStreaming: true,
    streamsDisplayText: false,
    supportsProvenance: false,
    isLegacy: true,
  );
}

/// Best-effort `String` extraction: returns null for a non-string value rather
/// than throwing, so a malformed field can't crash envelope parsing.
String? _asString(dynamic v) => v is String ? v : null;

/// Schema-validated response from the runtime.
class SyniRuntimeResponse {
  SyniRuntimeResponse._(
    this.rawJson,
    this.data, {
    this.apiVersion,
    this.requestId,
    this.finishReason,
    this.provenance,
    this.isFallback = false,
    this.fallbackReason,
    this.underlyingErrorCode,
    this.retryable = false,
  });

  /// Raw JSON string returned by the runtime (already grammar-constrained
  /// and validated against the persona's output schema).
  final String rawJson;

  /// Parsed top-level map. Field set depends on the persona's response
  /// schema (`chat_response`, `coach_response`, `suggestions`, …).
  final dynamic data;

  final String? apiVersion;
  final String? requestId;
  final String? finishReason;
  final SyniRuntimeProvenance? provenance;

  /// True when the runtime substituted a deterministic fallback for unusable
  /// model output. Defaults to false — including for an older runtime that
  /// emits no `meta` (absence ⇒ treated as a genuine answer). Clients must use
  /// this instead of matching the fallback's English text.
  final bool isFallback;

  /// Raw reason the model output was rejected (e.g. `timeout`), when
  /// [isFallback]. Null otherwise.
  final String? fallbackReason;

  /// Stable code classifying the underlying failure behind a fallback
  /// (`INVALID_JSON`, `SCHEMA`, `TIMEOUT`, …), when [isFallback]. Null otherwise.
  final String? underlyingErrorCode;

  /// Whether the underlying failure behind a fallback was transient. False
  /// when [isFallback] is false.
  final bool retryable;

  /// Parse a runtime response string.
  ///
  /// - A success is the bare payload (`{"type":…,"data":…}`), optionally with a
  ///   sibling `meta` object when a fallback was substituted.
  /// - A failure is the runtime's `{"ok":false,"error":{…}}` envelope —
  ///   rethrown as a typed [SyniRuntimeError] carrying `code`/`retryable`, so a
  ///   failure never masquerades as a valid (but fieldless) response.
  /// - Malformed native output (non-JSON, non-object) becomes a typed
  ///   [SyniRuntimeError.protocol] rather than a leaked `FormatException` or a
  ///   silent unknown success.
  factory SyniRuntimeResponse.fromJson(String json) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw SyniRuntimeError.protocol(
          'runtime returned malformed JSON: ${e.message}');
    }

    if (decoded is! Map) {
      throw SyniRuntimeError.protocol(
        'runtime returned a non-object response (${decoded.runtimeType})',
      );
    }

    // Failure envelope: `ok` explicitly false. A missing/other `ok` is a
    // success payload (the backward-compatible bare-payload contract).
    if (decoded['ok'] == false) {
      final error = decoded['error'];
      throw SyniRuntimeError.fromEnvelope(
        error is Map
            ? error.cast<String, dynamic>()
            : const <String, dynamic>{},
      );
    }

    // Optional fallback metadata — present only when the runtime substituted a
    // fallback. Absent ⇒ genuine answer (or an older runtime).
    var isFallback = false;
    String? fallbackReason;
    String? underlyingErrorCode;
    var retryable = false;
    final meta = decoded['meta'];
    if (meta is Map && meta['fallback_used'] == true) {
      isFallback = true;
      fallbackReason = _asString(meta['fallback_reason']);
      underlyingErrorCode = _asString(meta['error_code']);
      retryable = meta['retryable'] == true;
    }

    SyniRuntimeProvenance? provenance;
    final provenanceMap = decoded['provenance'];
    if (provenanceMap is Map) {
      provenance = SyniRuntimeProvenance.fromMap(provenanceMap);
    }

    return SyniRuntimeResponse._(
      json,
      decoded,
      apiVersion: _asString(decoded['api_version']),
      requestId: _asString(decoded['request_id']),
      finishReason: _asString(decoded['finish_reason']),
      provenance: provenance,
      isFallback: isFallback,
      fallbackReason: fallbackReason,
      underlyingErrorCode: underlyingErrorCode,
      retryable: retryable,
    );
  }
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

  /// Native feature negotiation. Older runtime artifacts do not export the
  /// capability symbol and are represented honestly as [SyniRuntimeCapabilities.legacy].
  Future<SyniRuntimeCapabilities> capabilities() async {
    await initialize();
    final raw = await _worker!.capabilitiesJson();
    if (raw == null || raw.isEmpty) return SyniRuntimeCapabilities.legacy;
    return SyniRuntimeCapabilities.fromJson(raw);
  }

  /// Snapshot the runtime's telemetry ring buffer: recent on-device inference
  /// metrics, including per-fallback root-cause [SyniFallbackDiagnostics].
  ///
  /// Returns an empty list when the engine isn't loaded or nothing has been
  /// recorded yet. The sensitive diagnostic fields (`prompt` / `rawOutput`) are
  /// populated only when the runtime ran with `capture_diagnostics` enabled.
  Future<List<SyniInferenceMetric>> telemetry() async {
    await initialize();
    return parseTelemetry(await _worker!.telemetryJson());
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
    } on SyniRuntimeError {
      // Already typed (e.g. a failure envelope) — preserve code/retryable.
      rethrow;
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
    await for (final chunk in _worker!.runStream(
      preset.value,
      seed,
      jsonEncode(request.toJson()),
    )) {
      // The final chunk carries the runtime's response JSON, which may be a
      // `{"ok":false,"error":{…}}` failure envelope. Surface it as a typed
      // stream error rather than emitting an envelope as if it were content.
      if (chunk is SyniRuntimeStreamFinal) {
        final decoded = jsonDecode(chunk.rawJson);
        if (decoded is Map && decoded['ok'] == false) {
          final error = decoded['error'];
          throw SyniRuntimeError.fromEnvelope(
            error is Map
                ? error.cast<String, dynamic>()
                : const <String, dynamic>{},
          );
        }
      }
      yield chunk;
    }
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
