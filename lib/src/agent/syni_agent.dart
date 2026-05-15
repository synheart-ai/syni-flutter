import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../runtime/runtime.dart' as rt;
import 'syni_chat.dart';
import 'syni_install_state.dart';
import 'syni_installer.dart';
import 'syni_model_spec.dart';
import 'syni_persona.dart';

/// Orchestrates an installed, persona-bound Syni: install lifecycle, model
/// management, and chat over the local runtime worker isolate.
///
/// **Layering:** this is Syni's orchestration layer. It is HSI-agnostic — it
/// takes the conditioning context as a plain `Map<String, dynamic>?`
/// (`hsiContext`) and never imports a host-SDK type. The host SDK
/// (`synheart_core`) wraps this with its four-authority gate and its HSI
/// context builder; see `Synheart.syni`.
class SyniAgent {
  SyniAgent({SyniInstaller? installer})
      : _installer = installer ?? SyniInstaller();

  final SyniInstaller _installer;
  final rt.SyniRuntime _runtime = rt.SyniRuntime();
  final BehaviorSubject<SyniInstallState> _state =
      BehaviorSubject<SyniInstallState>.seeded(const SyniNotInstalled());

  SyniPersona? _persona;

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
  /// by the host SDK (or null — the runtime renders nothing for it).
  Future<SyniChatResponse> chat(
    String message, {
    Map<String, dynamic>? hsiContext,
    int seed = 0,
  }) async {
    final (installed, persona) = _requireReady();
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

  /// Streaming counterpart to [chat]. Emits [SyniChatDelta]s as tokens
  /// arrive, then exactly one [SyniChatFinal].
  Stream<SyniChatEvent> chatStream(
    String message, {
    Map<String, dynamic>? hsiContext,
    int seed = 0,
  }) async* {
    final (installed, persona) = _requireReady();
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
