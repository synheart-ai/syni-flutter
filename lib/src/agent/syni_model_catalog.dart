import 'dart:convert';

import 'package:http/http.dart' as http;

import 'syni_model_spec.dart';

/// One entry in the Syni model catalog — a **local** (on-device GGUF) or
/// **cloud** (server-side) model. The two are peers: the client's router
/// picks among them using [optimizedFor] tags, [requires] constraints, and
/// the active execution mode.
sealed class SyniModelOption {
  const SyniModelOption({
    required this.id,
    required this.displayName,
    required this.description,
    required this.optimizedFor,
    required this.requires,
    required this.isDefault,
  });

  /// Stable catalog id.
  final String id;
  final String displayName;
  final String description;

  /// Free-form capability tags the router scores against a task, e.g.
  /// `offline`, `low_latency`, `deep_reasoning`, `long_context`, `privacy`.
  final Set<String> optimizedFor;

  /// Hard constraints the client must satisfy to offer this option, e.g.
  /// `network`, `plan_pro`, `device_class_high`.
  final Set<String> requires;

  /// The recommended default when the caller has no task-specific preference.
  final bool isDefault;

  /// Parse one `/v1/models` manifest entry.
  static SyniModelOption fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final displayName = json['display_name'] as String? ?? id;
    final description = json['description'] as String? ?? '';
    final optimizedFor = _strSet(json['optimized_for']);
    final requires = _strSet(json['requires']);
    final isDefault = json['default'] == true;

    switch (json['kind']) {
      case 'local':
        return SyniLocalModel(
          id: id,
          displayName: displayName,
          description: description,
          optimizedFor: optimizedFor,
          requires: requires,
          isDefault: isDefault,
          spec: SyniModelSpec.fromManifest(
            id,
            json['local'] as Map<String, dynamic>,
          ),
        );
      case 'cloud':
        final cloud = json['cloud'] as Map<String, dynamic>? ?? const {};
        return SyniCloudModel(
          id: id,
          displayName: displayName,
          description: description,
          optimizedFor: optimizedFor,
          requires: requires,
          isDefault: isDefault,
          serviceModelId: cloud['service_model_id'] as String? ?? 'default',
        );
      default:
        throw FormatException('unknown model kind: ${json['kind']}');
    }
  }

  static Set<String> _strSet(dynamic raw) =>
      raw is List ? raw.whereType<String>().toSet() : <String>{};
}

/// An on-device model — runs via the candle runtime. [spec] is what
/// `SyniAgent.install` needs to download + load it.
class SyniLocalModel extends SyniModelOption {
  const SyniLocalModel({
    required super.id,
    required super.displayName,
    required super.description,
    required super.optimizedFor,
    required super.requires,
    required super.isDefault,
    required this.spec,
  });

  final SyniModelSpec spec;
}

/// A server-side model — runs via `syni-service`. [serviceModelId] is the
/// id the service routes to internally; the client never needs the
/// provider/model details.
class SyniCloudModel extends SyniModelOption {
  const SyniCloudModel({
    required super.id,
    required super.displayName,
    required super.description,
    required super.optimizedFor,
    required super.requires,
    required super.isDefault,
    required this.serviceModelId,
  });

  final String serviceModelId;
}

/// Fetches + caches the Syni model catalog from `syni-service`
/// `GET /v1/models`.
///
/// Auth token and base URL are **injected by the host SDK** (`synheart_core`)
/// — `syni-flutter` does not own credentials. With no base URL configured,
/// or on any fetch failure (offline, non-200), the catalog falls back to
/// [bundled] — so it always returns *something*.
class SyniModelCatalog {
  SyniModelCatalog({
    String? baseUrl,
    Future<String?> Function()? authToken,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _authToken = authToken,
        _http = httpClient ?? http.Client();

  final String? _baseUrl;
  final Future<String?> Function()? _authToken;
  final http.Client _http;

  List<SyniModelOption>? _cache;

  /// Available models. Fetches `/v1/models` on first call (when a base URL
  /// is configured), caches the result, and falls back to [bundled] on any
  /// failure. Pass `forceRefresh: true` to re-fetch.
  Future<List<SyniModelOption>> available({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;
    if (_baseUrl == null) return _cache = bundled;
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final token = await _authToken?.call();
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final resp = await _http.get(
        Uri.parse('$_baseUrl/v1/models'),
        headers: headers,
      );
      if (resp.statusCode != 200) return _cache = bundled;

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final models = (decoded['models'] as List)
          .whereType<Map<String, dynamic>>()
          .map(SyniModelOption.fromJson)
          .toList();
      return _cache = models.isEmpty ? bundled : models;
    } catch (_) {
      // Offline / malformed / network error — degrade to the bundled set.
      return _cache = bundled;
    }
  }

  /// The bundled fallback catalog — always available, no network. Mirrors
  /// `syni-service`'s `GetDefaultModels`. Kept in sync by hand for V1; once
  /// the manifest is authoritative this is purely an offline safety net.
  static List<SyniModelOption> get bundled => [
        SyniLocalModel(
          id: SyniModels.qwen25_15bInstructQ4.id,
          displayName: 'Qwen2.5 1.5B (on-device)',
          description:
              'Runs fully on-device. Private, offline-capable, low-latency. '
              'Modest reasoning depth.',
          optimizedFor: const {'offline', 'privacy', 'low_latency'},
          requires: const {},
          isDefault: true,
          spec: SyniModels.qwen25_15bInstructQ4,
        ),
        const SyniCloudModel(
          id: 'cloud-default',
          displayName: 'Syni Cloud',
          description:
              'Runs server-side via Syni Cloud. Deeper reasoning, longer '
              'context. Requires a network connection.',
          optimizedFor: {'deep_reasoning', 'long_context', 'quality'},
          requires: {'network'},
          isDefault: false,
          serviceModelId: 'default',
        ),
      ];
}
