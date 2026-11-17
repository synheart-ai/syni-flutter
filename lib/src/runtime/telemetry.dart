import 'dart:convert';

/// Typed view over the runtime's telemetry snapshot (`syni_telemetry_json`).
///
/// Parsing is defensive: unknown / missing / wrong-typed fields degrade to
/// sensible defaults rather than throwing, so a runtime that adds fields (or an
/// older one that omits them) never breaks the SDK.

/// One recorded on-device inference. Mirrors the runtime's `InferenceMetrics`.
class SyniInferenceMetric {
  const SyniInferenceMetric({
    required this.startedAtUnixMs,
    required this.durationMs,
    required this.preset,
    required this.success,
    required this.schemaValid,
    required this.retries,
    required this.fallbackUsed,
    this.requestId,
    this.errorCode,
    this.fallbackReason,
    this.diagnostics,
    this.phases,
  });

  final int startedAtUnixMs;
  final int durationMs;
  final String preset;
  final bool success;
  final bool schemaValid;
  final int retries;

  /// Whether a deterministic fallback was substituted for model output.
  final bool fallbackUsed;

  /// Correlates this metric with a V2 turn response, or null for legacy calls.
  final String? requestId;

  /// Stable code the fallback papered over (`TIMEOUT`, `SCHEMA`, …), or null.
  final String? errorCode;

  /// Raw reason paired with [errorCode], or null.
  final String? fallbackReason;

  /// Root-cause debugging context — present only on a fallback.
  final SyniFallbackDiagnostics? diagnostics;

  /// Prompt reading (prefill) and answer writing (decode), timed apart, or
  /// null when the runtime does not report them (before syni-runtime 0.7).
  final SyniPhaseStats? phases;

  factory SyniInferenceMetric.fromMap(Map<String, dynamic> m) {
    final diag = m['diagnostics'];
    final phases = m['phases'];
    return SyniInferenceMetric(
      startedAtUnixMs: _int(m['started_at_unix_ms']),
      durationMs: _int(m['duration_ms']),
      preset: _str(m['preset']) ?? '',
      success: m['success'] == true,
      schemaValid: m['schema_valid'] == true,
      retries: _int(m['retries']),
      fallbackUsed: m['fallback_used'] == true,
      requestId: _str(m['request_id']),
      errorCode: _str(m['error_code']),
      fallbackReason: _str(m['fallback_reason']),
      diagnostics: diag is Map
          ? SyniFallbackDiagnostics.fromMap(diag.cast<String, dynamic>())
          : null,
      phases: phases is Map
          ? SyniPhaseStats.fromMap(phases.cast<String, dynamic>())
          : null,
    );
  }
}

/// Per-phase token counts and wall time for one generation.
class SyniPhaseStats {
  const SyniPhaseStats({
    required this.promptTokens,
    required this.reusedTokens,
    required this.prefillTokens,
    required this.prefillMs,
    required this.decodedTokens,
    required this.decodeMs,
  });

  /// Prompt length in tokens.
  final int promptTokens;

  /// Leading prompt tokens reused from the KV cache, so not read again.
  final int reusedTokens;

  /// Prompt tokens actually read.
  final int prefillTokens;
  final int prefillMs;

  /// Tokens written.
  final int decodedTokens;
  final int decodeMs;

  /// Prompt-reading speed, or null when nothing was read.
  double? get prefillTokensPerSecond => prefillMs > 0 && prefillTokens > 0
      ? prefillTokens * 1000 / prefillMs
      : null;

  /// Writing speed, or null when nothing was written.
  double? get decodeTokensPerSecond => decodeMs > 0 && decodedTokens > 0
      ? decodedTokens * 1000 / decodeMs
      : null;

  factory SyniPhaseStats.fromMap(Map<String, dynamic> m) => SyniPhaseStats(
        promptTokens: _int(m['prompt_tokens']),
        reusedTokens: _int(m['reused_tokens']),
        prefillTokens: _int(m['prefill_tokens']),
        prefillMs: _int(m['prefill_ms']),
        decodedTokens: _int(m['decoded_tokens']),
        decodeMs: _int(m['decode_ms']),
      );
}

/// Root-cause context for a fallback. `prompt` / `rawOutput` are populated only
/// when the runtime ran with `capture_diagnostics` enabled (a debug opt-in);
/// they carry user + HSI data, so treat them as sensitive.
class SyniFallbackDiagnostics {
  const SyniFallbackDiagnostics({
    required this.seed,
    required this.schema,
    required this.maxTokens,
    required this.likelyTruncated,
    required this.attempts,
    this.prompt,
    this.rawOutput,
  });

  final int seed;
  final String schema;
  final int maxTokens;

  /// Heuristic: the last output looked truncated at the token budget.
  final bool likelyTruncated;

  /// Per-attempt failure breakdown (not just the last attempt).
  final List<SyniAttemptDiagnostic> attempts;

  /// The prompt fed to the model. **Sensitive**; null unless capture was on.
  final String? prompt;

  /// The raw failing model output. **Sensitive**; null unless capture was on.
  final String? rawOutput;

  factory SyniFallbackDiagnostics.fromMap(Map<String, dynamic> m) {
    final raw = m['attempts'];
    final attempts = raw is List
        ? raw
            .whereType<Map>()
            .map(
                (a) => SyniAttemptDiagnostic.fromMap(a.cast<String, dynamic>()))
            .toList()
        : const <SyniAttemptDiagnostic>[];
    return SyniFallbackDiagnostics(
      seed: _int(m['seed']),
      schema: _str(m['schema']) ?? '',
      maxTokens: _int(m['max_tokens']),
      likelyTruncated: m['likely_truncated'] == true,
      attempts: attempts,
      prompt: _str(m['prompt']),
      rawOutput: _str(m['raw_output']),
    );
  }
}

/// One generation attempt's failure.
class SyniAttemptDiagnostic {
  const SyniAttemptDiagnostic({
    required this.attempt,
    required this.errorCode,
    required this.errorMessage,
    required this.outputLen,
    required this.repairAttempted,
  });

  final int attempt;
  final String errorCode;
  final String errorMessage;
  final int outputLen;
  final bool repairAttempted;

  factory SyniAttemptDiagnostic.fromMap(Map<String, dynamic> m) =>
      SyniAttemptDiagnostic(
        attempt: _int(m['attempt']),
        errorCode: _str(m['error_code']) ?? 'UNKNOWN',
        errorMessage: _str(m['error_message']) ?? '',
        outputLen: _int(m['output_len']),
        repairAttempted: m['repair_attempted'] == true,
      );
}

/// Parse the raw telemetry JSON string (array of metrics) into typed values.
/// Returns an empty list for null, a parse error, or a non-array payload.
List<SyniInferenceMetric> parseTelemetry(String? json) {
  if (json == null || json.isEmpty) return const [];
  final dynamic decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((m) => SyniInferenceMetric.fromMap(m.cast<String, dynamic>()))
      .toList();
}

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
String? _str(dynamic v) => v is String ? v : null;
