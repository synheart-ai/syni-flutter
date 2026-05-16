/// Installation lifecycle of the Syni agent.
///
/// `Activation` (one of the four authorities in the host SDK's feature model)
/// is gated on this reaching [SyniInstalled]. Until then, chat calls throw.
library;

sealed class SyniInstallState {
  const SyniInstallState();
}

/// No model downloaded, no persona bound. Default state.
class SyniNotInstalled extends SyniInstallState {
  const SyniNotInstalled();

  @override
  String toString() => 'SyniNotInstalled';
}

/// Install in progress. [progress] is in `[0.0, 1.0]`; [stage] explains which
/// sub-step is running.
class SyniInstalling extends SyniInstallState {
  const SyniInstalling({required this.stage, required this.progress});

  final SyniInstallStage stage;
  final double progress;

  @override
  String toString() =>
      'SyniInstalling(stage: $stage, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}

/// Successfully installed. The runtime engine has loaded the model and is
/// ready to receive chat calls.
class SyniInstalled extends SyniInstallState {
  const SyniInstalled({
    required this.personaId,
    required this.modelPath,
    required this.runtimeVersion,
  });

  final String personaId;
  final String modelPath;
  final String runtimeVersion;

  @override
  String toString() =>
      'SyniInstalled(personaId: $personaId, runtime: $runtimeVersion)';
}

/// Install failed. [reason] is human-readable; [cause] is the underlying
/// exception when available.
class SyniInstallFailed extends SyniInstallState {
  const SyniInstallFailed({required this.reason, this.cause});

  final String reason;
  final Object? cause;

  @override
  String toString() => 'SyniInstallFailed(reason: $reason)';
}

enum SyniInstallStage {
  /// Pre-flight checks.
  preflight,

  /// Model + tokenizer download.
  downloadingModel,

  /// SHA-256 verification of the downloaded model.
  verifyingModel,

  /// Persona binding.
  materializingPersona,

  /// libsyni_ffi engine spawn + model load on the worker isolate.
  loadingEngine,
}
