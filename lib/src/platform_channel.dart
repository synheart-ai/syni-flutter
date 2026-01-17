import 'dart:convert';
import 'package:flutter/services.dart';
import 'errors.dart';

/// The platform channel interface for Syni native SDK communication.
class SyniPlatformChannel {
  /// The method channel for Syni SDK calls.
  static const MethodChannel _methodChannel =
      MethodChannel('com.synheart.syni/sdk');

  /// Singleton instance.
  static final SyniPlatformChannel instance = SyniPlatformChannel._();

  SyniPlatformChannel._();

  /// Initializes the native SDK with the given configuration.
  ///
  /// Returns the native SDK version and spec version for compatibility checking.
  Future<Map<String, dynamic>> initialize(Map<String, dynamic> config) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'initialize',
        jsonEncode(config),
      );
      return result != null ? jsonDecode(result) as Map<String, dynamic> : {};
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Generates a response for the given request.
  Future<Map<String, dynamic>> generate(Map<String, dynamic> request) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'generate',
        jsonEncode(request),
      );
      if (result == null) {
        throw SyniError.platformError('No response received from native SDK');
      }
      return jsonDecode(result) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Gets the list of available models (optional).
  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('getModels');
      if (result == null) {
        return [];
      }
      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Downloads a model by ID (optional).
  Future<void> downloadModel(String modelId) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'downloadModel',
        jsonEncode({'modelId': modelId}),
      );
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Deletes a model by ID (optional).
  Future<void> deleteModel(String modelId) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'deleteModel',
        jsonEncode({'modelId': modelId}),
      );
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Handles platform exceptions and converts them to [SyniError].
  SyniError _handlePlatformException(PlatformException e) {
    final errorType = _parseErrorType(e.code);
    return SyniError(
      type: errorType,
      message: e.message ?? 'An unknown platform error occurred',
      code: e.code,
      details: e.details is Map<String, dynamic>
          ? e.details as Map<String, dynamic>
          : null,
    );
  }

  /// Parses the error type from the platform exception code.
  SyniErrorType _parseErrorType(String code) {
    switch (code) {
      case 'ENGINE_UNAVAILABLE':
        return SyniErrorType.engineUnavailable;
      case 'INVALID_REQUEST':
        return SyniErrorType.invalidRequest;
      case 'TIMEOUT':
        return SyniErrorType.timeout;
      case 'CANCELLED':
        return SyniErrorType.cancelled;
      case 'SCHEMA_VIOLATION':
        return SyniErrorType.schemaViolation;
      default:
        return SyniErrorType.platformError;
    }
  }
}
