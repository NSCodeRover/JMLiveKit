Pod::Spec.new do |s|
  s.name             = 'LiveKitWebRTC'
  s.version          = '125.6422.33'
  s.summary          = 'WebRTC framework for LiveKit iOS SDK'
  s.description      = <<-DESC
    WebRTC framework specifically built for LiveKit iOS SDK.
    This provides the LKRTC-prefixed WebRTC classes used by LiveKit.
  DESC
  s.homepage         = 'https://github.com/NSCodeRover/JMLiveKit'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 
    'LiveKit' => 'info@livekit.io',
    'Onkar Dhanlobhe' => 'onkar.dhanlobhe@ril.com'
  }
  s.source           = { 
    :git => 'https://github.com/NSCodeRover/JMLiveKit.git', 
    :tag => 'v2.6.1' 
  }
  
  # Platform
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  
  # Framework files
  s.vendored_frameworks = 'LiveKitWebRTC.xcframework'
  
  # Module map
  s.module_map = 'LiveKitWebRTC.modulemap'
  
  # Build configuration
  s.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited)',
    'OTHER_LDFLAGS' => '-framework LiveKitWebRTC',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64 x86_64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  
  # User target configuration
  s.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited)',
    'OTHER_LDFLAGS' => '$(inherited) -framework LiveKitWebRTC',
    'ENABLE_BITCODE' => 'NO'
  }
  
  # No dependencies for this framework
  # s.dependency is not needed when there are no dependencies
end 