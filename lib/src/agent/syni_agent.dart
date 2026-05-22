import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../runtime/runtime.dart' as rt;
import 'syni_chat.dart';
import 'syni_cloud_client.dart';
import 'syni_cloud_config.dart';
import 'syni_install_state.dart';
import 'syni_installer.dart';
import 'syni_model_spec.dart';
import 'syni_persona.dart';

/// Where a chat call should run.
///
/// - [localOnly]   — always candle on the worker isolate. Throws if no model
///   is installed. Offline-safe; never touches the network.
/// - [cloudOnly]   — always the Syni cloud. Throws if no cloud config was
///   injected. Server-side HSI via `include_state`.
/// - [localFirst]  — try local, fall back to cloud on failure or when local
///   isn't installed. Sensible default.
enum SyniExecutionMode { localOnly, cloudOnly, localFirst }

/// Orchestrates an installed, persona-bound Syni: install lifecycle, model
/// management, and chat over the local runtime worker isolate.
///
/// **Layering:** this is Syni's orchestration layer. It is HSI-agnostic — it
/// takes the conditioning context as a plain `Map<String, dynamic>?`
/// (`hsiContext`) and never imports a host-SDK type. The host SDK
/// (`synheart_core`) wraps this with its four-authority gate and its HSI
/// context builder; see `Synheart.syni`.
class SyniAgent {
  SyniAgent({
    SyniInstaller? installer,
    SyniCloudConfig? cloudConfig,
  })  : _installer = installer ?? SyniInstaller(),
        _cloudClient =
            cloudConfig != null ? SyniCloudClient(cloudConfig) : null;

  final SyniInstaller _installer;
  final rt.SyniRuntime _runtime = rt.SyniRuntime();
  final BehaviorSubject<SyniInstallState> _state =
      BehaviorSubject<SyniInstallState>.seeded(const SyniNotInstalled());

  /// Optional cloud client — null when no [SyniCloudConfig] was injected.
  /// When null, [SyniExecutionMode.cloudOnly] throws and [SyniExecutionMode.localFirst]
  /// has nowhere to fall back to.
  final SyniCloudClient? _cloudClient;

  SyniPersona? _persona;

  /// Whether a cloud client is configured (i.e. cloud chat is reachable).
  bool get hasCloud => _cloudClient != null;

  /// Stream of installation lifecycle events.
  Stream<SyniInstallState> get installState => _state.stream;

  /// Current installation state.
  SyniInstallState get currentState => _state.value;

  /// True iff [currentState] is [SyniInstalled].
  bool get isInstalled => _state.value is SyniInstalled;

  // -------------------------------------------------------------------------
  // Install / uninstall
  // -------------------------------------------------------------------------

  /// Install Syni: download + verify the model, load the engine, bind
  /// [persona]. Emits lifecycle events on [installState]; throws on failure
  /// (after emitting [SyniInstallFailed]).
  Future<void> install({
    required SyniPersona persona,
    required SyniModelSpec model,
  }) async {
    if (currentState is SyniInstalling) {
      throw StateError('install already in progress');
    }
    try {
      void emit(SyniInstallStage stage, double progress) {
        _state.add(SyniInstalling(stage: stage, progress: progress));
      }

      emit(SyniInstallStage.preflight, 0.0);

      final modelPath = await _installer.ensureModel(model, onProgress: emit);

      emit(SyniInstallStage.materializingPersona, 0.0);
      _persona = persona;
      emit(SyniInstallStage.materializingPersona, 1.0);

      emit(SyniInstallStage.loadingEngine, 0.0);
      await _runtime.initialize();
      await _runtime.loadModel(modelPath);
      final version = await _runtime.getVersion() ?? 'unknown';
      emit(SyniInstallStage.loadingEngine, 1.0);

      _state.add(SyniInstalled(
        personaId: persona.id,
        modelPath: modelPath,
        runtimeVersion: version,
      ));
    } catch (e) {
      _state.add(SyniInstallFailed(reason: e.toString(), cause: e));
      rethrow;
    }
  }

