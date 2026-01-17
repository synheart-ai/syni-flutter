/// Metadata about a Syni response.
class SyniResponseMeta {
  /// The schema ID used for this response.
  final String schemaId;

  /// The persona ID that handled this request.
  final String personaId;

  /// The engine that processed this request (e.g., "local", "cloud").
  final String? engine;

  /// Processing duration in milliseconds.
  final int? durationMs;

  /// Whether this is a fallback response due to an error.
  final bool isFallback;

  const SyniResponseMeta({
    required this.schemaId,
    required this.personaId,
    this.engine,
    this.durationMs,
    this.isFallback = false,
  });

  factory SyniResponseMeta.fromMap(Map<String, dynamic> map) {
    return SyniResponseMeta(
      schemaId: map['schemaId'] as String? ?? 'unknown',
      personaId: map['personaId'] as String? ?? 'unknown',
      engine: map['engine'] as String?,
      durationMs: map['durationMs'] as int?,
      isFallback: map['isFallback'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaId': schemaId,
      'personaId': personaId,
      if (engine != null) 'engine': engine,
      if (durationMs != null) 'durationMs': durationMs,
      'isFallback': isFallback,
    };
  }
}

/// A response from the Syni SDK.
class SyniResponse {
  /// The raw structured output as a map.
  /// This is the schema-validated JSON output from the native SDK.
  final Map<String, dynamic> outputJson;

  /// Metadata about this response.
  final SyniResponseMeta meta;

  const SyniResponse({
    required this.outputJson,
    required this.meta,
  });

  /// Creates a [SyniResponse] from a map.
  factory SyniResponse.fromMap(Map<String, dynamic> map) {
    return SyniResponse(
      outputJson: map['outputJson'] as Map<String, dynamic>? ?? {},
      meta: SyniResponseMeta.fromMap(
        map['meta'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Converts this response to a map.
  Map<String, dynamic> toMap() {
    return {
      'outputJson': outputJson,
      'meta': meta.toMap(),
    };
  }
}
