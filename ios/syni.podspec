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
  s.dependency 'Flutter'

  # libsyni_ffi is statically linked into the app binary via the xcframework
  # produced by `syni-runtime`'s Makefile. Dart FFI looks up symbols with
  # DynamicLibrary.process(); no SyniSwift / SyniRuntime pod required.
  #
  # TODO(release): vendor the xcframework once syni-runtime publishes a
  # tagged build. For local dev, copy `syni-runtime/build/ios/SyniRuntime.xcframework`
  # into `ios/Frameworks/` and uncomment:
  # s.vendored_frameworks = 'Frameworks/SyniRuntime.xcframework'

  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  s.xcconfig = {
    'OTHER_LDFLAGS' => '-lc++'
  }
end