  /// Cold-start restore: if the model + tokenizer are already on disk for
  /// [model], bind [persona] and load the engine — no download. Otherwise
  /// leaves state as [SyniNotInstalled] and returns false.
  ///
  /// Idempotent. Safe to call from `initState`. Use this so the screen
  /// doesn't show the Install card with a download warning when the user
  /// has installed before.
  Future<bool> restoreInstallIfReady({
    required SyniPersona persona,
    required SyniModelSpec model,
  }) async {
    if (currentState is SyniInstalled || currentState is SyniInstalling) {
      return isInstalled;
    }
    if (!await _installer.isModelOnDisk(model)) return false;
    // Files present — install() will skip the download (file exists check)
    // and go straight to engine load.
    try {
      await install(persona: persona, model: model);
    } catch (_) {
      // Failure already emitted SyniInstallFailed; the screen handles it.
    }
    return isInstalled;
  }

  /// Free the engine + worker isolate. Keeps the downloaded model on disk —
  /// re-installing reuses it.
  Future<void> uninstall() async {
    await _runtime.dispose();
    _persona = null;
    _state.add(const SyniNotInstalled());
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  /// Run a single chat turn. [hsiContext] is the conditioning payload built
  /// by the host SDK (or null). [mode] picks local vs cloud — see
  /// [SyniExecutionMode].
  ///
  /// V1 note: all modes still require [install] to have completed (it's
  /// where the persona is bound). Allowing pure-cloud-without-local-model
  /// install is a V2 lifecycle change.
  Future<SyniChatResponse> chat(
    String message, {
    Map<String, dynamic>? hsiContext,
    int seed = 0,
    SyniExecutionMode mode = SyniExecutionMode.localFirst,
  }) async {
    final (_, persona) = _requireReady();
    Future<SyniChatResponse> local() =>
        _localChat(persona, message, hsiContext, seed);
    Future<SyniChatResponse> cloud() =>
        _cloudChat(persona, message, hsiContext);
    return _route(mode, local, cloud);
  }

  /// Streaming counterpart to [chat]. Emits [SyniChatDelta]s as tokens
  /// arrive, then exactly one [SyniChatFinal].
  Stream<SyniChatEvent> chatStream(
    String message, {
    Map<String, dynamic>? hsiContext,
    int seed = 0,
    SyniExecutionMode mode = SyniExecutionMode.localFirst,
  }) async* {
    final (_, persona) = _requireReady();
    Stream<SyniChatEvent> local() =>
        _localChatStream(persona, message, hsiContext, seed);
    Stream<SyniChatEvent> cloud() =>
        _cloudChatStream(persona, message, hsiContext);
    yield* _routeStream(mode, local, cloud);
  }

  // -------------------------------------------------------------------------
  // Routing
  // -------------------------------------------------------------------------

  Future<SyniChatResponse> _route(
    SyniExecutionMode mode,
    Future<SyniChatResponse> Function() local,
    Future<SyniChatResponse> Function() cloud,
  ) async {
    switch (mode) {
      case SyniExecutionMode.localOnly:
        return local();
      case SyniExecutionMode.cloudOnly:
        if (_cloudClient == null) {
          throw StateError(
              'cloudOnly requested but no SyniCloudConfig injected');
        }
        return cloud();
      case SyniExecutionMode.localFirst:
        try {
          return await local();
        } catch (e) {
          if (_cloudClient == null) rethrow;
          return cloud();
        }
    }
  }

  Stream<SyniChatEvent> _routeStream(
    SyniExecutionMode mode,
    Stream<SyniChatEvent> Function() local,
    Stream<SyniChatEvent> Function() cloud,
  ) async* {
    switch (mode) {
      case SyniExecutionMode.localOnly:
        yield* local();
      case SyniExecutionMode.cloudOnly:
        if (_cloudClient == null) {
          throw StateError(
              'cloudOnly requested but no SyniCloudConfig injected');
        }
        yield* cloud();
      case SyniExecutionMode.localFirst:
        // Probe the local stream; on first-event failure, fall back to cloud.
        // (Mid-stream local failures abort and don't fall back — partial
        // output to the UI shouldn't be retried with a different backend.)
        var producedAny = false;
        try {
          await for (final e in local()) {
            producedAny = true;
            yield e;
          }
          return;
        } catch (e) {
          if (producedAny || _cloudClient == null) rethrow;
          yield* cloud();
        }
    }
  }

  // -------------------------------------------------------------------------
  // Local path (candle runtime)
  // -------------------------------------------------------------------------

  Future<SyniChatResponse> _localChat(
    SyniPersona persona,
    String message,
    Map<String, dynamic>? hsiContext,
    int seed,
  ) async {
    final installed = currentState as SyniInstalled;
    final raw = await _runtime.run(
      rt.SyniRuntimeRequest(
        instruction: _formatInstruction(persona, message),
        hsi: hsiContext,
        schema: persona.responseSchemaId,
      ),
      preset: _presetForSchema(persona.responseSchemaId),
      seed: seed,
    );
    return SyniChatResponse.fromRuntimeJson(
      raw.rawJson,
      personaId: persona.id,
      runtimeVersion: installed.runtimeVersion,
    );
  }

  Stream<SyniChatEvent> _localChatStream(
    SyniPersona persona,
    String message,
    Map<String, dynamic>? hsiContext,
    int seed,
  ) async* {
    final installed = currentState as SyniInstalled;
    final stream = _runtime.runStream(
      rt.SyniRuntimeRequest(
        instruction: _formatInstruction(persona, message),
        hsi: hsiContext,
        schema: persona.responseSchemaId,
      ),
      preset: _presetForSchema(persona.responseSchemaId),
      seed: seed,
    );
    await for (final chunk in stream) {
      if (chunk is rt.SyniRuntimeStreamDelta) {
        yield SyniChatDelta(chunk.text);
      } else if (chunk is rt.SyniRuntimeStreamFinal) {
        yield SyniChatFinal(SyniChatResponse.fromRuntimeJson(
          chunk.rawJson,
          personaId: persona.id,
          runtimeVersion: installed.runtimeVersion,
        ));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Cloud path
  // -------------------------------------------------------------------------

  Future<SyniChatResponse> _cloudChat(
    SyniPersona persona,
    String message,
    Map<String, dynamic>? hsiContext,
  ) {
    return _cloudClient!.chat(
      message: message,
      persona: persona,
      hsiContext: hsiContext,
    );
  }

  Stream<SyniChatEvent> _cloudChatStream(
    SyniPersona persona,
    String message,
    Map<String, dynamic>? hsiContext,
  ) {
    return _cloudClient!.chatStream(
      message: message,
      persona: persona,
      hsiContext: hsiContext,
    );
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  (SyniInstalled, SyniPersona) _requireReady() {
    final s = currentState;
    if (s is! SyniInstalled) {
      throw StateError('Syni is not installed. Call install() first.');
    }
    final p = _persona;
    if (p == null) throw StateError('persona missing (internal)');
    return (s, p);
  }

  /// V1: prepend the persona's system prompt inline. V2: have the runtime
  /// resolve the persona rather than baking it into the instruction string.
  String _formatInstruction(SyniPersona persona, String userMessage) {
    return '${persona.systemPrompt}\n\nUser: $userMessage';
  }

  rt.SyniPreset _presetForSchema(String schemaId) {
    switch (schemaId) {
      case 'suggestions':
        return rt.SyniPreset.keyboard;
      case 'coach':
        return rt.SyniPreset.coach;
      case 'chat':
      default:
        return rt.SyniPreset.chat;
    }
  }

  /// For testing / shutdown. Closes the state stream and disposes the
  /// underlying runtime.
  Future<void> dispose() async {
    await _runtime.dispose();
    await _state.close();
  }
}
