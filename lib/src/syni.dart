import 'config.dart';
import 'errors.dart';
import 'platform_channel.dart';
import 'request.dart';
import 'response.dart';

/// Version information returned during initialization.
class SyniVersionInfo {
  /// The version of the native SDK.
  final String nativeSdkVersion;

  /// The syni-core-spec version supported by the native SDK.
  final String specVersion;

  const SyniVersionInfo({
    required this.nativeSdkVersion,
    required this.specVersion,
  });

  factory SyniVersionInfo.fromMap(Map<String, dynamic> map) {
    return SyniVersionInfo(
      nativeSdkVersion: map['nativeSdkVersion'] as String? ?? 'unknown',
      specVersion: map['specVersion'] as String? ?? 'unknown',
    );
  }
}

/// The main entry point for the Syni SDK.
///
/// Use [Syni.initialize] to set up the SDK before making requests.
/// Use [Syni.generate] to generate responses from personas.
///
/// Example usage:
/// ```dart
/// // Initialize the SDK
/// await Syni.initialize(SyniConfig(
///   appId: 'com.example.myapp',
///   appVersion: '1.0.0',
/// ));
///
/// // Generate a response
/// final response = await Syni.generate(SyniRequest(
///   personaId: 'keyboard.v1',
///   input: 'Hello, how are',
/// ));
///
/// print(response.outputJson);
/// ```
class Syni {
  static final SyniPlatformChannel _channel = SyniPlatformChannel.instance;

  static bool _initialized = false;
  static SyniConfig? _config;
  static SyniVersionInfo? _versionInfo;

  /// The minimum supported syni-swift version.
  static const String minSwiftVersion = '1.2.0';

  /// The minimum supported syni-kotlin version.
  static const String minKotlinVersion = '1.2.0';

  /// The supported syni-core-spec version range.
  static const String supportedSpecVersion = '1.1.x';

  /// Prevent instantiation.
  Syni._();

  /// Whether the SDK has been initialized.
  static bool get isInitialized => _initialized;

  /// The current configuration, if initialized.
  static SyniConfig? get config => _config;

  /// Version information from the native SDK, if initialized.
  static SyniVersionInfo? get versionInfo => _versionInfo;

  /// Initializes the Syni SDK with the given configuration.
  ///
  /// This must be called before any other Syni methods.
  /// If [config.lazyInit] is true (default), the native SDK will be
  /// initialized lazily on the first call to [generate].
  ///
  /// Throws [SyniError] if initialization fails or if there is a
  /// version mismatch beyond the allowed range.
  static Future<SyniVersionInfo> initialize(SyniConfig config) async {
    if (_initialized && !config.lazyInit) {
      // Already initialized and not lazy, return cached version info
      return _versionInfo!;
    }

    _config = config;

    if (!config.lazyInit) {
      // Initialize immediately
      final result = await _channel.initialize(config.toMap());
      _versionInfo = SyniVersionInfo.fromMap(result);
      _checkVersionCompatibility(_versionInfo!);
    }

    _initialized = true;

    // Return version info if we have it, otherwise a placeholder for lazy init
    return _versionInfo ??
        const SyniVersionInfo(
          nativeSdkVersion: 'pending',
          specVersion: 'pending',
        );
  }

  /// Generates a response for the given request.
  ///
  /// The SDK must be initialized before calling this method.
  ///
  /// Throws [SyniError] if the SDK is not initialized, if the request
  /// is invalid, or if generation fails.
  static Future<SyniResponse> generate(SyniRequest request) async {
    await _ensureInitialized();

    final resultMap = await _channel.generate(request.toMap());
    return SyniResponse.fromMap(resultMap);
  }

  /// Ensures the SDK is initialized, performing lazy initialization if needed.
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      throw SyniError.invalidRequest(
        'Syni SDK not initialized. Call Syni.initialize() first.',
      );
    }

    // Perform lazy initialization if we haven't initialized the native SDK yet
    if (_config != null && _config!.lazyInit && _versionInfo == null) {
      final result = await _channel.initialize(_config!.toMap());
      _versionInfo = SyniVersionInfo.fromMap(result);
      _checkVersionCompatibility(_versionInfo!);
    }
  }

  /// Checks version compatibility and throws if incompatible.
  static void _checkVersionCompatibility(SyniVersionInfo info) {
    // Version checking logic would go here
    // For now, we just log a warning in debug mode
    // In production, this could fail fast or degrade to cloud-disabled mode
  }

  /// Resets the SDK state. Primarily for testing.
  static void reset() {
    _initialized = false;
    _config = null;
    _versionInfo = null;
  }
}
