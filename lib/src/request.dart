/// Constraints for how a request should be processed.
class SyniRequestConstraints {
  /// If true, only use offline/local engines. Never use cloud.
  final bool offlineOnly;

  /// If true, allow cloud engines when local is unavailable or unsuitable.
  final bool allowCloud;

  const SyniRequestConstraints({
    this.offlineOnly = false,
    this.allowCloud = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'offlineOnly': offlineOnly,
      'allowCloud': allowCloud,
    };
  }

  factory SyniRequestConstraints.fromMap(Map<String, dynamic> map) {
    return SyniRequestConstraints(
      offlineOnly: map['offlineOnly'] as bool? ?? false,
      allowCloud: map['allowCloud'] as bool? ?? true,
    );
  }
}

/// A request to the Syni SDK.
class SyniRequest {
  /// The persona ID to use for this request (e.g., "keyboard.v1", "life.coach.v1").
  final String personaId;

  /// The user input text to process.
  final String input;

  /// Optional conversation context for multi-turn interactions.
  final List<SyniMessage>? context;

  /// Optional constraints for how the request should be processed.
  final SyniRequestConstraints? constraints;

  /// Optional client event ID for telemetry correlation.
  final String? clientEventId;

  /// Optional additional parameters for the request.
  final Map<String, dynamic>? parameters;

  const SyniRequest({
    required this.personaId,
    required this.input,
    this.context,
    this.constraints,
    this.clientEventId,
    this.parameters,
  });

  /// Converts this request to a JSON-serializable map.
  Map<String, dynamic> toMap() {
    return {
      'personaId': personaId,
      'input': input,
      if (context != null) 'context': context!.map((m) => m.toMap()).toList(),
      if (constraints != null) 'constraints': constraints!.toMap(),
      if (clientEventId != null) 'clientEventId': clientEventId,
      if (parameters != null) 'parameters': parameters,
    };
  }

  /// Creates a [SyniRequest] from a map.
  factory SyniRequest.fromMap(Map<String, dynamic> map) {
    return SyniRequest(
      personaId: map['personaId'] as String,
      input: map['input'] as String,
      context: (map['context'] as List<dynamic>?)
          ?.map((m) => SyniMessage.fromMap(m as Map<String, dynamic>))
          .toList(),
      constraints: map['constraints'] != null
          ? SyniRequestConstraints.fromMap(
              map['constraints'] as Map<String, dynamic>)
          : null,
      clientEventId: map['clientEventId'] as String?,
      parameters: map['parameters'] as Map<String, dynamic>?,
    );
  }
}

/// The role of a message in a conversation.
enum SyniMessageRole {
  user,
  assistant,
  system,
}

/// A message in a conversation context.
class SyniMessage {
  /// The role of the message sender.
  final SyniMessageRole role;

  /// The content of the message.
  final String content;

  const SyniMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  factory SyniMessage.fromMap(Map<String, dynamic> map) {
    return SyniMessage(
      role: SyniMessageRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => SyniMessageRole.user,
      ),
      content: map['content'] as String,
    );
  }
}
