## 0.3.3

### Changed
- OSS launch cleanup: scrubbed internal-implementation references
  (e.g. "Rust core" → "native core"), aligned all install commands to
  `synheart install runtime syni`, corrected podspec author email,
  added LICENSE/CONTRIBUTING/SECURITY parity files, added
  `.pubignore`. No functional change to the public API.
- iOS podspec version synced to 0.3.3 (was drifted at 1.0.0).

## 0.3.2

### Added
- `SyniAgent.bindPersona(SyniPersona)` — bind a persona without
  installing a local model. Cloud chat only needs a persona plus a
  configured `SyniCloudConfig`, so hosts that pick
  `SyniExecutionMode.cloudOnly` no longer have to download a model
  just to attach a persona.

### Fixed
- `chat` / `chatStream` no longer throw "Syni is not installed" in
  `cloudOnly` mode. The chat gate now requires the install state only
  when the request would actually run on device (local / localFirst);
  `cloudOnly` proceeds as long as a persona is bound. `localFirst`
  still wants a model on disk — its fallback-to-cloud path is
  unchanged.

## 0.3.1

### Added
- New bundled spec persona: **`life.companion.v1`** — a reflective
  behavioral-insights companion. Non-prescriptive by default, hedged
  probabilistic language, no emotional or medical labels, frames live
  signals as the user's CURRENT state. Sister to the existing
  `focus.coach.v1` (which prescribes); useful for conversational /
  daily-companion apps where reflection is the goal.

### Changed
- **`focus.coach.v1`** tightened against framing-language drift: live
  signal values are now explicitly framed as the user's CURRENT state.
  Session language (`recent session`, `last session`, `session today`)
  is only used when the provided context includes a non-empty
  `history.recent_sessions` array. If the user asks about a session but
  that array is missing or empty, the model says so plainly instead of
  dressing live state in session language.

Both changes ship via `tool/sync_personas.sh` from `syni-spec`. No
Dart API changes — consumers pick the new persona up via
`SyniSpecPersona.load('life.companion.v1')`, and Focus Coach consumers
benefit from the tightening automatically.

## 0.3.0

### Changed (breaking)
- `SyniCloudConfig.authToken` (a static `Future<String?> Function()` bearer
  provider) is replaced by `authHeaders`, a request-aware
  `Future<Map<String, String>> Function(String method, String url)`. Cloud
  auth headers are now resolved per request — required for `X-Synheart-Proof`
  device attestation, which signs the request method and URL.
- Host SDKs that previously passed a static token provider must update to
  the new shape; the SDK never holds or stores credentials itself.

### Fixed
- `SyniChatResponse.fromCloudReply` now extracts the JSON payload from
  replies wrapped in Markdown code fences (e.g. ` ```{...}``` `) — some
  cloud models emit structured-output JSON inside fences. Plain-text
  replies and unfenced JSON continue to parse as before.

## 0.2.0

### Changed (breaking)
- iOS podspec switched from static `.a` + `force_load` to a vendored
  dynamic framework via `prepare_command` symlink. Consumer apps
  install `SyniRuntime.xcframework` via `synheart install runtime syni`; the
  podspec walks up from `POD_DIR` (or honors `SYNHEART_APP_ROOT`) to
  find it.
- `library_loader.dart` uses `DynamicLibrary.process()` on iOS so
  symbols resolve from the auto-loaded embedded framework (matches the
  pattern in core-flutter v0.5.0).

### Other
- `.gitignore` excludes the symlink the podspec creates at pod-install
  time so it doesn't show up as untracked.

## 0.1.0

First public release.

### Agent layer (`package:syni/agent.dart`)

- `SyniAgent` — install lifecycle, model catalog, persona binding,
  chat / chatStream orchestration, hybrid local/cloud routing via
  `SyniExecutionMode`.
- `SyniInstaller` — model download, tokenizer fetch, SHA-256
  verification, cold-start restore from disk.
- `SyniCloudClient` — HTTP + SSE client for the Syni cloud chat
  endpoint, sticky session id, HSI forwarded as request `context`.
- `SyniSpecPersona.load(id)` — resolves persona JSON from the bundled
  spec assets so the same persona id consistently produces the same
  behavior on both client and server.

### Runtime layer (`package:syni/runtime.dart`)

- `SyniRuntime` — worker-isolate wrapper over the on-device inference
  engine. Engine load + token generation run on a worker so the UI
  thread is free.
- `SyniRuntimeRequest` / `SyniRuntimeResponse` for direct inference.

### Models

- `SyniModels` catalog with two pre-pinned entries:
  - `qwen25_15bInstructQ4` (Qwen 2.5 1.5B Instruct Q4_K_M, ~1.1 GB).
  - `gemma3_1bInstructQ4` (Gemma 3 1B Instruct Q4_K_M, ~770 MB,
    Synheart-hosted mirror).
- Both ship with pinned SHA-256 verified by `SyniInstaller` at install
  time.

### Personas (bundled assets)

Five spec personas mirrored from `syni-spec` and bundled under
`assets/personas/prod/`:

- `focus.coach.v1`
- `stress.coach.v1`
- `cognitive.companion.v1`
- `performance.coach.v1`
- `wellness.guide.v1`

Refresh via `tool/sync_personas.sh`.

### Notes

- The legacy `Syni.initialize` / `Syni.generate` platform-channel API
  remains exported for backwards compatibility but new code should use
  the agent layer.
