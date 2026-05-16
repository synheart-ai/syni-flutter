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

  # The native static library is provisioned INTO THE CONSUMER APP by
  # `make vendor-app-ios` (syni-runtime), landing at
  # <app>/synheart/vendor/syni/ios/SyniRuntime.xcframework/. This mirrors
  # how synheart-core-runtime is provisioned. ${PODS_ROOT} is <app>/ios/Pods,
  # so ../../ resolves to the app root.
  #
  # Force-load preserves the syni_* C ABI symbols so Dart FFI's
  # DynamicLibrary.process() / dlsym can resolve them — including in
  # release/Archive builds where the linker would otherwise strip them.
  lib_path = '"${PODS_ROOT}/../../synheart/vendor/syni/ios/SyniRuntime.xcframework/ios-arm64/libsyni_ffi.a"'

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => "$(inherited) -force_load #{lib_path} -lc++",
    'DEAD_CODE_STRIPPING' => 'NO',
    # Preserve syni_* globals through Archive's strip so Dart FFI's
    # DynamicLibrary.process() can still resolve them in TestFlight builds.
    'STRIP_STYLE' => 'non-global',
  }

  s.dependency 'Flutter'
end
