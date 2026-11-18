Pod::Spec.new do |s|
  s.name             = 'syni'
  s.version          = '0.4.0'
  s.summary          = 'Dart FFI bindings for the Synheart on-device agent runtime'
  s.description      = <<-DESC
Flutter plugin that provides Dart FFI access to libsyni_ffi (the native
on-device inference engine from syni-runtime). The plugin itself is a
no-op shell — all functionality lives in Dart.
                       DESC
  s.homepage         = 'https://github.com/synheart-ai/syni-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SynHeart AI' => 'eng@synheart.ai' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  # ── Native runtime distribution ─────────────────────────────────────
  #
  # syni-runtime is shipped via the `synheart` CLI.
  # `synheart install runtime syni` writes the right variant + version
  # to `<app>/synheart/vendor/syni-runtime/ios/SyniRuntime.xcframework`,
  # beside `android/jniLibs/`, the same layout as the Synheart core runtime.
  # Symlinked from the CLI install dir into the pod install dir at
  # `pod install` time.
  #
  # syni-runtime before 0.6.0 put the xcframework at the package root
  # (`syni-runtime/SyniRuntime.xcframework`). syni 0.3.8 was the last release
  # to read it; when only that copy exists, `pod install` says so and stops.
  s.prepare_command = <<-CMD
    set -e
    NEW_REL="synheart/vendor/syni-runtime/ios/SyniRuntime.xcframework"
    OLD_REL="synheart/vendor/syni-runtime/SyniRuntime.xcframework"
    APP_ROOT="${SYNHEART_APP_ROOT:-}"
    if [ -z "$APP_ROOT" ]; then
      cursor="$(pwd)"
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        cursor="$(cd "$cursor/.." && pwd)"
        if [ -d "$cursor/$NEW_REL" ] || [ -d "$cursor/$OLD_REL" ]; then
          APP_ROOT="$cursor"
          break
        fi
      done
    fi
    if [ -z "$APP_ROOT" ]; then
      echo "syni: could not locate <app>/$NEW_REL"
      echo "  Set SYNHEART_APP_ROOT in your Podfile:"
      echo "    ENV['SYNHEART_APP_ROOT'] = File.expand_path('..', __dir__)"
      echo "  And run: synheart install runtime syni"
      exit 1
    fi
    if [ ! -d "$APP_ROOT/$NEW_REL" ]; then
      echo "syni: framework not found at $APP_ROOT/$NEW_REL"
      if [ -d "$APP_ROOT/$OLD_REL" ]; then
        echo "  Found $OLD_REL, the layout from before syni-runtime 0.6.0,"
        echo "  which this syni release no longer reads."
      fi
      echo "  Run: synheart install runtime syni"
      exit 1
    fi
    SRC="$APP_ROOT/$NEW_REL"
    rm -rf SyniRuntime.xcframework
    ln -s "$SRC" SyniRuntime.xcframework
  CMD

  s.vendored_frameworks = 'SyniRuntime.xcframework'

  s.user_target_xcconfig = {
    # Preserve syni_* globals through Archive's strip so Dart FFI's
    # DynamicLibrary.open()/dlsym can still resolve them in TestFlight
    # builds.
    'STRIP_STYLE' => 'non-global',
  }

  s.dependency 'Flutter'
end
