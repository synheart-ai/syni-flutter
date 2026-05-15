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

  /// Canonical spec persona id, e.g. `focus.coach.v1`. Matches the
  /// `id` field of the matching JSON file under
  /// `syni-core-spec/personas/{prod,research}/`. Sent to the cloud as
  /// `persona_id`; the server uses it to look up the authoritative
  /// system prompt, rules, budget, and privacy contract.
  ///
  /// Local-only consumers may still set this to any stable string,
  /// but matching the spec id keeps cloud + local behavior aligned.
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
