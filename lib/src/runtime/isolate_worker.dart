import 'dart:async';
import 'dart:isolate';

import 'ffi_bindings.dart';

// ---------------------------------------------------------------------------
// Stream chunk types — emitted by `SyniRuntimeWorker.runStream`.
// ---------------------------------------------------------------------------

/// One chunk in a streaming inference response.
sealed class SyniRuntimeStreamChunk {
  const SyniRuntimeStreamChunk();
}

/// An incremental token (or token batch) emitted during generation.
class SyniRuntimeStreamDelta extends SyniRuntimeStreamChunk {
  const SyniRuntimeStreamDelta(this.text);
  final String text;

  @override
  String toString() => 'SyniRuntimeStreamDelta(${text.length} chars)';
}

/// Final accumulated JSON response, emitted exactly once when generation
/// completes. Always the last element of the stream before close.
class SyniRuntimeStreamFinal extends SyniRuntimeStreamChunk {
  const SyniRuntimeStreamFinal(this.rawJson);
  final String rawJson;

  @override
  String toString() => 'SyniRuntimeStreamFinal(${rawJson.length} chars)';
}

// ---------------------------------------------------------------------------
// Wire protocol — main isolate ↔ worker isolate
// ---------------------------------------------------------------------------
//
// Each command carries a [reply] SendPort the worker uses to deliver the
// result of that single command. The reply is either the success value or
// an [Exception]; the main side translates the exception back to throw.

sealed class _Cmd {
  const _Cmd(this.reply);
  final SendPort reply;
}

class _CmdLoadModel extends _Cmd {
  _CmdLoadModel(super.reply, this.path);
  final String path;
}

class _CmdRunJson extends _Cmd {
  _CmdRunJson(super.reply, this.preset, this.seed, this.requestJson);
  final int preset; // SyniPreset.value
  final int seed;
  final String requestJson;
}

/// Streaming request. [streamPort] receives each chunk as a String;
/// [reply] receives the final JSON string (or an Exception) when generation
/// completes.
class _CmdRunStream extends _Cmd {
  _CmdRunStream(
    super.reply,
    this.streamPort,
    this.preset,
    this.seed,
    this.requestJson,
  );
  final SendPort streamPort;
  final int preset;
  final int seed;
  final String requestJson;
}

class _CmdVersion extends _Cmd {
  _CmdVersion(super.reply);
}

class _CmdHealthcheck extends _Cmd {
  _CmdHealthcheck(super.reply);
}

class _CmdTelemetry extends _Cmd {
  _CmdTelemetry(super.reply);
}

class _CmdDispose extends _Cmd {
  _CmdDispose(super.reply);
}

// ---------------------------------------------------------------------------
// SyniRuntimeWorker — main-isolate handle to the engine-owning worker.
// ---------------------------------------------------------------------------

/// A handle to a dedicated worker isolate that owns the [SyniRuntimeFFI]
/// engine pointer.
///
/// All FFI calls happen on the worker isolate so they cannot block the
/// caller (UI) isolate. Each public method returns a [Future] that completes
/// when the worker has finished processing the request.
///
/// Lifecycle:
/// ```
/// final worker = await SyniRuntimeWorker.spawn();
/// await worker.loadModel('/path/to/model.gguf');
/// final json = await worker.runJson(SyniPreset.chat.value, 0, request);
/// await worker.dispose();
/// ```
class SyniRuntimeWorker {
  SyniRuntimeWorker._(this._workerPort, this._isolate);

  final SendPort _workerPort;
  final Isolate _isolate;
  bool _disposed = false;

  /// Spawn a worker isolate and wait for it to report back its inbox port.
  static Future<SyniRuntimeWorker> spawn() async {
    final init = ReceivePort();
    final isolate = await Isolate.spawn<SendPort>(_entry, init.sendPort);
    final workerPort = await init.first as SendPort;
    init.close();
    return SyniRuntimeWorker._(workerPort, isolate);
  }

  Future<T> _send<T>(_Cmd Function(SendPort reply) build) async {
    if (_disposed) {
      throw StateError('SyniRuntimeWorker is disposed');
    }
    final rx = ReceivePort();
    _workerPort.send(build(rx.sendPort));
    final res = await rx.first;
    rx.close();
    if (res is Exception) throw res;
    return res as T;
  }

  Future<void> loadModel(String path) =>
      _send<void>((reply) => _CmdLoadModel(reply, path));

  Future<String> runJson(int preset, int seed, String requestJson) =>
      _send<String>(
        (reply) => _CmdRunJson(reply, preset, seed, requestJson),
      );

