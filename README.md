# syni

[![pub package](https://img.shields.io/pub/v/syni.svg)](https://pub.dev/packages/syni)

Flutter SDK for **Syni** — adaptive, on-device LLM inference with hybrid
local/cloud chat, structured persona conditioning, and an isolate-worker
FFI bridge to a Rust runtime.

- **On-device inference** via [`syni-runtime`](https://github.com/synheart-ai/syni-portable-local-engine)
  (pure-Rust, GGUF). Currently dispatches Qwen2/Qwen2.5 and Gemma 3
  architectures.
- **Hybrid local/cloud** chat — same agent API, choose execution mode
  per call (`localFirst` / `cloudFirst` / `localOnly` / `cloudOnly`).
- **Persona spec** — versioned persona definitions
  ([`syni-core-spec`](https://github.com/synheart-ai/syni-core-spec))
  bundled as assets and resolved by id at runtime.
- **Isolate worker** so engine load + token generation don't block the UI.

## Install

```bash
flutter pub add syni
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:syni/agent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final agent = SyniAgent();

  Future<void> _setup() async {
    final persona = await SyniSpecPersona.load('focus.coach.v1');
    await agent.install(
      persona: persona,
      model: SyniModels.qwen25_15bInstructQ4,
    );
    final reply = await agent.chat('How can I focus right now?');
    debugPrint(reply.displayText);
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(/* ... */);
}
```

A complete runnable Flutter app is in [`example/`](example/).

## Concepts

### Personas

A persona is a versioned behavioral contract — system prompt, output
schema, rules. Load by id from the bundled spec:

```dart
final persona = await SyniSpecPersona.load('focus.coach.v1');
```

The same id resolves to the same definition on both client and server,
so a hybrid chat behaves consistently regardless of execution mode.

### Models

The catalog (`SyniModels`) ships a small curated set with pinned
SHA-256 hashes verified at install time. Two sample entries:

- `SyniModels.qwen25_15bInstructQ4` — Qwen 2.5 1.5B Instruct Q4_K_M (~1.1 GB)
- `SyniModels.gemma3_1bInstructQ4` — Gemma 3 1B Instruct Q4_K_M (~770 MB)

For broader catalogs, fetch a server-signed `/v1/models` manifest and
construct `SyniModelSpec` directly.

### Execution modes

```dart
await agent.chat(
  'hello',
  mode: SyniExecutionMode.localFirst, // try local, fall back to cloud
);
```

`localOnly` and `cloudOnly` are also available. Cloud mode requires a
`SyniCloudConfig` injected when constructing the agent.

### Streaming

```dart
agent.chatStream('hello').listen((event) {
  if (event is SyniChatDelta) print(event.delta);
  if (event is SyniChatFinal) print('done: ${event.response.displayText}');
});
```

## Where this fits

`package:syni` is the agent layer — it owns inference, install
lifecycle, persona binding, and chat orchestration. It does **not**
own:

- HSI signal collection / fusion (provided by the host SDK).
- The four-authority gate (consent + capability + activation +
  session) — also a host concern.

If you're building a Synheart-ecosystem app, you typically depend on
[`synheart_core`](https://github.com/synheart-ai/synheart-core-flutter)
and use `Synheart.syni`, which wraps this package with those layers.
Standalone use of `package:syni` is fully supported when you don't
need the wider Synheart contract.

## License

MIT. See [`LICENSE`](LICENSE).
