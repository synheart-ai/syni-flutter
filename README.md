# syni

Flutter (Dart) wrapper for Syni. This package provides a unified Flutter API that delegates execution to the native Syni SDKs via platform channels.

## Usage

Add the dependency:

```bash
flutter pub add syni
```

Initialize once at app start:

```dart
import 'package:flutter/widgets.dart';
import 'package:syni/syni.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Syni.initialize(const SyniConfig(
    appId: 'com.example.myapp',
    appVersion: '1.0.0',
  ));

  // runApp(...)
}
```

Generate a response:

```dart
final response = await Syni.generate(const SyniRequest(
  personaId: 'keyboard.v1',
  input: 'Hello, how are',
));

// Raw structured output
print(response.outputJson);
```

Typed helpers for known schemas live in `package:syni/models.dart`:

```dart
import 'package:syni/syni.dart';
import 'package:syni/models.dart';

final response = await Syni.generate(const SyniRequest(
  personaId: 'keyboard.v1',
  input: 'Hello, how are',
));

final suggestions = KeyboardSuggestionResponse.fromSyniResponse(response);
```

## Platform notes

This Flutter package communicates with native SDKs over a MethodChannel:

- Channel: `com.synheart.syni/sdk`
- Methods: `initialize`, `generate`, `getModels`, `downloadModel`, `deleteModel`

Native SDK integration (syni-swift / syni-kotlin) is expected to be provided via the iOS podspec and Android Gradle dependency when available.

## Docs

- Design RFC: `doc/rfc.md`
