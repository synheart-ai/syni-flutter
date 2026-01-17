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
  # TODO: Add syni-swift dependency when available
  # s.dependency 'syni-swift', '~> 1.2.0'
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.0'
end
