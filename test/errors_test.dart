import 'package:flutter_test/flutter_test.dart';
import 'package:syni/syni.dart';

void main() {
  group('SyniError', () {
    test('toString surfaces type + message', () {
      const e = SyniError(
        type: SyniErrorType.invalidRequest,
        message: 'persona id is empty',
      );
      final s = e.toString();
      expect(s, contains('invalidRequest'));
      expect(s, contains('persona id is empty'));
    });

    test('fromMap recognizes known type strings', () {
      final e = SyniError.fromMap({
        'type': 'timeout',
        'message': 'engine timed out after 30s',
        'code': 'ENGINE_TIMEOUT',
      });
      expect(e.type, SyniErrorType.timeout);
      expect(e.message, 'engine timed out after 30s');
      expect(e.code, 'ENGINE_TIMEOUT');
    });

    test('fromMap falls back to platformError on unknown type', () {
      final e = SyniError.fromMap({
        'type': 'something_native_invented',
        'message': 'native side surprised us',
      });
      expect(e.type, SyniErrorType.platformError);
      expect(e.message, 'native side surprised us');
    });
  });
}
