## 0.2.0

### Changed (breaking)
- `SyniCloudConfig.authToken` (a static `Future<String?> Function()` bearer
  provider) is replaced by `authHeaders`, a request-aware
  `Future<Map<String, String>> Function(String method, String url)`. Cloud
  auth headers are now resolved per request — required for `X-Synheart-Proof`
  device attestation, which signs the request method and URL.
- iOS podspec switched from static `.a` + `force_load` to a vendored
  dynamic framework via `prepare_command` symlink. Consumer apps
  install `SyniRuntime.xcframework` via `synheart install syni`; the
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
