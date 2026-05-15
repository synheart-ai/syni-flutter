/// A declarative Syni persona — voice, goals, boundaries, output schema.
///
/// This is the generic *type* only. `syni-flutter` defines no concrete
/// personas — that is a product / spec concern. Personas are either:
/// - supplied by the host app and passed to `SyniAgent.install()`, or
/// - (future) loaded from `syni-core-spec` bundled assets.
///
/// Syni privileges no domain (focus, recovery, stress, …); the persona's
/// [systemPrompt] decides what the agent attends to.
library;

class SyniPersona {
  const SyniPersona({
    required this.id,
    required this.displayName,
    required this.systemPrompt,
    required this.responseSchemaId,
    this.tone = 'calm',
  });

  /// Stable identifier, e.g. `<persona-name>.v1`. Used for logging /
  /// telemetry and (future) resolution against `syni-core-spec`.
  final String id;

  /// Human-readable name surfaced in host-app UI.
  final String displayName;

  /// One- or two-sentence tone descriptor.
  final String tone;

  /// System prompt prepended to the HSI-conditioned prompt by the runtime's
  /// `PromptBuilder`.
  final String systemPrompt;

  /// Output schema selector — must be one of the runtime's `OutputSchema`
  /// enum values: `suggestions`, `coach`, or `chat`.
  final String responseSchemaId;
}
