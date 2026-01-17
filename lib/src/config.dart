/// Configuration options for the Syni SDK.
class SyniConfig {
  /// Application identifier for telemetry and logging.
  final String? appId;

  /// Application version for telemetry.
  final String? appVersion;

  /// Device class identifier (e.g., "phone", "tablet").
  final String? deviceClass;

  /// Whether to enable debug logging.
  /// Debug logging is scrubbed of sensitive data.
  final bool debugLogging;

  /// Whether to lazily initialize the native SDK on first call.
  /// If false, initialization happens immediately.
  final bool lazyInit;

  /// Additional configuration options passed to the native SDK.
  final Map<String, dynamic>? additionalConfig;

  const SyniConfig({
    this.appId,
    this.appVersion,
    this.deviceClass,
    this.debugLogging = false,
    this.lazyInit = true,
    this.additionalConfig,
  });

  /// Converts this config to a JSON-serializable map.
  Map<String, dynamic> toMap() {
    return {
      if (appId != null) 'appId': appId,
      if (appVersion != null) 'appVersion': appVersion,
      if (deviceClass != null) 'deviceClass': deviceClass,
      'debugLogging': debugLogging,
      'lazyInit': lazyInit,
      if (additionalConfig != null) ...additionalConfig!,
    };
  }

  /// Creates a [SyniConfig] from a map.
  factory SyniConfig.fromMap(Map<String, dynamic> map) {
    return SyniConfig(
      appId: map['appId'] as String?,
      appVersion: map['appVersion'] as String?,
      deviceClass: map['deviceClass'] as String?,
      debugLogging: map['debugLogging'] as bool? ?? false,
      lazyInit: map['lazyInit'] as bool? ?? true,
      additionalConfig: map['additionalConfig'] as Map<String, dynamic>?,
    );
  }
}
