# syni

[![pub package](https://img.shields.io/pub/v/syni.svg)](https://pub.dev/packages/syni)
[![pub points](https://img.shields.io/pub/points/syni)](https://pub.dev/packages/syni/score)
[![popularity](https://img.shields.io/pub/popularity/syni)](https://pub.dev/packages/syni/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Flutter SDK for **Syni** — adaptive on-device LLM inference with hybrid
local/cloud chat, structured persona conditioning, and a streaming chat
API designed for the UI thread.

---

## Features

- 🧠 **On-device inference** — Qwen 2 / 2.5 and Gemma 3 GGUF models
  out of the box; bring your own GGUF for other supported architectures.
- 🌐 **Hybrid local / cloud** — same agent API, choose execution mode
  per call (`localFirst`, `cloudFirst`, `localOnly`, `cloudOnly`).
- 🎭 **Versioned personas** — load by id from bundled
  [`syni-core-spec`](https://github.com/synheart-ai/syni-core-spec) JSON;
  the same id resolves to the same behavior on client and server.
- 🧵 **Worker isolate** so engine load + token generation don't block
  the UI thread.
- 🔒 **Verified model downloads** — pinned SHA-256 per model, checked
  at install time.
- 📡 **Streaming chat** with token-level deltas plus a final structured
  response.

## Platform support

| Android | iOS | macOS | Linux | Windows | Web |
| :-----: | :-: | :---: | :---: | :-----: | :-: |
|   ✅    | ✅  |  🚧   |  🚧   |   🚧    | ❌  |

Android + iOS are the supported targets today. Desktop targets are in
the works. Web is out of scope.

## Getting started

Add the dependency:

```bash
flutter pub add syni
```

Install the runtime via the Synheart CLI:

```bash
synheart install syni
```

This drops the platform binaries into your app's vendor tree
(`synheart/vendor/syni/`) so Gradle / Cocoapods can link them. Re-run
the command anytime you want to refresh — it's idempotent.

Then import the agent layer:

```dart
import 'package:syni/agent.dart';
```

## Usage

A complete runnable Flutter app lives in [`example/`](example/). The
abridged version:

```dart
import 'package:flutter/material.dart';
import 'package:syni/agent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final agent = SyniAgent();

  // Load a persona by id from the bundled spec assets.
  final persona = await SyniSpecPersona.load('focus.coach.v1');

  // First-run install: download + verify the model, load the engine,
  // bind the persona. Emits lifecycle events on agent.installState.
  await agent.install(
    persona: persona,
    model: SyniModels.qwen25_15bInstructQ4,
  );

  // Single-turn chat.
  final response = await agent.chat('How can I focus right now?');
  debugPrint(response.displayText);
}
```

### Streaming

```dart
agent.chatStream('hello').listen((event) {
  switch (event) {
    case SyniChatDelta(:final delta):
      stdout.write(delta);
    case SyniChatFinal(:final response):
      print('\n[${response.displayText.length} chars]');
  }
});
```

### Hybrid local / cloud

```dart
final agent = SyniAgent(
  cloudConfig: SyniCloudConfig(
    baseUrl: 'https://api.synheart.ai',
    authToken: () async => '<bearer-token>',
    tenantId: '<tenant>',
    userId: '<user>',
  ),
);

await agent.chat(
  'how was my recent session?',
  mode: SyniExecutionMode.cloudFirst, // try cloud, fall back to local
);
```

## Where this fits

`package:syni` is the **agent layer** — inference, install lifecycle,
persona binding, chat orchestration. It does not own:

- HSI signal collection (the
  [`synheart_core`](https://github.com/synheart-ai/synheart-core-flutter)
  SDK does), or
- the four-authority gate (consent + capability + activation + session;
  also a host concern).

Synheart-ecosystem apps typically depend on `synheart_core` and use
`Synheart.syni`, which wraps this package with those layers. Standalone
use of `package:syni` is fully supported when you don't need the wider
Synheart contract.

## Documentation

- [API reference on pub.dev](https://pub.dev/documentation/syni/latest/)
- [Persona spec](https://github.com/synheart-ai/syni-core-spec)

## Contributing

Issues and PRs welcome —
[github.com/synheart-ai/syni-flutter](https://github.com/synheart-ai/syni-flutter).
See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the local dev loop.

## License

[MIT](LICENSE) © Synheart.
