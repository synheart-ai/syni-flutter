import '../response.dart';

/// The type of insight card.
///
/// Used with persona: life.insights.v1
enum InsightCardType {
  /// A reflective insight prompting self-examination.
  reflection,

  /// An actionable insight with specific recommendations.
  actionable,

  /// An informational insight providing context or knowledge.
  informational,

  /// A motivational insight for encouragement.
  motivational,

  /// A warning or caution insight.
  caution,

  /// Unknown or custom type.
  other,
}

/// A single insight card.
class InsightCard {
  /// Unique identifier for this card.
  final String? id;

  /// The type of insight.
  final InsightCardType type;

  /// The main headline or title.
  final String title;

  /// The body content of the insight.
  final String body;

  /// Optional icon or emoji identifier.
  final String? icon;

  /// Optional priority or importance level (1-5, higher is more important).
  final int? priority;

  /// Optional tags or categories.
  final List<String>? tags;

  /// Optional call-to-action text.
  final String? actionText;

  /// Optional deep link or action identifier.
  final String? actionId;

  const InsightCard({
    this.id,
    required this.type,
    required this.title,
    required this.body,
    this.icon,
    this.priority,
    this.tags,
    this.actionText,
    this.actionId,
  });

  factory InsightCard.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] as String? ?? 'other';
    final type = InsightCardType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => InsightCardType.other,
    );

    return InsightCard(
      id: map['id'] as String?,
      type: type,
      title: map['title'] as String,
      body: map['body'] as String,
      icon: map['icon'] as String?,
      priority: map['priority'] as int?,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>(),
      actionText: map['actionText'] as String?,
      actionId: map['actionId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      if (icon != null) 'icon': icon,
      if (priority != null) 'priority': priority,
      if (tags != null) 'tags': tags,
      if (actionText != null) 'actionText': actionText,
      if (actionId != null) 'actionId': actionId,
    };
  }

  /// Whether this card has an associated action.
  bool get hasAction => actionText != null || actionId != null;
}

/// A typed response for life insights cards.
///
/// Example usage:
/// ```dart
/// final response = await Syni.generate(SyniRequest(
///   personaId: 'life.insights.v1',
///   input: 'What should I focus on today?',
/// ));
/// final insights = InsightsCardResponse.fromSyniResponse(response);
/// for (final card in insights.cards) {
///   print('${card.title}: ${card.body}');
/// }
/// ```
class InsightsCardResponse {
  /// The list of insight cards.
  final List<InsightCard> cards;

  /// Optional summary or overview message.
  final String? summary;

  /// Response metadata from Syni.
  final SyniResponseMeta meta;

  const InsightsCardResponse({
    required this.cards,
    this.summary,
    required this.meta,
  });

  /// Creates an [InsightsCardResponse] from a raw [SyniResponse].
  factory InsightsCardResponse.fromSyniResponse(SyniResponse response) {
    final outputJson = response.outputJson;
    final cardsJson = outputJson['cards'] as List<dynamic>? ?? [];

    return InsightsCardResponse(
      cards: cardsJson
          .map((c) => InsightCard.fromMap(c as Map<String, dynamic>))
          .toList(),
      summary: outputJson['summary'] as String?,
      meta: response.meta,
    );
  }

  /// Whether there are any cards available.
  bool get hasCards => cards.isNotEmpty;

  /// Gets the primary/first card, if available.
  InsightCard? get primaryCard => cards.isNotEmpty ? cards.first : null;

  /// Gets cards filtered by type.
  List<InsightCard> cardsByType(InsightCardType type) =>
      cards.where((c) => c.type == type).toList();

  /// Gets cards sorted by priority (highest first).
  List<InsightCard> get cardsByPriority {
    final sorted = List<InsightCard>.from(cards);
    sorted.sort((a, b) => (b.priority ?? 0).compareTo(a.priority ?? 0));
    return sorted;
  }
}