  /// Run streaming inference. Returns a [Stream] that emits each token
  /// chunk as it is generated, and completes with the final accumulated
  /// JSON as the last event.
  ///
  /// Errors during generation are forwarded as stream errors. The stream
  /// closes once the worker reports completion (success or failure).
  Stream<SyniRuntimeStreamChunk> runStream(
    int preset,
    int seed,
    String requestJson,
  ) {
    final controller = StreamController<SyniRuntimeStreamChunk>();
    final streamRx = ReceivePort();
    final replyRx = ReceivePort();

    final streamSub = streamRx.listen((msg) {
      if (msg is String) controller.add(SyniRuntimeStreamDelta(msg));
    });

    replyRx.first.then((result) async {
      await streamSub.cancel();
      streamRx.close();
      replyRx.close();
      if (result is Exception) {
        controller.addError(result);
      } else if (result is String) {
        controller.add(SyniRuntimeStreamFinal(result));
      } else {
        controller.addError(Exception('worker returned unexpected: $result'));
      }
      await controller.close();
    });

    if (_disposed) {
      controller.addError(StateError('SyniRuntimeWorker is disposed'));
      streamRx.close();
      replyRx.close();
      controller.close();
    } else {
      _workerPort.send(_CmdRunStream(
        replyRx.sendPort,
        streamRx.sendPort,
        preset,
        seed,
        requestJson,
      ));
    }

    return controller.stream;
  }

  Future<String?> version() => _send<String?>((reply) => _CmdVersion(reply));

  Future<bool> healthcheck() => _send<bool>((reply) => _CmdHealthcheck(reply));

  /// Telemetry snapshot JSON (array of inference metrics), or null when the
  /// engine isn't loaded / nothing recorded yet.
  Future<String?> telemetryJson() =>
      _send<String?>((reply) => _CmdTelemetry(reply));

  /// Free the native engine and terminate the worker isolate.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _send<void>((reply) => _CmdDispose(reply));
    } catch (_) {
      // Worker may have died already; fall through to kill.
    }
    _isolate.kill(priority: Isolate.immediate);
  }

  // -------------------------------------------------------------------------
  // Worker isolate entry point
  // -------------------------------------------------------------------------

  static void _entry(SendPort mainPort) {
    final inbox = ReceivePort();
    mainPort.send(inbox.sendPort);

    SyniEngineNative? engine;

    void respond(SendPort reply, Object? result) {
      try {
        reply.send(result);
      } catch (_) {/* receiver gone; nothing we can do */}
    }

    inbox.listen((message) {
      // Each branch must call respond() exactly once with either the result
      // or an Exception. Unknown messages are dropped silently.
      try {
        switch (message) {
          case _CmdLoadModel(:final reply, :final path):
            if (engine == null) {
              final ptr = SyniRuntimeFFI.engineNewWithModel(path);
              if (ptr.address == 0) {
                respond(reply, Exception('engineNewWithModel returned null'));
                return;
              }
              engine = ptr;
            } else {
              final ok = SyniRuntimeFFI.engineLoadModel(engine!, path);
              if (!ok) {
                respond(reply, Exception('engineLoadModel returned false'));
                return;
              }
            }
            respond(reply, null);

          case _CmdRunJson(
              :final reply,
              :final preset,
              :final seed,
              :final requestJson
            ):
            if (engine == null) {
              respond(
                reply,
                StateError('engine not initialized — call loadModel first'),
              );
              return;
            }
            final out = SyniRuntimeFFI.engineRunJson(
              engine!,
              SyniPreset.fromValue(preset),
              seed,
              requestJson,
            );
            if (out == null) {
              respond(reply, Exception('engineRunJson returned null'));
              return;
            }
            respond(reply, out);

          case _CmdRunStream(
              :final reply,
              :final streamPort,
              :final preset,
              :final seed,
              :final requestJson
            ):
            if (engine == null) {
              respond(
                reply,
                StateError('engine not initialized — call loadModel first'),
              );
              return;
            }
            // Stream callback fires synchronously on this thread during the
            // blocking FFI call (NativeCallable.isolateLocal).
            final out = SyniRuntimeFFI.engineRunStreamJson(
              engine!,
              SyniPreset.fromValue(preset),
              seed,
              requestJson,
              (chunk) {
                try {
                  streamPort.send(chunk);
                } catch (_) {/* receiver gone */}
                return true; // V1: never cancel
              },
            );
            if (out == null) {
              respond(reply, Exception('engineRunStreamJson returned null'));
              return;
            }
            respond(reply, out);

          case _CmdVersion(:final reply):
            respond(reply, SyniRuntimeFFI.version());

          case _CmdHealthcheck(:final reply):
            // syni_engine_healthcheck not yet bound; placeholder.
            respond(reply, engine != null);

          case _CmdTelemetry(:final reply):
            // Null when no engine yet → SyniRuntime maps it to an empty list.
            respond(
              reply,
              engine == null ? null : SyniRuntimeFFI.telemetryJson(engine!),
            );

          case _CmdDispose(:final reply):
            if (engine != null) {
              SyniRuntimeFFI.engineFree(engine!);
              engine = null;
            }
            respond(reply, null);
            inbox.close();
        }
      } catch (e, st) {
        if (message is _Cmd) {
          respond(message.reply, Exception('worker error: $e\n$st'));
        }
      }
    });
  }
}
