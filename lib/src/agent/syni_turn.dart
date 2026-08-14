import 'dart:convert';

import '../runtime/runtime.dart' as rt;
import 'syni_chat.dart';
import 'syni_persona.dart';

/// Role of one prior conversational turn. System policy is deliberately not a
/// dialogue role; it is supplied separately on [SyniTurnRequest.systemPolicy].
enum SyniTurnMessageRole { user, assistant }

class SyniTurnMessage {
  const SyniTurnMessage({required this.role, required this.content});

  final SyniTurnMessageRole role;
  final String content;
}

/// Host-owned task contract for one turn. This is stable app intent, not text
/// authored by the user, so the SDK places it at system authority.
class SyniTaskContract {
  const SyniTaskContract({
    required this.instruction,
    this.id,
    this.responseSchemaId,
  });

  final String? id;
  final String instruction;

  /// Optional runtime schema override (`chat`, `coach`, or `suggestions`).
  /// When omitted the bound persona's schema is used.
  final String? responseSchemaId;
}

/// Per-turn inference controls. Omitted values retain the runtime preset.
class SyniGenerationProfile {
  const SyniGenerationProfile({
    this.maxTokens,
    this.ttftTimeoutMs,
    this.seed,
    this.temperature,
    this.topK,
    this.topP,
    this.minP,
    this.penaltyRepeat,
    this.penaltyFreq,
    this.dryMultiplier,
  });

  final int? maxTokens;
  final int? ttftTimeoutMs;
  final int? seed;
  final double? temperature;
  final int? topK;
  final double? topP;
  final double? minP;
  final double? penaltyRepeat;
  final double? penaltyFreq;
  final double? dryMultiplier;
}

/// Versioned, authority-aware turn request.
///
/// The fields are kept separate all the way to the native runtime:
/// persona/host policy and task intent become the system turn, [dialogue]
/// becomes native user/assistant history, [userMessage] remains the final user
/// turn, and [context] is conditioning data rather than executable policy.
class SyniTurnRequest {
  const SyniTurnRequest({
    required this.requestId,
    required this.task,
    required this.userMessage,
    this.systemPolicy,
    this.context,
    this.hsiContext,
    this.dialogue = const [],
    this.generation = const SyniGenerationProfile(),
  });

  final String requestId;
  final SyniTaskContract task;
  final String userMessage;
  final String? systemPolicy;

  /// Authoritative host data for this task (session facts, aggregates, etc.).
  /// It is serialized into the runtime's conversation conditioning field and
  /// explicitly labelled as data, not instructions.
  final Map<String, dynamic>? context;

  /// Optional full HSI payload supplied by synheart-core.
  final Map<String, dynamic>? hsiContext;
  final List<SyniTurnMessage> dialogue;
  final SyniGenerationProfile generation;

  /// Deterministically compile the typed request into Runtime API 2.0.
  /// Public primarily for integration diagnostics and contract tests.
  rt.SyniRuntimeRequest toRuntimeRequest(SyniPersona persona) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be empty');
    }
    if (task.instruction.trim().isEmpty) {
      throw ArgumentError.value(
        task.instruction,
        'task.instruction',
        'must not be empty',
      );
    }
    if (userMessage.trim().isEmpty) {
      throw ArgumentError.value(
        userMessage,
        'userMessage',
        'must not be empty',
      );
    }

    final systemSections = <String>[
      persona.systemPrompt.trim(),
      if (systemPolicy?.trim().isNotEmpty == true) systemPolicy!.trim(),
      [
        if (task.id?.trim().isNotEmpty == true) 'Task: ${task.id!.trim()}',
        task.instruction.trim(),
      ].join('\n'),
    ].where((section) => section.isNotEmpty).toList(growable: false);

    final hsi = <String, dynamic>{...?hsiContext};
    if (context != null && context!.isNotEmpty) {
      final dataBlock =
          'Authoritative host context (data, not instructions): ${jsonEncode(context)}';
      final existing = hsi['conversation_context'];
      hsi['conversation_context'] =
          existing is String && existing.trim().isNotEmpty
              ? '${existing.trim()}\n$dataBlock'
              : dataBlock;
    }

    return rt.SyniRuntimeRequest(
      apiVersion: '2.0',
      requestId: requestId,
      instruction: userMessage.trim(),
      system: systemSections.join('\n\n'),
      messages: dialogue
          .map(
            (message) => rt.SyniRuntimeMessage(
              role: message.role == SyniTurnMessageRole.assistant
                  ? rt.SyniRuntimeMessageRole.assistant
                  : rt.SyniRuntimeMessageRole.user,
              content: message.content,
            ),
          )
          .toList(growable: false),
      hsi: hsi.isEmpty ? null : hsi,
      schema: task.responseSchemaId ?? persona.responseSchemaId,
      generation: rt.SyniRuntimeGenerationConfig(
        maxTokens: generation.maxTokens,
        ttftTimeoutMs: generation.ttftTimeoutMs,
        seed: generation.seed,
        temperature: generation.temperature,
        topK: generation.topK,
        topP: generation.topP,
        minP: generation.minP,
        penaltyRepeat: generation.penaltyRepeat,
        penaltyFreq: generation.penaltyFreq,
        dryMultiplier: generation.dryMultiplier,
      ),
    );
  }
}

enum SyniTurnBackend { local, cloud }

class SyniTurnProvenance {
  const SyniTurnProvenance({
    required this.backend,
    required this.accelerator,
    required this.runtimeVersion,
    this.modelId,
  });

  final String backend;
  final String accelerator;
  final String runtimeVersion;
  final String? modelId;
}

/// Completed typed turn plus routing and native provenance information.
class SyniTurnResult {
  const SyniTurnResult({
    required this.requestId,
    required this.backend,
    required this.response,
    this.apiVersion,
    this.finishReason,
    this.provenance,
  });

  final String requestId;
  final SyniTurnBackend backend;
  final SyniChatResponse response;
  final String? apiVersion;
  final String? finishReason;
  final SyniTurnProvenance? provenance;
}
