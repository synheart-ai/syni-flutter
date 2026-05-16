import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'syni_chat.dart';
import 'syni_cloud_config.dart';
import 'syni_persona.dart';

/// HTTP + SSE client for `syni-service` `/v1/chat[/stream]`.
///
/// Owns a sticky `session_id` for the agent's lifetime so the server can
/// thread multi-turn context. HSI is pulled server-side via
/// `include_state: true`; the locally-built `hsiContext` is forwarded as
/// the optional `context` map for richer conditioning.
///
/// Persona: sends [SyniPersona.id] as the request's `persona_id`. The
/// server resolves it against its embedded `syni-spec` registry —
/// the authoritative source for system prompt, rules, budget, and privacy.
class SyniCloudClient {
  SyniCloudClient(this._config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final SyniCloudConfig _config;
  final http.Client _http;

  /// Server-assigned session id, sticky across calls.
  String? _sessionId;

  String? get sessionId => _sessionId;

  // ---------------------------------------------------------------------------
  // Non-streaming chat
  // ---------------------------------------------------------------------------

  Future<SyniChatResponse> chat({
    required String message,
    required SyniPersona persona,
    Map<String, dynamic>? hsiContext,
  }) async {
    final resp = await _http.post(
      Uri.parse('${_config.baseUrl}/v1/chat'),
      headers: await _headers(),
      body: jsonEncode(_buildRequest(
        message: message,
        persona: persona,
        hsiContext: hsiContext,
        stream: false,
      )),
    );
    if (resp.statusCode != 200) {
      throw SyniCloudException(
        'POST /v1/chat HTTP ${resp.statusCode}: ${resp.body}',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    _sessionId = (body['session_id'] as String?) ?? _sessionId;
    return SyniChatResponse.fromCloudReply(
      (body['reply'] as String?) ?? '',
      personaId: persona.id,
      runtimeVersion: 'cloud',
    );
  }

  // ---------------------------------------------------------------------------
  // Streaming chat (SSE)
  // ---------------------------------------------------------------------------

  /// Streams content chunks as [SyniChatDelta] events, then exactly one
  /// [SyniChatFinal] when the server emits `{type: "done"}`. Server errors
  /// surface as a thrown [SyniCloudException].
  ///
  /// SSE wire format (per `syni-service`):
  /// ```
  /// data: {"type":"content","content":"<chunk>"}
  /// data: {"type":"done","session_id":"<id>"}
  /// data: {"type":"error","error":"<msg>"}
  /// ```
  Stream<SyniChatEvent> chatStream({
    required String message,
    required SyniPersona persona,
    Map<String, dynamic>? hsiContext,
  }) async* {
    final req = http.Request(
      'POST',
      Uri.parse('${_config.baseUrl}/v1/chat/stream'),
    );
    req.headers.addAll(await _headers());
    req.headers['Accept'] = 'text/event-stream';
    req.body = jsonEncode(_buildRequest(
      message: message,
      persona: persona,
      hsiContext: hsiContext,
      stream: true,
    ));

    final streamed = await _http.send(req);
    if (streamed.statusCode != 200) {
      throw SyniCloudException(
        'POST /v1/chat/stream HTTP ${streamed.statusCode}',
      );
    }

    final messageBuf = StringBuffer();
    final lineBuf = StringBuffer();

    await for (final bytes in streamed.stream) {
      lineBuf.write(utf8.decode(bytes, allowMalformed: true));
      // SSE frames end with a blank line (\n\n).
      while (true) {
        final s = lineBuf.toString();
        final boundary = s.indexOf('\n\n');
        if (boundary < 0) break;
        final frame = s.substring(0, boundary);
        lineBuf
          ..clear()
          ..write(s.substring(boundary + 2));

        // Parse the `data:` line(s) of the frame. We only emit the JSON
        // payload; other SSE fields (event:, id:, retry:) are ignored.
        for (final line in frame.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;

          final Map<String, dynamic> evt;
          try {
            evt = jsonDecode(payload) as Map<String, dynamic>;
          } catch (_) {
            continue; // Malformed frame — skip.
          }

          switch (evt['type']) {
            case 'content':
              final content = (evt['content'] as String?) ?? '';
              messageBuf.write(content);
              yield SyniChatDelta(content);
            case 'done':
              _sessionId = (evt['session_id'] as String?) ?? _sessionId;
              yield SyniChatFinal(SyniChatResponse.fromCloudReply(
                messageBuf.toString(),
                personaId: persona.id,
                runtimeVersion: 'cloud',
              ));
              return;
            case 'error':
              throw SyniCloudException(
                (evt['error'] as String?) ?? 'unknown server error',
              );
          }
        }
      }
    }
    // Stream ended without an explicit `done`/`error` — synthesize a final.
    if (messageBuf.isNotEmpty) {
      yield SyniChatFinal(SyniChatResponse.fromCloudReply(
        messageBuf.toString(),
        personaId: persona.id,
        runtimeVersion: 'cloud',
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _headers() async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await _config.authToken();
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Map<String, dynamic> _buildRequest({
    required String message,
    required SyniPersona persona,
    required Map<String, dynamic>? hsiContext,
    required bool stream,
  }) {
    return {
      'message': message,
      // Canonical spec persona id (e.g. `focus.coach.v1`). The server
      // resolves it against the embedded syni-spec registry.
      'persona_id': persona.id,
      'tenant_id': _config.tenantId,
      'user_id': _config.userId,
      if (_config.projectId.isNotEmpty) 'project_id': _config.projectId,
      if (_config.orgId.isNotEmpty) 'org_id': _config.orgId,
      if (_config.appId.isNotEmpty) 'app_id': _config.appId,
      if (_config.deviceId.isNotEmpty) 'device_id': _config.deviceId,
      if (_sessionId != null) 'session_id': _sessionId,
      'execution_mode': 'cloud_only',
      'include_state': true,
      'stream': stream,
      if (hsiContext != null) 'context': hsiContext,
    };
  }
}

class SyniCloudException implements Exception {
  SyniCloudException(this.message);
  final String message;

  @override
  String toString() => 'SyniCloudException: $message';
}
