import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syni/agent.dart';

void main() {
  const persona = 'life.companion.v1';
  const version = '0.4.0';

  SyniChatResponse fromRuntime(String json) =>
      SyniChatResponse.fromRuntimeJson(json,
          personaId: persona, runtimeVersion: version);
  SyniChatResponse fromCloud(String reply) =>
      SyniChatResponse.fromCloudReply(reply,
          personaId: persona, runtimeVersion: version);

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

  group('fromRuntimeJson — never leaks structured message text', () {
    test('fenced nested response details are unwrapped', () {
      final raw = jsonEncode({
        'type': 'chat',
        'data': {
          'message': '''```json
{"response":{"status":"calibration","details":"This was a short calibration session in Synheart Life."}}
```''',
        },
      });

      final r = fromRuntime(raw);
      expect(
          r.message, 'This was a short calibration session in Synheart Life.');
      expect(r.displayText, isNot(contains('```')));
      expect(r.displayText, isNot(contains('{"response"')));
      expect(r.rawJson, raw);
    });

    test('known nested display fields are extracted', () {
      final r = fromRuntime(jsonEncode({
        'type': 'chat',
        'data': {
          'message': '{"data":{"summary":"This session lasted five minutes."}}',
        },
      }));

      expect(r.message, 'This session lasted five minutes.');
    });

    test('plain prose inside a whole code fence is unwrapped', () {
      final r = fromRuntime(jsonEncode({
        'type': 'chat',
        'data': {
          'message': '''```
This calibration established a baseline for later readings.
```''',
        },
      }));

      expect(
        r.message,
        'This calibration established a baseline for later readings.',
      );
      expect(r.displayText, isNot(contains('```')));
    });

    test('malformed structured messages are not displayed', () {
      final r = fromRuntime(jsonEncode({
        'type': 'chat',
        'data': {
          'message': '```json\n{"response":{"details":"unfinished"}\n```',
        },
      }));

      expect(r.message, isNull);
      expect(r.displayText, isNot(contains('unfinished')));
    });

    test('unknown structured messages are not displayed', () {
      final r = fromRuntime(jsonEncode({
        'type': 'chat',
        'data': {
          'message': '{"response":{"status":"calibration"}}',
        },
      }));

      expect(r.message, isNull);
      expect(r.displayText, isNot(contains('calibration')));
    });
  });

  group('fromCloudReply — never leaks raw JSON', () {
    test('plain text reply is used verbatim', () {
      final r = fromCloud('Here is a gentle reflection.');
      expect(r.message, 'Here is a gentle reflection.');
      expect(r.kind, SyniResponseKind.chat);
    });

    test('coach JSON extracts response + suggested_action', () {
      final r = fromCloud(
          '{"response":"You paced yourself well.","suggested_action":"Note it."}');
      expect(r.kind, SyniResponseKind.coach);
      expect(r.message, 'You paced yourself well.');
      expect(r.suggestions, ['Note it.']);
    });

    test('fenced coach JSON is unwrapped', () {
      final r = fromCloud('```json\n{"response":"Nice work."}\n```');
      expect(r.message, 'Nice work.');
    });

    test('plain prose inside a whole code fence is unwrapped', () {
      final r = fromCloud('''```text
This calibration established a baseline for later readings.
```''');

      expect(
        r.message,
        'This calibration established a baseline for later readings.',
      );
      expect(r.displayText, isNot(contains('```')));
    });

    test('preamble before fenced coach JSON is not displayed', () {
      final r = fromCloud(
        'Here is the answer:\n'
        '```json\n'
        '{"response":"You seem more focused today."}\n'
        '```',
      );
      expect(r.message, 'You seem more focused today.');
      expect(r.displayText, isNot(contains('Here is the answer')));
      expect(r.displayText, isNot(contains('{"response"')));
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
