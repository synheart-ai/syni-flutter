import 'package:flutter_test/flutter_test.dart';
import 'package:syni/runtime.dart';

void main() {
  group('parseTelemetry', () {
    test('null / empty / non-array → empty list', () {
      expect(parseTelemetry(null), isEmpty);
      expect(parseTelemetry(''), isEmpty);
      expect(parseTelemetry('not json'), isEmpty);
      expect(parseTelemetry('{"not":"an array"}'), isEmpty);
    });

    test('genuine success metric has no diagnostics', () {
      final m = parseTelemetry(
        '[{"started_at_unix_ms":1,"duration_ms":12,"preset":"chat",'
        '"success":true,"schema_valid":true,"retries":0,"fallback_used":false}]',
      );
      expect(m, hasLength(1));
      expect(m.first.fallbackUsed, isFalse);
      expect(m.first.preset, 'chat');
      expect(m.first.diagnostics, isNull);
    });

    test('fallback metric parses per-attempt diagnostics', () {
      final m = parseTelemetry(
        '[{"started_at_unix_ms":1,"duration_ms":30,"preset":"coach",'
        '"success":true,"schema_valid":true,"retries":1,"fallback_used":true,'
        '"error_code":"INVALID_JSON","fallback_reason":"invalid json: x",'
        '"diagnostics":{"seed":0,"schema":"coach","max_tokens":256,'
        '"likely_truncated":true,"attempts":['
        '{"attempt":0,"error_code":"INVALID_JSON","error_message":"invalid json: x",'
        '"output_len":16,"repair_attempted":true}]}}]',
      );
      expect(m, hasLength(1));
      final metric = m.first;
      expect(metric.fallbackUsed, isTrue);
      expect(metric.errorCode, 'INVALID_JSON');
      final d = metric.diagnostics!;
      expect(d.schema, 'coach');
      expect(d.likelyTruncated, isTrue);
      expect(d.attempts, hasLength(1));
      expect(d.attempts.first.errorCode, 'INVALID_JSON');
      expect(d.attempts.first.outputLen, 16);
      // Sensitive fields absent when capture_diagnostics was off.
      expect(d.prompt, isNull);
      expect(d.rawOutput, isNull);
    });

    test('sensitive fields surface when captured', () {
      final m = parseTelemetry(
        '[{"started_at_unix_ms":1,"duration_ms":30,"preset":"coach",'
        '"success":true,"schema_valid":true,"retries":0,"fallback_used":true,'
        '"diagnostics":{"seed":7,"schema":"coach","max_tokens":256,'
        '"likely_truncated":false,"attempts":[],'
        '"prompt":"<hsi prompt>","raw_output":"not json"}}]',
      );
      final d = m.first.diagnostics!;
      expect(d.seed, 7);
      expect(d.prompt, '<hsi prompt>');
      expect(d.rawOutput, 'not json');
    });

    test('malformed metric entries are skipped, valid ones kept', () {
      final m = parseTelemetry(
        '[42,"nope",{"preset":"chat","success":true,"schema_valid":true,'
        '"retries":0,"fallback_used":false,"started_at_unix_ms":1,"duration_ms":1}]',
      );
      expect(m, hasLength(1));
      expect(m.first.preset, 'chat');
    });
  });
}
