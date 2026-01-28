import 'dart:io';
import 'package:syni/src/runtime/runtime.dart';

/// Example usage of SyniRuntime with a local GGUF model
Future<void> main() async {
  final runtime = SyniRuntime();
  
  try {
    // Initialize
    runtime.initialize();
    print('Syni Runtime version: ${runtime.getVersion()}');

    // Try to use local model first, download if not found
    String modelPath;
    
    // Option 1: Try local model file
    final localModelPath = '/Users/henok/Documents/synilife/syni-cli/gguf model/google_gemma-3-1b-it-Q4_K_M.gguf';
    
    if (File(localModelPath).existsSync()) {
      print('Using local model at $localModelPath');
      modelPath = localModelPath;
    } else {
      // Option 2: Download a model if local one not found
      print('Local model not found. Downloading model...');
      final modelUrl = 'https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_k_m.gguf';
      modelPath = await runtime.downloadModel(modelUrl);
      print('Model downloaded to $modelPath');
    }

    print('Loading model from $modelPath...');
    runtime.loadModel(modelPath);
    print('Model loaded successfully!');

    // Run inference
    print('\nRunning inference...');
    final request = SyniRuntimeRequest(
      instruction: 'Hello! How are you?',
      hsi: {
        'coherence': 0.8,
        'focus': 'high',
      },
    );

    final response = runtime.run(
      request,
      preset: SyniPreset.chat,
      seed: 42,
    );

    print('\nResponse:');
    print(response.rawJson);
    print('\nParsed data:');
    print(response.data);

    // Example with keyboard preset
    print('\n\nRunning keyboard inference...');
    final keyboardRequest = SyniRuntimeRequest(
      instruction: 'I feel',
    );

    final keyboardResponse = runtime.run(
      keyboardRequest,
      preset: SyniPreset.keyboard,
      seed: 42,
    );

    print('Keyboard response:');
    print(keyboardResponse.rawJson);

  } catch (e) {
    print('Error: $e');
  } finally {
    runtime.dispose();
  }
}
