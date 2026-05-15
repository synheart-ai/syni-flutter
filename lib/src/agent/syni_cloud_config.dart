/// Configuration the cloud client needs from the host SDK.
///
/// `syni-flutter` owns no credentials and no tenant identity — those belong
/// to the host SDK (`synheart_core`'s auth + project setup). The host SDK
/// constructs this and injects it when constructing the agent. With no
/// config injected, the agent runs local-only.
library;

class SyniCloudConfig {
  const SyniCloudConfig({
    required this.baseUrl,
    required this.authToken,
    required this.tenantId,
    required this.userId,
    this.projectId = '',
    this.orgId = '',
    this.appId = '',
    this.deviceId = '',
  });

  /// `syni-service` base URL, e.g. `https://api.synheart.ai` or
  /// `http://localhost:8093` for dev.
  final String baseUrl;

  /// Async bearer token provider. Returns `null` when no token is available
  /// (the cloud will fail unauthenticated unless it is in test mode with
  /// `DISABLE_CHAT_AUTH=true`).
  final Future<String?> Function() authToken;

  final String tenantId;
  final String userId;
  final String projectId;
  final String orgId;
  final String appId;
  final String deviceId;
}
