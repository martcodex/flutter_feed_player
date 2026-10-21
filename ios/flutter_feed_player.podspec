Pod::Spec.new do |s|
  s.name             = 'flutter_feed_player'
  s.version          = '0.1.6'
  s.summary          = 'Picture in picture for flutter_feed_player.'
  s.description      = s.summary
  s.homepage         = 'https://github.com/martcodex/flutter_feed_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'martcodex' => 'dev@martcodex.local' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'AVKit', 'AVFoundation'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
