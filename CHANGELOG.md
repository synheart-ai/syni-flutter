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

Five spec personas mirrored from `syni-core-spec` and bundled under
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
