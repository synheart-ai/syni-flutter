import '../response.dart';

/// A single coaching step or action item.
///
/// Used with persona: life.coach.v1
class CoachStep {
  /// The step number or order.
  final int order;

  /// The title or summary of this step.
  final String title;

  /// Detailed description or instructions for this step.
  final String description;

  /// Optional duration estimate (e.g., "5 minutes", "1 day").
  final String? duration;

  /// Optional category (e.g., "reflection", "action", "mindfulness").
  final String? category;

  /// Whether this step is optional.
  final bool isOptional;

  const CoachStep({
    required this.order,
    required this.title,
    required this.description,
    this.duration,
    this.category,
    this.isOptional = false,
  });

  factory CoachStep.fromMap(Map<String, dynamic> map) {
    return CoachStep(
      order: map['order'] as int? ?? 0,
      title: map['title'] as String,
      description: map['description'] as String,
      duration: map['duration'] as String?,
      category: map['category'] as String?,
      isOptional: map['isOptional'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'title': title,
      'description': description,
      if (duration != null) 'duration': duration,
      if (category != null) 'category': category,
      'isOptional': isOptional,
    };
  }
}

/// A typed response for life coach steps.
///
/// Example usage:
/// ```dart
/// final response = await Syni.generate(SyniRequest(
///   personaId: 'life.coach.v1',
///   input: 'I want to be more productive',
/// ));
/// final coachResponse = CoachStepsResponse.fromSyniResponse(response);
/// for (final step in coachResponse.steps) {
///   print('${step.order}. ${step.title}');
/// }
/// ```
class CoachStepsResponse {
  /// The overall theme or goal being addressed.
  final String? theme;

  /// An introductory message from the coach.
  final String? introduction;

  /// The list of coaching steps.
  final List<CoachStep> steps;

  /// A closing or motivational message.
  final String? closing;

  /// Response metadata from Syni.
  final SyniResponseMeta meta;

  const CoachStepsResponse({
    this.theme,
    this.introduction,
    required this.steps,
    this.closing,
    required this.meta,
  });

  /// Creates a [CoachStepsResponse] from a raw [SyniResponse].
  factory CoachStepsResponse.fromSyniResponse(SyniResponse response) {
    final outputJson = response.outputJson;
    final stepsJson = outputJson['steps'] as List<dynamic>? ?? [];

    return CoachStepsResponse(
      theme: outputJson['theme'] as String?,
      introduction: outputJson['introduction'] as String?,
      steps: stepsJson
          .map((s) => CoachStep.fromMap(s as Map<String, dynamic>))
          .toList(),
      closing: outputJson['closing'] as String?,
      meta: response.meta,
    );
  }

  /// Whether there are any steps available.
  bool get hasSteps => steps.isNotEmpty;

  /// Gets the total number of steps.
  int get stepCount => steps.length;

  /// Gets only the required (non-optional) steps.
  List<CoachStep> get requiredSteps =>
      steps.where((s) => !s.isOptional).toList();
}
