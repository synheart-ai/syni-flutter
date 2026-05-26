import 'package:flutter_test/flutter_test.dart';
import 'package:syni/syni.dart';

void main() {
  test('SyniRequest round-trips via toMap/fromMap', () {
    const request = SyniRequest(
      personaId: 'keyboard.v1',
      input: 'Hello',
      constraints: SyniRequestConstraints(
        offlineOnly: true,
        allowCloud: false,
      ),
      clientEventId: 'evt_123',
      parameters: {'foo': 'bar'},
      context: [
        SyniMessage(role: SyniMessageRole.user, content: 'Hi'),
        SyniMessage(role: SyniMessageRole.assistant, content: 'Hello!'),
      ],
    );

    final map = request.toMap();
    final reparsed = SyniRequest.fromMap(map);

    expect(reparsed.personaId, request.personaId);
    expect(reparsed.input, request.input);
    expect(reparsed.clientEventId, request.clientEventId);
    expect(reparsed.parameters, request.parameters);
    expect(reparsed.constraints?.offlineOnly, isTrue);
    expect(reparsed.constraints?.allowCloud, isFalse);
    expect(reparsed.context?.length, 2);
    expect(reparsed.context?.first.role, SyniMessageRole.user);
  });

  test('SyniResponse parses and typed KeyboardSuggestionResponse works', () {
    final response = SyniResponse.fromMap({
      'outputJson': {
        'suggestions': [
          {'text': 'Hello!', 'confidence': 0.95},
          {'text': 'Hi there!', 'confidence': 0.85},
        ],
      },
      'meta': {
        'schemaId': 'keyboard.suggestions.v1',
        'personaId': 'keyboard.v1',
        'engine': 'local',
        'durationMs': 50,
        'isFallback': false,
      },
    });

    expect(response.outputJson['suggestions'], isA<List<dynamic>>());
    expect(response.meta.schemaId, 'keyboard.suggestions.v1');
    expect(response.meta.isFallback, isFalse);

    final typed = KeyboardSuggestionResponse.fromSyniResponse(response);
    expect(typed.hasSuggestions, isTrue);
    expect(typed.topSuggestion?.text, 'Hello!');
    expect(typed.suggestions.length, 2);
  });
}
