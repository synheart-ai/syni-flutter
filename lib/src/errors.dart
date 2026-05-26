/// The type of error that occurred during a Syni operation.
///
/// These errors are surfaced from the native SDKs and provide
/// consistent error handling across platforms.
enum SyniErrorType {
  /// The inference engine is not available (not downloaded, not supported, etc.)
  engineUnavailable,

  /// The request was invalid (missing required fields, invalid persona, etc.)
  invalidRequest,

  /// The operation timed out before completing.
  timeout,

  /// The operation was cancelled by the user or system.
  cancelled,

  /// The response did not conform to the expected schema.
  /// This should be rare as native SDKs should return fallback responses.
  schemaViolation,

  /// A platform-specific error occurred.
  platformError,
}

/// An error that occurred during a Syni operation.
class SyniError implements Exception {
  /// The type of error.
  final SyniErrorType type;

  /// A human-readable error message.
  final String message;

  /// Optional error code from the native SDK.
  final String? code;

  /// Optional additional details about the error.
  final Map<String, dynamic>? details;

  const SyniError({
    required this.type,
    required this.message,
    this.code,
    this.details,
  });

  /// Creates a [SyniError] from a platform exception map.
  factory SyniError.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] as String? ?? 'platformError';
    final type = SyniErrorType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => SyniErrorType.platformError,
    );

    return SyniError(
      type: type,
      message: map['message'] as String? ?? 'An unknown error occurred',
      code: map['code'] as String?,
      details: map['details'] as Map<String, dynamic>?,
    );
  }

  /// Creates an engine unavailable error.
  factory SyniError.engineUnavailable([String? message]) {
    return SyniError(
      type: SyniErrorType.engineUnavailable,
      message: message ?? 'The inference engine is not available',
    );
  }

  /// Creates an invalid request error.
  factory SyniError.invalidRequest([String? message]) {
    return SyniError(
      type: SyniErrorType.invalidRequest,
      message: message ?? 'The request was invalid',
    );
  }

  /// Creates a timeout error.
  factory SyniError.timeout([String? message]) {
    return SyniError(
      type: SyniErrorType.timeout,
      message: message ?? 'The operation timed out',
    );
  }

  /// Creates a cancelled error.
  factory SyniError.cancelled([String? message]) {
    return SyniError(
      type: SyniErrorType.cancelled,
      message: message ?? 'The operation was cancelled',
    );
  }

  /// Creates a schema violation error.
  factory SyniError.schemaViolation([String? message]) {
    return SyniError(
      type: SyniErrorType.schemaViolation,
      message: message ?? 'The response did not conform to the expected schema',
    );
  }

  /// Creates a platform error.
  factory SyniError.platformError([String? message]) {
    return SyniError(
      type: SyniErrorType.platformError,
      message: message ?? 'A platform error occurred',
    );
  }

  @override
  String toString() => 'SyniError(${type.name}): $message';
}
