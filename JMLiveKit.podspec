Pod::Spec.new do |s|
  s.name             = 'JMLiveKit'
  s.version          = '2.6.23'
  s.summary          = 'LiveKit iOS SDK fork for JMLiveKit'
  s.description      = <<-DESC
    LiveKit iOS SDK fork with additional features and optimizations for JioMeet integration.
    Provides real-time audio and video communication capabilities with WebRTC support.
    Supports both main app and app extension targets through subspecs.
  DESC
  s.homepage         = 'https://github.com/NSCodeRover/JMLiveKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Onkar Dhanlobhe' => 'onkar.dhanlobhe@ril.com' }
  s.source           = { :git => 'https://github.com/NSCodeRover/JMLiveKit.git', :tag => "v#{s.version}" }
  
  # Platform and Swift version
  s.ios.deployment_target = '13.0'
  s.swift_versions = ['5.7', '5.8', '5.9']
  
  # Source files
  s.source_files = [
    'Sources/LiveKit/**/*.{swift,h,m}',
    'Sources/LKObjCHelpers/**/*.{swift,h,m}',
    'Sources/LiveKitWebRTCForMediaSoup/**/*.{swift,h,m}'
  ]
  
  # Exclude test files
  s.exclude_files = [
    'Sources/**/*Tests.swift',
    'Sources/**/*Test.swift',
    'Tests/**/*'
  ]
  
  # Dependencies
  s.dependency 'SwiftProtobuf', '~> 1.25.0'
  s.dependency 'Starscream', '~> 4.0'
  s.dependency 'PromisesSwift', '~> 2.3'
  s.dependency 'WebRTC-SDK', '~> 114.5735.08'
  s.dependency 'LiveKitWebRTC-LK', '~> 125.6422.33'
  s.dependency 'SwiftLogJM', '1.6.6'
  s.dependency 'swift-collections', '~> 1.0'
  
  # Module name
  s.module_name = 'JMLiveKit'
  
  # Resource bundle for privacy info
  s.resource_bundles = {
    'LiveKitPrivacy' => ['Sources/LiveKit/PrivacyInfo.xcprivacy']
  }
  
  # Build configuration
  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'JMLIVEKIT_CORE',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64 x86_64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  
  # User target configuration
  s.user_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO'
  }
end
