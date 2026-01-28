import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'ffi_bindings.dart';

/// Runtime error
class SyniRuntimeError implements Exception {
  final String message;
  SyniRuntimeError(this.message);
  @override
  String toString() => 'SyniRuntimeError: $message';
}

/// Preset for inference
enum SyniPreset {
  keyboard,
  coach,
  chat,
}

/// Request for inference
class SyniRuntimeRequest {
  final String instruction;
  final Map<String, dynamic>? hsi;
  final String? schema;

  const SyniRuntimeRequest({
    required this.instruction,
    this.hsi,
    this.schema,
  });

  Map<String, dynamic> toJson() {
    return {
      'instruction': instruction,
      if (hsi != null) 'hsi': hsi,
      if (schema != null) 'schema': schema,
    };
  }
}

/// Response from inference
class SyniRuntimeResponse {
  final String rawJson;
  final Map<String, dynamic> data;

  SyniRuntimeResponse(this.rawJson) : data = jsonDecode(rawJson);

  factory SyniRuntimeResponse.fromJson(String json) {
    return SyniRuntimeResponse(json);
  }
}

/// Syni Runtime wrapper using FFI
class SyniRuntime {
  Pointer<Void>? _engine;
  String? _modelPath;
  bool _initialized = false;

  /// Initialize the runtime
  void initialize() {
    if (_initialized) return;
    try {
      SyniRuntimeFFI.initialize();
      _initialized = true;
    } catch (e) {
      throw SyniRuntimeError('Failed to initialize FFI: $e');
    }
  }

  /// Get the runtime version
  String? getVersion() {
    if (!_initialized) initialize();
    return SyniRuntimeFFI.version();
  }

  /// Load a model from a file path
  bool loadModel(String modelPath) {
    if (!_initialized) initialize();

    if (!File(modelPath).existsSync()) {
      throw SyniRuntimeError('Model file not found: $modelPath');
    }

    if (_engine == null) {
      _engine = SyniRuntimeFFI.engineNewWithModel(modelPath);
      if (_engine == null || _engine!.address == 0) {
        throw SyniRuntimeError('Failed to create engine with model');
      }
    } else {
      final success = SyniRuntimeFFI.engineLoadModel(_engine!, modelPath);
      if (!success) {
        throw SyniRuntimeError('Failed to load model');
      }
    }

    _modelPath = modelPath;
    return true;
  }

  /// Download a model from a URL
  Future<String> downloadModel(String url, {String? filename}) async {
    if (!_initialized) initialize();

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/syni_models');
    if (!modelsDir.existsSync()) {
      modelsDir.createSync(recursive: true);
    }

    final name = filename ?? url.split('/').last;
    final modelPath = '${modelsDir.path}/$name';

    // Check if already downloaded
    if (File(modelPath).existsSync()) {
      return modelPath;
    }

    // Download the model
    print('Downloading model from $url...');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw SyniRuntimeError(
        'Failed to download model: ${response.statusCode}',
      );
    }

    // Save to file
    final file = File(modelPath);
    await file.writeAsBytes(response.bodyBytes);
    print('Model downloaded to $modelPath');

    return modelPath;
  }

  /// Run inference
  SyniRuntimeResponse run(
    SyniRuntimeRequest request, {
    SyniPreset preset = SyniPreset.chat,
    int seed = 0,
  }) {
    if (!_initialized) initialize();
    if (_engine == null || _engine!.address == 0) {
      throw SyniRuntimeError(
        'Model not loaded. Call loadModel() or downloadModel() first.',
      );
    }

    final requestJson = jsonEncode(request.toJson());
    final presetNative = _presetToNative(preset);

    final result = SyniRuntimeFFI.engineRunJson(
      _engine!,
      presetNative,
      seed,
      requestJson,
    );

    if (result == null) {
      throw SyniRuntimeError('Inference failed');
    }

    return SyniRuntimeResponse.fromJson(result);
  }

  SyniRuntimeFFI.SyniPreset _presetToNative(SyniPreset preset) {
    switch (preset) {
      case SyniPreset.keyboard:
        return SyniRuntimeFFI.SyniPreset.keyboard;
      case SyniPreset.coach:
        return SyniRuntimeFFI.SyniPreset.coach;
      case SyniPreset.chat:
        return SyniRuntimeFFI.SyniPreset.chat;
    }
  }

  /// Dispose resources
  void dispose() {
    if (_engine != null && _engine!.address != 0) {
      SyniRuntimeFFI.engineFree(_engine!);
      _engine = null;
    }
    _modelPath = null;
  }
}
