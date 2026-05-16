import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'syni_persona.dart';

/// Loads a [SyniPersona] from a bundled `syni-spec` JSON asset.
///
/// Consumers should prefer this over inlining persona fields (id,
/// system_prompt, output schema) in app code — the spec file is the
/// authoritative definition shared with the cloud, and keeping consumers
/// at arm's length from it means a single update in `syni-spec`
/// propagates everywhere on the next sync + rebuild.
///
/// V1 lookup is by id only (e.g. `focus.coach.v1`) and searches the
/// `prod` tier. Future versions may add `research`, environment
/// overrides, or a remote-fetched registry — call sites only need to
/// pass an id, so they don't need to change.
class SyniSpecPersona {
  SyniSpecPersona._();

  /// Resolve and parse the bundled persona JSON for [id]. Throws
  /// [SyniSpecPersonaException] when the id is unknown or the JSON
  /// can't be projected onto [SyniPersona].
  static Future<SyniPersona> load(String id) async {
    final assetPath = 'packages/syni/assets/personas/prod/$id.json';
    final String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      throw SyniSpecPersonaException(
        'persona "$id" not bundled at $assetPath',
        cause: e,
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw SyniSpecPersonaException('persona "$id": invalid JSON', cause: e);
    }

    return _fromJson(json);
  }

  static SyniPersona _fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final name = j['name'] as String?;
    final systemPrompt = j['system_prompt'] as String?;
    final outputSchemaId = j['output_schema_id'] as String?;
    if (id == null ||
        name == null ||
        systemPrompt == null ||
        outputSchemaId == null) {
      throw SyniSpecPersonaException(
        'spec persona missing one of {id, name, system_prompt, output_schema_id}',
      );
    }
    return SyniPersona(
      id: id,
      displayName: name,
      systemPrompt: systemPrompt,
      responseSchemaId: _normalizeOutputSchema(outputSchemaId),
    );
  }

  /// Map a versioned spec output schema id to the short name the runtime
  /// expects (`coach`, `chat`, `suggestions`). Stripped of any `.response.vN`
  /// suffix and lowercased.
  static String _normalizeOutputSchema(String id) {
    final base = id.split('.').first;
    return base.toLowerCase();
  }
}

class SyniSpecPersonaException implements Exception {
  SyniSpecPersonaException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() {
    final tail = cause == null ? '' : ' (cause: $cause)';
    return 'SyniSpecPersonaException: $message$tail';
  }
}
