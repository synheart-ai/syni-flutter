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
    required this.authHeaders,
    required this.tenantId,
    required this.userId,
    this.projectId = '',
    this.orgId = '',
    this.appId = '',
    this.deviceId = '',
  });

  /// Syni cloud base URL, e.g. `https://api.synheart.ai` or
  /// `http://localhost:8093` for dev.
  final String baseUrl;

  /// Per-request auth-header provider. Given the HTTP [method] and the
  /// absolute request [url], returns the headers to attach — e.g.
  /// `{'X-Synheart-Proof': '<jws>'}` for device-attestation auth.
  ///
  /// It is request-aware because an `X-Synheart-Proof` is signed over the
  /// method and URL and so cannot be a static token. Return an empty map
  /// when no credential is available (the cloud rejects unauthenticated
  /// requests unless it is in test mode with `DISABLE_CHAT_AUTH=true`).
  final Future<Map<String, String>> Function(String method, String url)
      authHeaders;

  final String tenantId;
  final String userId;
  final String projectId;
  final String orgId;
  final String appId;
  final String deviceId;

  /// Value equality over the identity fields that actually gate cloud routing.
  ///
  /// [authHeaders] is intentionally excluded: it is a per-request provider
  /// closure that the host rebuilds on every wire-up, so comparing it by
  /// identity would make every freshly-built config look "different" and force
  /// a needless agent teardown/respawn. When the identity fields below are
  /// unchanged, the agent does not need rebuilding even if a new closure was
  /// supplied (the closure resolves a fresh proof per request regardless).
  @override
  bool operator ==(Object other) =>
      other is SyniCloudConfig &&
      other.baseUrl == baseUrl &&
      other.tenantId == tenantId &&
      other.userId == userId &&
      other.projectId == projectId &&
      other.orgId == orgId &&
      other.appId == appId &&
      other.deviceId == deviceId;

  @override
  int get hashCode =>
      Object.hash(baseUrl, tenantId, userId, projectId, orgId, appId, deviceId);
}
