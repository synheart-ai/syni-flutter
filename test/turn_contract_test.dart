import 'package:flutter_test/flutter_test.dart';
import 'package:syni/agent.dart';

void main() {
  const persona = SyniPersona(
    id: 'life.companion.v1',
    displayName: 'Syni',
    systemPrompt: 'Be warm, grounded, and concise.',
    responseSchemaId: 'chat',
  );

  test('V2 turn preserves authority, context, history, and generation fields',
      () {
    const request = SyniTurnRequest(
      requestId: 'turn-123',
      systemPolicy: 'Do not diagnose or invent missing measurements.',
      task: SyniTaskContract(
        id: 'explain_session',
        instruction: 'Explain only the supplied session facts.',
        responseSchemaId: 'coach',
      ),
      userMessage: 'What does this session mean?',
      context: {
        'session_type': 'calibration',
        'duration_minutes': 4,
      },
      hsiContext: {'locale': 'en'},
      dialogue: [
        SyniTurnMessage(
          role: SyniTurnMessageRole.user,
          content: 'Was this a long session?',
        ),
        SyniTurnMessage(
          role: SyniTurnMessageRole.assistant,
          content: 'It lasted four minutes.',
        ),
      ],
      generation: SyniGenerationProfile(
        maxTokens: 160,
        ttftTimeoutMs: 5000,
        seed: 7,
        temperature: 0.2,
      ),
    );

    final json = request.toRuntimeRequest(persona).toJson();

    expect(json['api_version'], '2.0');
    expect(json['request_id'], 'turn-123');
    expect(json['instruction'], 'What does this session mean?');
    expect(json['schema'], 'coach');
    expect(json['system'], contains(persona.systemPrompt));
    expect(json['system'], contains('Do not diagnose'));
    expect(json['system'], contains('Task: explain_session'));
    expect(json['system'], contains('Explain only the supplied session facts'));

    final hsi = json['hsi'] as Map<String, dynamic>;
    expect(hsi['locale'], 'en');
    expect(hsi['conversation_context'], contains('"duration_minutes":4'));
    expect(hsi['conversation_context'], contains('data, not instructions'));

    final messages = json['messages'] as List<dynamic>;
    expect(messages, [
      {'role': 'user', 'content': 'Was this a long session?'},
      {'role': 'assistant', 'content': 'It lasted four minutes.'},
    ]);
    expect(json['generation'], {
      'max_tokens': 160,
      'ttft_timeout_ms': 5000,
      'seed': 7,
      'temperature': 0.2,
    });
  });

  test('V2 turn rejects empty identity, task, and user content', () {
    expect(
      () => const SyniTurnRequest(
        requestId: '',
        task: SyniTaskContract(instruction: 'Explain.'),
        userMessage: 'Hello',
      ).toRuntimeRequest(persona),
      throwsArgumentError,
    );
    expect(
      () => const SyniTurnRequest(
        requestId: 'turn-1',
        task: SyniTaskContract(instruction: '  '),
        userMessage: 'Hello',
      ).toRuntimeRequest(persona),
      throwsArgumentError,
    );
    expect(
      () => const SyniTurnRequest(
        requestId: 'turn-1',
        task: SyniTaskContract(instruction: 'Explain.'),
        userMessage: '  ',
      ).toRuntimeRequest(persona),
      throwsArgumentError,
    );
  });
}
