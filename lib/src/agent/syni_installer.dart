import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'syni_install_state.dart';
import 'syni_model_spec.dart';

/// Downloads + verifies a model (GGUF + its `tokenizer.json` sibling). Emits
/// progress via the supplied callback. Returns the final on-disk model path.
class SyniInstaller {
  SyniInstaller();

  /// Where downloaded models live on the local filesystem.
  ///
  /// V1 uses the app's documents directory. V2 should move to the core
  /// runtime's encrypted cache directory so models inherit the same
  /// at-rest encryption as artifacts.
  Future<Directory> _modelsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/synheart_syni_models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Whether the GGUF model + its sibling `tokenizer.json` are already on
  /// disk for the given spec. Used by the cold-start restore path so the
  /// screen can skip the download UX when nothing actually needs downloading.
  Future<bool> isModelOnDisk(SyniModelSpec spec) async {
    final dir = await _modelsDir();
    final modelFile = File('${dir.path}/${spec.filename}');
    final tokenizerFile = File('${dir.path}/tokenizer.json');
    return modelFile.existsSync() && tokenizerFile.existsSync();
  }

  /// Returns the on-disk path the GGUF would live at — does NOT touch the
  /// filesystem. Pair with [isModelOnDisk] to drive a "load only, skip
  /// download" flow.
  Future<String> modelPathFor(SyniModelSpec spec) async {
    final dir = await _modelsDir();
    return '${dir.path}/${spec.filename}';
  }

  /// Total on-disk bytes occupied by [spec]'s model files (the GGUF plus its
  /// sibling `tokenizer.json`). Returns 0 when nothing is installed. Useful
  /// for telling the user how much storage a delete will reclaim.
  Future<int> installedBytes(SyniModelSpec spec) async {
    final dir = await _modelsDir();
    var total = 0;
    for (final file in [
      File('${dir.path}/${spec.filename}'),
      File('${dir.path}/tokenizer.json'),
    ]) {
      if (file.existsSync()) {
        try {
          total += file.lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Permanently deletes [spec]'s model files from disk — the GGUF and its
  /// sibling `tokenizer.json` — reclaiming the ~1.1 GB the install occupies.
  ///
  /// Returns the number of bytes actually freed. Idempotent: deleting when
  /// nothing is on disk is a no-op that returns 0. Throws
  /// [SyniInstallException] if a file exists but cannot be removed.
  ///
  /// This is the real counterpart to [ensureModel] — `SyniAgent.uninstall()`
  /// only frees the in-memory engine and leaves the download on disk.
  Future<int> deleteModel(SyniModelSpec spec) async {
    final dir = await _modelsDir();
    final freed = await installedBytes(spec);
    for (final file in [
      File('${dir.path}/${spec.filename}'),
      File('${dir.path}/tokenizer.json'),
    ]) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (e) {
          throw SyniInstallException(
            'failed to delete model file ${file.path}: $e',
          );
        }
      }
    }
    return freed;
  }

  /// Returns the path to the model file. Downloads the GGUF and its sibling
  /// `tokenizer.json` if not already on disk. Calls [onProgress] with the
  /// bytes-downloaded fraction.
  ///
  /// The candle backend resolves the tokenizer as a `tokenizer.json` sibling
  /// of the GGUF, so both land in the same directory.
  Future<String> ensureModel(
    SyniModelSpec spec, {
    required void Function(SyniInstallStage, double) onProgress,
  }) async {
    final dir = await _modelsDir();
    final path = '${dir.path}/${spec.filename}';
    final file = File(path);

    if (!file.existsSync()) {
      onProgress(SyniInstallStage.downloadingModel, 0.0);
      await _download(spec.downloadUrl, file, onProgress: (p) {
        // Reserve the last 5% of the download bar for the tokenizer.
        onProgress(SyniInstallStage.downloadingModel, p * 0.95);
      });
    }

    // tokenizer.json must sit next to the GGUF for the candle backend.
    final tokenizerFile = File('${dir.path}/tokenizer.json');
    if (!tokenizerFile.existsSync()) {
      await _download(spec.tokenizerUrl, tokenizerFile, onProgress: (p) {
        onProgress(SyniInstallStage.downloadingModel, 0.95 + p * 0.05);
      });
    }
    onProgress(SyniInstallStage.downloadingModel, 1.0);

    if (spec.sha256.isNotEmpty) {
      onProgress(SyniInstallStage.verifyingModel, 0.0);
      final actual = await _sha256(file);
      onProgress(SyniInstallStage.verifyingModel, 1.0);
      if (actual.toLowerCase() != spec.sha256.toLowerCase()) {
        // Discard a possibly-corrupted file so the next attempt re-downloads.
        try {
          file.deleteSync();
        } catch (_) {}
        throw SyniInstallException(
          'model SHA-256 mismatch: expected ${spec.sha256}, got $actual',
        );
      }
    }

    return path;
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  Future<void> _download(
    String url,
    File outFile, {
    required void Function(double) onProgress,
  }) async {
    final req = http.Request('GET', Uri.parse(url));
    final streamed = await http.Client().send(req);
    if (streamed.statusCode != 200) {
      throw SyniInstallException(
        'model download HTTP ${streamed.statusCode} for $url',
      );
    }
    final total = streamed.contentLength ?? 0;
    final sink = outFile.openWrite();
    var received = 0;
    try {
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    onProgress(1.0);
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

class SyniInstallException implements Exception {
  SyniInstallException(this.message);
  final String message;

  @override
  String toString() => 'SyniInstallException: $message';
}
