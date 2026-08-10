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
    this.isFallback = false,
    this.fallbackReason,
    this.underlyingErrorCode,
    this.retryable = false,
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

  /// True when the runtime returned a deterministic fallback rather than model
  /// output. Defaults to false (a genuine answer, or a cloud reply, or an older
  /// runtime that emits no `meta`). Clients must branch on this rather than
  /// matching the fallback's text.
  final bool isFallback;

  /// Raw reason behind a fallback (e.g. `timeout`), else null.
  final String? fallbackReason;

  /// Stable code classifying the failure behind a fallback (`INVALID_JSON`,
  /// `SCHEMA`, `TIMEOUT`, …), else null.
  final String? underlyingErrorCode;

  /// Whether the failure behind a fallback was transient. False unless
  /// [isFallback].
  final bool retryable;

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
    var isFallback = false;
    String? fallbackReason;
    String? underlyingErrorCode;
    var retryable = false;

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map) {
          switch (decoded['type']) {
            case 'coach':
              kind = SyniResponseKind.coach;
              message = _normalizeDisplayMessage(_str(data['message']));
              suggestions.addAll(_suggestionTexts(data['suggestions']));
            case 'chat':
              kind = SyniResponseKind.chat;
              message = _normalizeDisplayMessage(_str(data['message']));
            case 'suggestions':
              kind = SyniResponseKind.suggestions;
              suggestions.addAll(_suggestionTexts(data['suggestions']));
          }
        }
        // Sibling `meta` present only when a fallback was substituted (see the
        // runtime's success envelope). Absence ⇒ genuine answer.
        final meta = decoded['meta'];
        if (meta is Map && meta['fallback_used'] == true) {
          isFallback = true;
          fallbackReason = _str(meta['fallback_reason']);
          underlyingErrorCode = _str(meta['error_code']);
          retryable = meta['retryable'] == true;
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
      isFallback: isFallback,
      fallbackReason: fallbackReason,
      underlyingErrorCode: underlyingErrorCode,
      retryable: retryable,
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

  /// Best-effort `String` extraction — null for a non-string value.
  static String? _str(dynamic v) => v is String ? v : null;

  /// Documented cloud suggestion list: either bare strings or `{ "text": … }`
  /// objects. Anything else is dropped (never rendered raw).
  static List<String> _cloudSuggestions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is String ? e : (e is Map ? _str(e['text']) : null))
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  /// If the whole reply is wrapped in a single ```` ``` ```` code fence
  /// (optionally with a language tag), return the inner content; else the
  /// input unchanged.
  static String _stripCodeFence(String s) {
    if (!s.startsWith('```')) return s;
    var t = s.substring(3);
    final nl = t.indexOf('\n');
    if (nl >= 0) t = t.substring(nl + 1); // drop the ```json language line
    if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    return t.trim();
  }

  /// Return the contents of one complete outer code fence, or null when the
  /// reply contains a partial fence or surrounding text.
  static String? _wholeCodeFenceContent(String reply) {
    final trimmed = reply.trim();
    if (!trimmed.startsWith('```') || !trimmed.endsWith('```')) return null;
    final openingLineEnd = trimmed.indexOf('\n');
    if (openingLineEnd < 0 || openingLineEnd >= trimmed.length - 3) return null;
    return trimmed.substring(openingLineEnd + 1, trimmed.length - 3).trim();
  }

  /// Decode a JSON object from a whole structured reply, a fenced reply, or a
  /// short preamble followed by an object. Returns null when no valid object is
  /// present.
  static Map? _structuredReplyObject(String reply) {
    final trimmed = reply.trim();
    final unfenced = _stripCodeFence(trimmed);
    final firstBrace = unfenced.indexOf('{');
    final lastBrace = unfenced.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) return null;

    try {
      final decoded = jsonDecode(
        unfenced.substring(firstBrace, lastBrace + 1),
      );
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether [reply] looks like structured output that must never be rendered
  /// literally when parsing fails or its shape is unknown.
  static bool _looksStructuredReply(String reply) {
    final trimmed = reply.trim();
    final unfenced = _stripCodeFence(trimmed);
    final firstBrace = unfenced.indexOf('{');
    final lastBrace = unfenced.lastIndexOf('}');
    return unfenced.startsWith('{') ||
        unfenced.startsWith('[') ||
        trimmed.contains('```') ||
        (firstBrace >= 0 && lastBrace > firstBrace);
  }

  /// Extract the first documented human-readable field from a structured
  /// model reply. Containers may be nested because small local models
  /// sometimes emit `{ "response": { "details": "..." } }` even though the
  /// runtime's outer `data.message` field is already a string.
  static String? _structuredDisplayText(dynamic value, [int depth = 0]) {
    if (depth > 6) return null;
    if (value is String) return value.trim().isEmpty ? null : value;
    if (value is! Map) return null;

    const displayKeys = ['message', 'details', 'summary', 'answer', 'text'];
    for (final key in displayKeys) {
      final extracted = _structuredDisplayText(value[key], depth + 1);
      if (extracted != null) return extracted;
    }

    const containerKeys = ['response', 'data', 'result'];
    for (final key in containerKeys) {
      final extracted = _structuredDisplayText(value[key], depth + 1);
      if (extracted != null) return extracted;
    }

    return null;
  }

  /// Normalize a message that is supposed to be display text. Plain prose is
  /// preserved. Recognized JSON is reduced to its display field; malformed or
  /// unknown structured output becomes null instead of leaking into the UI.
  static String? _normalizeDisplayMessage(String? message) {
    if (message == null || message.trim().isEmpty) return null;
    final object = _structuredReplyObject(message);
    if (object != null) return _structuredDisplayText(object);

    final fenced = _wholeCodeFenceContent(message);
    if (fenced != null && !_looksStructuredReply(fenced)) {
      return fenced.isEmpty ? null : fenced;
    }

    return _looksStructuredReply(message) ? null : message;
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

    // Cloud and runtime messages share the same structured-output detection so
    // neither route can accidentally expose JSON-shaped model output.
    final obj = _structuredReplyObject(reply);

    if (obj != null) {
      // Extract ONLY documented display fields. An unknown structured shape
      // yields an empty message — never the raw JSON object as display text.
      final response = _str(obj['response']);
      if (response != null && response.isNotEmpty) {
        // Coach schema (cloud): {response, suggested_action}.
        kind = SyniResponseKind.coach;
        message = response;
        final action = _str(obj['suggested_action']);
        if (action != null && action.isNotEmpty) suggestions.add(action);
      } else {
        // Richer schema: {message, suggestions}.
        final m = _str(obj['message']);
        if (m != null && m.isNotEmpty) {
          message = m;
          suggestions.addAll(_cloudSuggestions(obj['suggestions']));
        } else {
          // Tolerate nested display fields produced by smaller models while
          // still refusing arbitrary/unknown JSON objects.
          message = _structuredDisplayText(obj);
        }
      }
    } else {
      // No JSON object. If it merely *looked* structured (a leading `{` that
      // didn't parse), treat it as unknown output and leave the message empty
      // rather than echoing JSON-ish text. A complete fence containing only
      // prose is safe to unwrap; all other plain text is preserved verbatim.
      message = _normalizeDisplayMessage(reply);
    }

    return SyniChatResponse._(
      personaId: personaId,
      runtimeVersion: runtimeVersion,
      rawJson: reply,
      kind: kind,
      // Never fall back to the raw reply for structured/unknown output — a
      // null message surfaces via [displayText]'s neutral placeholder.
      message: message,
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
