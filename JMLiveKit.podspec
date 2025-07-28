Pod::Spec.new do |s|
  s.name             = 'JMLiveKit'
  s.version          = '2.6.25'
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
  s.swift_version = '5.9'
  
  # Dependencies
  s.dependency 'LiveKitWebRTC-LK', '~> 125.6422.33'
  s.dependency 'SwiftProtobuf', '~> 1.30'
  s.dependency 'PromisesSwift', '~> 2.0'
  s.dependency 'SwiftLogJM', '~> 1.0'
  
  # Source files
  s.source_files = 'Sources/LiveKit/**/*.swift'
  
  # Exclude files that are not needed
  s.exclude_files = 'Sources/LiveKit/LiveKit.docc/**/*'
  
  # Framework dependencies
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'CoreAudio', 'CoreMedia', 'CoreVideo', 'Foundation', 'VideoToolbox'
  
  # Subspecs for different targets
  s.subspec 'Core' do |core|
    core.source_files = 'Sources/LiveKit/**/*.swift'
    core.exclude_files = 'Sources/LiveKit/LiveKit.docc/**/*'
  end
  
  s.subspec 'Broadcast' do |broadcast|
    broadcast.source_files = 'Sources/LiveKit/Broadcast/**/*.swift'
    broadcast.dependency 'JMLiveKit/Core'
  end
  
  s.subspec 'WebRTC' do |webrtc|
    webrtc.source_files = 'Sources/LiveKitWebRTCForMediaSoup/**/*.swift'
    webrtc.dependency 'JMLiveKit/Core'
  end
  
  s.subspec 'ObjCHelpers' do |objc|
    objc.source_files = 'Sources/LKObjCHelpers/**/*.{h,m}'
    objc.public_header_files = 'Sources/LKObjCHelpers/include/*.h'
    objc.dependency 'JMLiveKit/Core'
  end
  
  # Default to Core subspec
  s.default_subspecs = 'Core'
end
