Pod::Spec.new do |s|
  s.name             = 'syni'
  s.version          = '1.0.0'
  s.summary          = 'Internal Dart FFI bindings for libsyni_ffi'
  s.description      = <<-DESC
Flutter plugin that provides Dart FFI access to libsyni_ffi (Rust core
inference engine built from syni-runtime). The plugin itself is a no-op
shell — all functionality lives in Dart. Apps should not depend on this
package directly; use package:synheart_core's Synheart.syni module instead.
                       DESC
  s.homepage         = 'https://github.com/synheart-ai/syni-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Synheart' => 'dev@synheart.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  # ── Native runtime distribution ─────────────────────────────────────
  #
  # syni-runtime is proprietary and shipped via the `synheart` CLI.
  # `synheart install syni` writes the right variant + version
  # to `<app>/synheart/vendor/syni-runtime/ios/SyniRuntime.xcframework`.
  #
  # The framework is a DYNAMIC `cdylib` wrapped in `.framework` — see
  # synheart_core.podspec for the full reasoning on why we moved off
  # static + force_load. Symlinked from the CLI install dir into the
  # pod install dir at `pod install` time.
  s.prepare_command = <<-CMD
    set -e
    APP_ROOT="${SYNHEART_APP_ROOT:-}"
    if [ -z "$APP_ROOT" ]; then
      cursor="$(pwd)"
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        cursor="$(cd "$cursor/.." && pwd)"
        # syni-runtime CLI install layout has the xcframework at the
        # vendor package root (not nested under ios/) — different from
        # the legacy `runtime` alias.
        if [ -d "$cursor/synheart/vendor/syni-runtime/SyniRuntime.xcframework" ]; then
          APP_ROOT="$cursor"
          break
        fi
      done
    fi
    if [ -z "$APP_ROOT" ]; then
      echo "syni: could not locate <app>/synheart/vendor/syni-runtime/SyniRuntime.xcframework"
      echo "  Set SYNHEART_APP_ROOT in your Podfile:"
      echo "    ENV['SYNHEART_APP_ROOT'] = File.expand_path('..', __dir__)"
      echo "  And run: synheart install syni"
      exit 1
    fi
    SRC="$APP_ROOT/synheart/vendor/syni-runtime/SyniRuntime.xcframework"
    if [ ! -d "$SRC" ]; then
      echo "syni: framework not found at $SRC"
      echo "  Run: synheart install syni"
      exit 1
    fi
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
