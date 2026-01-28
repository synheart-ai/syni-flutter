Pod::Spec.new do |s|
  s.name             = 'syni'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for Syni SDK'
  s.description      = <<-DESC
Flutter plugin that provides a unified Syni API by delegating to syni-swift on iOS.
                       DESC
  s.homepage         = 'https://github.com/synheart/syni-dart'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Synheart' => 'dev@synheart.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  # SyniSwift dependency - use local path for development
  # For production, this would be a published pod:
  # s.dependency 'SyniSwift', '~> 1.0.0'
  s.dependency 'SyniSwift', :path => '../../syni-swift'

  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  # SyniSwift requires the SyniRuntime XCFramework
  s.xcconfig = {
    'OTHER_LDFLAGS' => '-lc++'
  }
end
