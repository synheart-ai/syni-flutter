/// Public entry point for the Syni agent layer — install lifecycle, model
/// management, persona binding, and chat orchestration over the local
/// runtime.
///
/// The host SDK (`synheart_core`) consumes this and wraps it with the
/// four-authority gate + HSI context builder, re-exposing it as
/// `Synheart.syni`. App developers should depend on `synheart_core`, not
/// `package:syni` directly.
library;

export 'src/agent/syni_agent.dart';
export 'src/agent/syni_chat.dart';
export 'src/agent/syni_cloud_client.dart' show SyniCloudException;
export 'src/agent/syni_cloud_config.dart';
export 'src/agent/syni_install_state.dart';
export 'src/agent/syni_installer.dart' show SyniInstaller, SyniInstallException;
export 'src/agent/syni_model_catalog.dart';
export 'src/agent/syni_model_spec.dart';
export 'src/agent/syni_persona.dart';
export 'src/agent/syni_spec_persona.dart';
// The agent's chat/stream calls surface local-runtime failures as
// [SyniRuntimeError] (carrying the runtime's stable `code` + `retryable`), so
// it belongs on the agent's public surface alongside [SyniCloudException].
export 'src/runtime/syni_runtime.dart' show SyniRuntimeError;
