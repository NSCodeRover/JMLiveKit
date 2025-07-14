Pod::Spec.new do |s|
  s.name             = 'LiveKit'
  s.version          = '2.6.1'
  s.summary          = 'LiveKit iOS SDK - Real-time audio and video communication'
  s.description      = <<-DESC
    LiveKit iOS SDK provides real-time audio and video communication capabilities.
    This is a fork of the official LiveKit client SDK with additional features
    and optimizations for JioMeet integration.
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
  
  # Platform and Swift version
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_versions = ['5.7', '5.8', '5.9']
  
  # Source files
  s.source_files = [
    'Sources/LiveKit/**/*.{swift,h,m}',
    'Sources/LKObjCHelpers/**/*.{swift,h,m}'
  ]
  
  # Exclude test files
  s.exclude_files = [
    'Sources/**/*Tests.swift',
    'Sources/**/*Test.swift',
    'Tests/**/*'
  ]
  
  # Dependencies
  s.dependency 'SwiftProtobuf', '~> 1.25.0'
  s.dependency 'Logging', '= 1.5.4'
  s.dependency 'DequeModule', '= 1.1.4'
  s.dependency 'OrderedCollections', '= 1.1.4'
  
  # Resource bundle for privacy info
  s.resource_bundles = {
    'LiveKitPrivacy' => ['Sources/LiveKit/PrivacyInfo.xcprivacy']
  }
  
  # Build configuration
  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) COCOAPODS',
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64 x86_64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  
  # User target configuration
  s.user_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO'
  }
  
  # Xcode version specific settings
  xcode_output = `xcodebuild -version`.strip
  major_version = xcode_output =~ /Xcode\s+(\d+)/ ? $1.to_i : 15
  
  if major_version >= 15
    s.pod_target_xcconfig['OTHER_SWIFT_FLAGS'] = '$(inherited) -enable-experimental-feature AccessLevelOnImport'
  end
  
  # Note: LiveKitWebRTC should be added separately via Swift Package Manager
  # or as a separate pod dependency in the consuming project
end
