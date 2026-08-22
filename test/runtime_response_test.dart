import 'package:flutter_test/flutter_test.dart';
import 'package:syni/runtime.dart';

void main() {
  group('Runtime API 2.0 contract metadata', () {
    test('capabilities are parsed into typed feature flags', () {
      final capabilities = SyniRuntimeCapabilities.fromJson(
        '{"api_versions":["1.0","2.0"],"backend":"llama.cpp",'
        '"accelerator":"metal","roles":{"system":true},'
        '"generation":{"max_tokens":true,"temperature":true},'
        '"structured_decoding":true,'
        '"streaming":{"supported":true,"display_text_deltas":false},'
        '"provenance":true}',
      );

      expect(capabilities.apiVersions, ['1.0', '2.0']);
      expect(capabilities.backend, 'llama.cpp');
      expect(capabilities.accelerator, 'metal');
      expect(capabilities.supportsSystemRole, isTrue);
      expect(capabilities.generationControls, {'max_tokens', 'temperature'});
      expect(capabilities.supportsStructuredDecoding, isTrue);
      expect(capabilities.supportsStreaming, isTrue);
      expect(capabilities.streamsDisplayText, isFalse);
      expect(capabilities.supportsProvenance, isTrue);
      expect(capabilities.isLegacy, isFalse);
    });

    test('response identity and provenance are surfaced', () {
      final response = SyniRuntimeResponse.fromJson(
        '{"type":"chat","data":{"message":"hello"},'
        '"api_version":"2.0","request_id":"turn-123",'
        '"finish_reason":"stop","provenance":{"backend":"llama.cpp",'
        '"accelerator":"metal","runtime_version":"0.4.4",'
        '"model_id":"qwen.gguf"}}',
      );

      expect(response.apiVersion, '2.0');
      expect(response.requestId, 'turn-123');
      expect(response.finishReason, 'stop');
      expect(response.provenance?.backend, 'llama.cpp');
      expect(response.provenance?.accelerator, 'metal');
      expect(response.provenance?.runtimeVersion, '0.4.4');
      expect(response.provenance?.modelId, 'qwen.gguf');
    });
  });

  group('SyniRuntimeResponse.fromJson — success + fallback meta', () {
    test('genuine answer has no meta → isFallback false', () {
      final r = SyniRuntimeResponse.fromJson(
        '{"type":"chat","data":{"message":"hi"}}',
      );
      expect(r.isFallback, isFalse);
      expect(r.underlyingErrorCode, isNull);
      expect(r.fallbackReason, isNull);
      expect(r.retryable, isFalse);
    });

    test('fallback meta is surfaced with code + retryable', () {
      final r = SyniRuntimeResponse.fromJson(
        '{"type":"coach","data":{"message":"…","suggestions":[]},'
        '"meta":{"fallback_used":true,"fallback_reason":"timeout",'
        '"error_code":"TIMEOUT","retryable":true}}',
      );
      expect(r.isFallback, isTrue);
      expect(r.underlyingErrorCode, 'TIMEOUT');
      expect(r.fallbackReason, 'timeout');
      expect(r.retryable, isTrue);
    });

    test('meta present but fallback_used false is treated as genuine', () {
      final r = SyniRuntimeResponse.fromJson(
        '{"type":"chat","data":{"message":"hi"},"meta":{"fallback_used":false}}',
      );
      expect(r.isFallback, isFalse);
    });
  });

  group('SyniRuntimeResponse.fromJson — failure envelope', () {
    test('ok:false throws typed error with code + retryable', () {
      expect(
        () => SyniRuntimeResponse.fromJson(
          '{"ok":false,"error":{"code":"MODEL_UNAVAILABLE",'
          '"message":"no model","retryable":false}}',
        ),
        throwsA(
          isA<SyniRuntimeError>()
              .having((e) => e.code, 'code', 'MODEL_UNAVAILABLE')
              .having((e) => e.retryable, 'retryable', isFalse)
              .having((e) => e.message, 'message', 'no model'),
        ),
      );
    });

    test('missing error object → UNKNOWN, still typed', () {
      expect(
        () => SyniRuntimeResponse.fromJson('{"ok":false}'),
        throwsA(
            isA<SyniRuntimeError>().having((e) => e.code, 'code', 'UNKNOWN')),
      );
    });

    test('non-boolean retryable is treated as false', () {
      expect(
        () => SyniRuntimeResponse.fromJson(
          '{"ok":false,"error":{"code":"BACKEND","message":"x","retryable":"yes"}}',
        ),
        throwsA(
          isA<SyniRuntimeError>()
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('non-string code/message do not crash parsing', () {
      expect(
        () => SyniRuntimeResponse.fromJson(
          '{"ok":false,"error":{"code":123,"message":{"x":1},"retryable":true}}',
        ),
        throwsA(
          isA<SyniRuntimeError>()
              .having((e) => e.code, 'code', 'UNKNOWN')
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });
  });

  group('SyniRuntimeResponse.fromJson — malformed native output', () {
    test('malformed JSON becomes a protocol error, not a FormatException', () {
      expect(
        () => SyniRuntimeResponse.fromJson('this is not json'),
        throwsA(
          isA<SyniRuntimeError>()
              .having((e) => e.code, 'code', 'MALFORMED_RESPONSE'),
        ),
      );
    });

    test('non-object JSON (array) becomes a protocol error', () {
      expect(
        () => SyniRuntimeResponse.fromJson('[1,2,3]'),
        throwsA(
          isA<SyniRuntimeError>()
              .having((e) => e.code, 'code', 'MALFORMED_RESPONSE'),
        ),
      );
    });
  });
}
