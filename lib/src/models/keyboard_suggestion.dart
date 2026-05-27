import '../response.dart';

/// A single keyboard suggestion.
///
/// Used with persona: keyboard.v1
class Suggestion {
  /// The suggested text to insert.
  final String text;

  /// Optional display label (if different from text).
  final String? label;

  /// Confidence score (0.0 to 1.0) if provided.
  final double? confidence;

  /// Optional category or type of suggestion.
  final String? category;

  const Suggestion({
    required this.text,
    this.label,
    this.confidence,
    this.category,
  });

  factory Suggestion.fromMap(Map<String, dynamic> map) {
    return Suggestion(
      text: map['text'] as String,
      label: map['label'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      category: map['category'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      if (label != null) 'label': label,
      if (confidence != null) 'confidence': confidence,
      if (category != null) 'category': category,
    };
  }
}

/// Metadata specific to keyboard suggestion responses.
class KeyboardSuggestionMeta {
  /// The input context that was analyzed.
  final String? inputContext;

  /// Language detected or used.
  final String? language;

  const KeyboardSuggestionMeta({
    this.inputContext,
    this.language,
  });

  factory KeyboardSuggestionMeta.fromMap(Map<String, dynamic> map) {
    return KeyboardSuggestionMeta(
      inputContext: map['inputContext'] as String?,
      language: map['language'] as String?,
    );
  }
}

/// A typed response for keyboard suggestions.
///
/// Example usage:
/// ```dart
/// final response = await Syni.generate(SyniRequest(
///   personaId: 'keyboard.v1',
///   input: 'Hello, how are',
/// ));
/// final suggestions = KeyboardSuggestionResponse.fromSyniResponse(response);
/// for (final suggestion in suggestions.suggestions) {
///   print(suggestion.text);
/// }
/// ```
class KeyboardSuggestionResponse {
  /// The list of suggestions.
  final List<Suggestion> suggestions;

  /// Response metadata from Syni.
  final SyniResponseMeta meta;

  /// Additional keyboard-specific metadata.
  final KeyboardSuggestionMeta? keyboardMeta;

  const KeyboardSuggestionResponse({
    required this.suggestions,
    required this.meta,
    this.keyboardMeta,
  });

  /// Creates a [KeyboardSuggestionResponse] from a raw [SyniResponse].
  factory KeyboardSuggestionResponse.fromSyniResponse(SyniResponse response) {
    final outputJson = response.outputJson;
    final suggestionsJson = outputJson['suggestions'] as List<dynamic>? ?? [];

    return KeyboardSuggestionResponse(
      suggestions: suggestionsJson
          .map((s) => Suggestion.fromMap(s as Map<String, dynamic>))
          .toList(),
      meta: response.meta,
      keyboardMeta: outputJson['keyboardMeta'] != null
          ? KeyboardSuggestionMeta.fromMap(
              outputJson['keyboardMeta'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Whether there are any suggestions available.
  bool get hasSuggestions => suggestions.isNotEmpty;

  /// Gets the top suggestion, if available.
  Suggestion? get topSuggestion =>
      suggestions.isNotEmpty ? suggestions.first : null;
}
