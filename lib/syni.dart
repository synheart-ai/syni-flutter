/// Syni SDK for Flutter.
///
/// A unified Flutter API for Syni that delegates execution to native SDKs
/// (syni-swift on iOS, syni-kotlin on Android) via platform channels.
///
/// ## Getting Started
///
/// Initialize the SDK before making requests:
///
/// ```dart
/// import 'package:syni/syni.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await Syni.initialize(SyniConfig(
///     appId: 'com.example.myapp',
///     appVersion: '1.0.0',
///   ));
///
///   runApp(MyApp());
/// }
/// ```
///
/// ## Generating Responses
///
/// Use [Syni.generate] to get responses from personas:
///
/// ```dart
/// final response = await Syni.generate(SyniRequest(
///   personaId: 'keyboard.v1',
///   input: 'Hello, how are',
/// ));
///
/// // Use typed helpers for known schemas
/// final suggestions = KeyboardSuggestionResponse.fromSyniResponse(response);
/// for (final suggestion in suggestions.suggestions) {
///   print(suggestion.text);
/// }
/// ```
///
/// ## Available Personas
///
/// - `keyboard.v1` - Keyboard suggestions
/// - `life.coach.v1` - Life coaching steps
/// - `life.insights.v1` - Life insights cards
/// - `research.debug.v1` - Debug/research persona
///
/// ## Offline Support
///
/// Control offline behavior via request constraints:
///
/// ```dart
/// final response = await Syni.generate(SyniRequest(
///   personaId: 'keyboard.v1',
///   input: 'Hello',
///   constraints: SyniRequestConstraints(
///     offlineOnly: true, // Never use cloud
///   ),
/// ));
/// ```
library syni;

// Core API
export 'src/syni.dart';
export 'src/config.dart';
export 'src/request.dart';
export 'src/response.dart';
export 'src/errors.dart';

// Typed response models
export 'src/models/models.dart';
