RFC: syni-dart — Flutter (Dart) Wrapper for Syni SDK

Related Repos:

- syni-core-spec (authoritative contracts: personas/schemas/grammars)
- syni-swift (iOS implementation)
- syni-kotlin (Android implementation)
- syni-cloud-gateway (Go)
Target Platforms: Flutter apps (iOS + Android)
Out of Scope: iOS Keyboard Extension (uses syni-swift directly)

# **1. Summary**

This RFC defines syni-dart, a Dart/Flutter package that provides a unified Syni API for Flutter apps by delegating execution to the native SDKs (syni-swift, syni-kotlin) via platform channels.

syni-dart is intentionally thin:

- it does not perform inference
- it does not implement routing policy
- it does not own schemas/grammars

It exposes a stable Flutter-friendly interface and returns typed structured outputs that match the syni-core-spec contracts.

# **2. Goals**

- Provide a single Flutter API for Syni that matches the native SDK API semantics
- Guarantee schema-versioned structured outputs to Flutter UI
- Avoid duplication of persona routing, schema validation, and inference logic
- Support offline-first behavior as implemented by native engines
- Keep Flutter integration simple and stable across engine changes

# **3. Non-Goals**

- Running LocalEngine inside Dart (no FFI llama.cpp in Flutter for v1)
- Implementing persona routing or engine selection in Dart
- Calling OpenAI directly from mobile apps
- Supporting iOS keyboard extension use cases (native only)

# **4. Design Principles**

1. Thin wrapper, native source of truth
2. Same contracts as native (personas, schema IDs, error semantics)
3. Typed structured outputs for Flutter UI
4. No provider coupling (no OpenAI model names, no llama.cpp knowledge)
5. Deterministic failure behavior (schema-valid fallback responses)

# **5. Architecture Overview**

Flutter App UI

│

▼

syni-dart (API + typed models)

│   (MethodChannel / EventChannel)

├──────────────► syni-swift (iOS)

│                  │

│                  ├─ Local engines (Apple FM / Portable)

│                  └─ Cloud via syni-cloud-gateway

│

└──────────────► syni-kotlin (Android)

│

├─ Local engine (Portable via JNI)

└─ Cloud via syni-cloud-gateway

# **6. Public API (Dart)**

**6.1 Initialization**

await Syni.initialize(SyniConfig config);

- Loads SDK configuration
- Does not download models by default
- Defers native initialization until first call if desired (lazy init allowed)

**6.2 Generate**

final SyniResponse response = await Syni.generate(SyniRequest request);

**6.3 Stream (optional, v1.1+)**

If supported by native:

Stream<SyniStreamEvent> Syni.stream(SyniRequest request);

v1 requirement: generate() must be supported; stream() is optional.

# **7. Data Types & Contracts**

**7.1 Persona IDs (from spec)**

Examples:

- keyboard.v1
- life.coach.v1
- life.insights.v1
- research.debug.v1

syni-dart must:

- accept persona IDs as strings
- optionally provide enums/constants generated from syni-core-spec

**7.2 Schema IDs (from spec)**

syni-dart must treat schema IDs as opaque versioned identifiers.

**7.3 Structured Output**

syni-dart returns:

- raw Map<String, dynamic> outputJson
- plus typed helpers for known schemas (recommended)

Example:

class KeyboardSuggestionResponse {

final List<Suggestion> suggestions;

final Meta meta;

}

Rule: Flutter UI must not depend on raw_text.

# **8. Platform Channel Design**

**8.1 Method Channel**

Channel name:

- com.synheart.syni/sdk

Methods:

- initialize(configJson)
- generate(requestJson) → responseJson
- getModels() (optional)
- downloadModel(modelId) (optional)
- deleteModel(modelId) (optional)

Payloads are JSON strings or maps (choose one; JSON string is simplest for versioning).

**8.2 Event Channel (optional streaming)**

- com.synheart.syni/sdk_stream

Events:

- token deltas (if native supports)
- status events: started, cancelled, completed
- schema validation failure events (debug only)

# **9. Responsibilities**

**9.1 syni-dart MUST**

- Provide stable Dart API
- Serialize/deserialize requests/responses
- Provide typed model classes for known schemas
- Surface errors consistently
- Stay aligned with syni-core-spec versions (declared support)

**9.2 syni-dart MUST NOT**

- Implement persona routing rules
- Implement schema validation logic as source of truth
- Run inference locally
- Talk directly to OpenAI/provider APIs

# **10. Error Model**

syni-dart surfaces errors from native as:

- SyniError.engineUnavailable
- SyniError.invalidRequest
- SyniError.timeout
- SyniError.cancelled
- SyniError.schemaViolation (should be rare; native should fallback)
- SyniError.platformError

Guarantee: even on failures, native should return schema-valid fallback JSON when possible, so UI can render gracefully.

# **11. Offline & Cloud Behavior**

- Offline behavior is controlled by request constraints:
-    - offlineOnly
-    - allowCloud
- 
- syni-dart passes these flags through unchanged.
- Decisions are made natively by Persona + router.

# **12. Telemetry**

syni-dart should:

- forward a clientEventId
- allow app to attach context (app version, device class)
- not log raw user text by default

Native SDKs remain responsible for core telemetry.

# **13. Versioning & Compatibility**

**13.1 syni-dart versioning**

- SemVer: v1.x.y

**13.2 Spec version declaration**

syni-dart must declare:

- supported syni-core-spec version range (e.g., v1.1.x)
- minimum native SDK versions:
    - syni-swift >= 1.2.0
    - syni-kotlin >= 1.2.0
- 

**13.3 Compatibility checks**

On init, syni-dart requests native:

- native_sdk_version
- spec_version
If mismatched beyond allowed range:
- fail fast with clear error
- or degrade to “cloud disabled” mode (policy decision)

# **14. Distribution**

- Publish to pub.dev as syni
- Provide installation docs:
    - iOS: add syni-swift via CocoaPods/SPM integration through Flutter plugin
    - Android: add syni-kotlin dependency via Gradle
- 

# **15. Security & Privacy**

- No provider keys in Dart
- No direct cloud calls from Dart
- No raw text logging in Dart
- Any debug logging must be explicitly enabled and scrubbed

# **16. Rollout Plan**

**Phase 1 (v1.0)**

- initialize()
- generate()
- typed models for:
    - keyboard suggestions
    - coach steps
    - insights cards
- 
- No streaming

**Phase 2 (v1.1+)**

- streaming support where native supports it
- model manager API passthrough
- compatibility checks hardened

# **17. Open Questions**

- Payload format choice: JSON string
- Streaming support requirements for Flutter UI
- Whether typed schema bindings are generated automatically from syni-core-spec

# **18. Conclusion**

syni-dart is a thin, stable Flutter facade over Syni native SDKs.

It ensures Flutter teams get:

- consistent persona behavior
- structured outputs
- offline-first capabilities

…without duplicating inference, routing, or schema enforcement outside native.

