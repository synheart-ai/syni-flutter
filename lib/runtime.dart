/// Public entry point for `package:syni`'s Dart FFI runtime.
///
/// Re-exports the runtime surface so consumers can `import 'package:syni/runtime.dart'`
/// without reaching into `src/`. Today the only intended consumer is
/// `package:synheart_core`'s `SyniModule`; app developers should not import
/// this directly.
library;

export 'src/runtime/runtime.dart';
