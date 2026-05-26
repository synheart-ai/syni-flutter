import 'dart:convert';

/// Which `EngineResponse` variant the runtime returned.
enum SyniResponseKind { coach, chat, suggestions, unknown }

/// A completed Syni response.
///
/// Parses the runtime's *tagged* `EngineResponse` envelope —
/// `{"type":"coach","data":{...}}` — into a clean typed surface. Callers use
/// [message] / [suggestions] / [displayText] and never touch raw JSON.
class SyniChatResponse {
  SyniChatResponse._({
    required this.personaId,
    required this.runtimeVersion,
    required this.rawJson,
    required this.kind,
    required this.message,
    required this.suggestions,
  });

  /// The persona that produced this response.
  final String personaId;

  /// Runtime semver reported by `libsyni_ffi`.
  final String runtimeVersion;

  /// The runtime's raw final JSON — kept for debugging / telemetry. UI code
  /// should use [message] / [suggestions] / [displayText], not this.
  final String rawJson;

  /// Which `EngineResponse` variant this is.
  final SyniResponseKind kind;

  /// Primary reply text. Present for `coach` and `chat`; null for a pure
  /// `suggestions` response.
  final String? message;

  /// Suggestion texts. Populated for `coach` and `suggestions`.
  final List<String> suggestions;

  /// Best-effort display string — [message] if present, else the first
  /// suggestion, else a neutral placeholder. UI can render this directly.
  String get displayText {
    final m = message?.trim();
    if (m != null && m.isNotEmpty) return m;
    if (suggestions.isNotEmpty) return suggestions.first;
    return 'Syni had no response.';
  }

  /// Parse the runtime's final `EngineResponse` JSON string. Tolerant of
  /// unexpected shapes — falls back to [SyniResponseKind.unknown].
  factory SyniChatResponse.fromRuntimeJson(
    String rawJson, {
    required String personaId,
    required String runtimeVersion,
  }) {
    var kind = SyniResponseKind.unknown;
    String? message;
    final suggestions = <String>[];

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map) {
          switch (decoded['type']) {
            case 'coach':
              kind = SyniResponseKind.coach;
              message = data['message']?.toString();
              suggestions.addAll(_suggestionTexts(data['suggestions']));
            case 'chat':
              kind = SyniResponseKind.chat;
              message = data['message']?.toString();
            case 'suggestions':
              kind = SyniResponseKind.suggestions;
              suggestions.addAll(_suggestionTexts(data['suggestions']));
          }
        }
      }
    } catch (_) {/* leave as unknown */}

    return SyniChatResponse._(
      personaId: personaId,
      runtimeVersion: runtimeVersion,
      rawJson: rawJson,
      kind: kind,
      message: message,
      suggestions: suggestions,
    );
  }

  static List<String> _suggestionTexts(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => m['text']?.toString())
        .whereType<String>()
        .toList();
  }

  /// Build a response from a cloud `reply` string.
  ///
  /// The cloud's reply may be plain text (chat schema) or a structured-output
  /// JSON object — typically `{"response": "...", "suggested_action": "..."}`
  /// for the coach schema, or `{"message": "...", "suggestions": [...]}` for
  /// richer flavors. This factory parses JSON-shaped replies into typed
  /// fields so UI never renders raw JSON; on any parse error or unknown
  /// shape it falls back to the literal reply as plain chat.
  factory SyniChatResponse.fromCloudReply(
    String reply, {
    required String personaId,
    required String runtimeVersion,
  }) {
    var kind = SyniResponseKind.chat;
    String? message;
    final suggestions = <String>[];

    // Find the JSON object inside the reply, tolerating model preambles
    // and Markdown code fences (```json … ``` is what some cloud models
    // wrap structured-output replies in). Slice from the first `{` to the
    // matching last `}` and try to decode that.
    final trimmed = reply.trim();
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      final jsonCandidate = trimmed.substring(firstBrace, lastBrace + 1);
      try {
        final decoded = jsonDecode(jsonCandidate);
        if (decoded is Map) {
          // Coach schema (cloud): {response, suggested_action}.
          final response = decoded['response']?.toString();
          if (response != null && response.isNotEmpty) {
            kind = SyniResponseKind.coach;
            message = response;
            final action = decoded['suggested_action']?.toString();
            if (action != null && action.isNotEmpty) {
              suggestions.add(action);
            }
          } else {
            // Fallback schema: {message, suggestions}.
            final m = decoded['message']?.toString();
            if (m != null && m.isNotEmpty) {
              message = m;
              final raw = decoded['suggestions'];
              if (raw is List) {
                suggestions.addAll(raw.whereType<String>());
              }
            }
          }
        }
      } catch (_) {/* leave as plain chat */}
    }

    return SyniChatResponse._(
      personaId: personaId,
      runtimeVersion: runtimeVersion,
      rawJson: reply,
      kind: kind,
      message: message ?? reply,
      suggestions: suggestions,
    );
  }
}

// ---------------------------------------------------------------------------
// Streaming events — emitted by `SyniAgent.chatStream`.
// ---------------------------------------------------------------------------

/// One event in a streaming chat response. Discriminated union over
/// incremental deltas and the final structured response.
sealed class SyniChatEvent {
  const SyniChatEvent();
}

/// An incremental token chunk emitted during generation.
///
/// For structured (coach / chat) schemas these are raw JSON tokens — not
/// directly user-presentable. UI typically shows a "thinking" state until
/// [SyniChatFinal] arrives.
class SyniChatDelta extends SyniChatEvent {
  const SyniChatDelta(this.text);
  final String text;

  @override
  String toString() => 'SyniChatDelta(${text.length} chars)';
}

/// The final parsed response. Always emitted exactly once at the end of a
/// successful stream.
class SyniChatFinal extends SyniChatEvent {
  const SyniChatFinal(this.response);
  final SyniChatResponse response;

  @override
  String toString() => 'SyniChatFinal(persona: ${response.personaId})';
}
