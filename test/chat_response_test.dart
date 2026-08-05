import 'package:flutter_test/flutter_test.dart';
import 'package:syni/agent.dart';

void main() {
  const persona = 'life.companion.v1';
  const version = '0.4.0';

  SyniChatResponse fromRuntime(String json) =>
      SyniChatResponse.fromRuntimeJson(json, personaId: persona, runtimeVersion: version);
  SyniChatResponse fromCloud(String reply) =>
      SyniChatResponse.fromCloudReply(reply, personaId: persona, runtimeVersion: version);

  group('fromRuntimeJson fallback metadata', () {
    test('genuine answer → not a fallback', () {
      final r = fromRuntime('{"type":"chat","data":{"message":"hello"}}');
      expect(r.message, 'hello');
      expect(r.isFallback, isFalse);
      expect(r.underlyingErrorCode, isNull);
    });

    test('fallback response carries code + reason + retryable', () {
      final r = fromRuntime(
        '{"type":"coach","data":{"message":"reset","suggestions":[]},'
        '"meta":{"fallback_used":true,"fallback_reason":"local_generation_failed",'
        '"error_code":"INVALID_JSON","retryable":true}}',
      );
      expect(r.isFallback, isTrue);
      expect(r.underlyingErrorCode, 'INVALID_JSON');
      expect(r.fallbackReason, 'local_generation_failed');
      expect(r.retryable, isTrue);
    });
  });

  group('fromCloudReply — never leaks raw JSON', () {
    test('plain text reply is used verbatim', () {
      final r = fromCloud('Here is a gentle reflection.');
      expect(r.message, 'Here is a gentle reflection.');
      expect(r.kind, SyniResponseKind.chat);
    });

    test('coach JSON extracts response + suggested_action', () {
      final r = fromCloud('{"response":"You paced yourself well.","suggested_action":"Note it."}');
      expect(r.kind, SyniResponseKind.coach);
      expect(r.message, 'You paced yourself well.');
      expect(r.suggestions, ['Note it.']);
    });

    test('fenced coach JSON is unwrapped', () {
      final r = fromCloud('```json\n{"response":"Nice work."}\n```');
      expect(r.message, 'Nice work.');
    });

    test('message schema supports object-shaped suggestions', () {
      final r = fromCloud(
        '{"message":"ok","suggestions":[{"text":"a"},"b",{"nope":1}]}',
      );
      expect(r.message, 'ok');
      expect(r.suggestions, ['a', 'b']);
    });

    test('unknown JSON object is NOT dumped as display text', () {
      final r = fromCloud('{"totally":"unknown","shape":42}');
      expect(r.message, isNull);
      // displayText degrades to the neutral placeholder, never the raw JSON.
      expect(r.displayText, isNot(contains('totally')));
    });

    test('malformed JSON-ish reply is not echoed raw', () {
      final r = fromCloud('{ this is broken json');
      expect(r.message, isNull);
      expect(r.displayText, isNot(contains('broken json')));
    });
  });
}
