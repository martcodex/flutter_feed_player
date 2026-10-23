Pod::Spec.new do |s|
  s.name             = 'flutter_feed_player'
  s.version          = '0.1.8'
  s.summary          = 'Picture in picture for flutter_feed_player.'
  s.description      = s.summary
  s.homepage         = 'https://github.com/martcodex/flutter_feed_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'martcodex' => 'dev@martcodex.local' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_feed_player/Sources/flutter_feed_player/**/*.swift'
  s.resource_bundles = {'flutter_feed_player_privacy' => ['flutter_feed_player/Sources/flutter_feed_player/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'AVKit', 'AVFoundation'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
