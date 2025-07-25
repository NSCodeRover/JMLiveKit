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
  s.osx.deployment_target = '10.15'
  s.swift_versions = ['5.7', '5.8', '5.9']
  
  # Default subspec (Core) - allows using just 'pod JMLiveKit'
  s.default_subspec = 'Core'
  
  # Main spec includes Core by default
  s.source_files = [
    'Sources/LiveKit/**/*.{swift,h,m}',
    'Sources/LKObjCHelpers/**/*.{swift,h,m}',
    'Sources/LiveKitWebRTCForMediaSoup/**/*.{swift,h,m}'
  ]
  
  # Exclude test files and screen share files from main spec
  s.exclude_files = [
    'Sources/**/*Tests.swift',
    'Sources/**/*Test.swift',
    'Tests/**/*',
    'Sources/LiveKit/Broadcast/**/*'  # Exclude broadcast files from main spec
  ]
  
  # Dependencies for main spec (same as Core)
  s.dependency 'SwiftProtobuf', '~> 1.25.0'
  s.dependency 'Starscream', '~> 4.0'
  s.dependency 'PromisesSwift', '~> 2.3'
  s.dependency 'WebRTC-SDK', '~> 114.5735.08'
  # Temporarily removed swift-log due to compilation issues
  # s.dependency 'swift-log', '~> 1.5.0'
  s.dependency 'swift-collections', '~> 1.0'
  
  # Module name
  s.module_name = 'JMLiveKit'
  
  # Public headers
  s.public_header_files = 'Sources/LiveKit/JMLiveKitSubspecs.h'
  
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

  # MARK: - Core Subspec (Main App)
  s.subspec 'Core' do |core|
    # Source files for main app (includes camera, UI, etc.)
    core.source_files = [
      'Sources/LiveKit/**/*.{swift,h,m}',
      'Sources/LKObjCHelpers/**/*.{swift,h,m}',
      'Sources/LiveKitWebRTCForMediaSoup/**/*.{swift,h,m}'
    ]
    
    # Exclude test files and screen share files
    core.exclude_files = [
      'Sources/**/*Tests.swift',
      'Sources/**/*Test.swift',
      'Tests/**/*',
      'Sources/LiveKit/Broadcast/**/*'  # Exclude broadcast files from Core
    ]
    
    # Dependencies for main app
    core.dependency 'SwiftProtobuf', '~> 1.25.0'
    core.dependency 'Starscream', '~> 4.0'
    core.dependency 'PromisesSwift', '~> 2.3'
    core.dependency 'WebRTC-SDK', '~> 114.5735.08'
    # Temporarily removed swift-log due to compilation issues
    # core.dependency 'swift-log', '~> 1.5.0'
    core.dependency 'swift-collections', '~> 1.0'
    
    # Core can use app-only APIs (camera, UI, etc.)
    core.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) COCOAPODS JMLIVEKIT_CORE=1',
      'ENABLE_BITCODE' => 'NO',
      'VALID_ARCHS' => 'arm64 x86_64',
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
    }
  end

  # MARK: - ScreenShare Subspec (App Extensions)
  s.subspec 'ScreenShare' do |ss|
    # Source files for app extensions (ReplayKit, broadcast, etc.)
    ss.source_files = [
      'Sources/ScreenShare/**/*.{swift,h,m}'
    ]
    
    # Exclude test files
    ss.exclude_files = [
      'Sources/**/*Tests.swift',
      'Sources/**/*Test.swift',
      'Tests/**/*'
    ]
    
    # Dependencies for screen share (minimal, extension-safe)
    ss.dependency 'SwiftProtobuf', '~> 1.25.0'
    # Temporarily removed swift-log due to compilation issues
    # ss.dependency 'swift-log', '~> 1.5.0'
    ss.dependency 'swift-collections', '~> 1.0'
    
    # Extension-safe configuration
    ss.pod_target_xcconfig = {
      'APPLICATION_EXTENSION_API_ONLY' => 'YES',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) COCOAPODS JMLIVEKIT_SCREENSHARE=1',
      'ENABLE_BITCODE' => 'NO',
      'VALID_ARCHS' => 'arm64 x86_64',
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
    }
    
    # Frameworks available in extensions
    ss.frameworks = [
      'ReplayKit',
      'CoreMedia',
      'CoreVideo',
      'Foundation'
    ]
  end

  # MARK: - WebRTC Subspec (Optional, for advanced users)
  s.subspec 'WebRTC' do |webrtc|
    webrtc.dependency 'JMLiveKit/Core'
    webrtc.dependency 'WebRTC-SDK', '~> 114.5735.08'
    
    webrtc.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) COCOAPODS JMLIVEKIT_WEBRTC=1',
      'ENABLE_BITCODE' => 'NO',
      'VALID_ARCHS' => 'arm64 x86_64',
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
    }
  end
end
