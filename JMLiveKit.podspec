Pod::Spec.new do |s|
  s.name             = 'JMLiveKit'
  s.version          = '2.6.22'
  s.summary          = 'LiveKit iOS SDK fork for JMLiveKit'
  s.homepage         = 'https://github.com/NSCodeRover/JMLiveKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Onkar Dhanlobhe' => 'onkar.dhanlobhe@ril.com' }
  s.source           = { :git => 'https://github.com/NSCodeRover/JMLiveKit.git', :tag => 'v2.6.22' }
  s.ios.deployment_target = '13.0'
  s.module_name      = 'JMLiveKit'
  s.swift_versions    = ['5.9']
  
  # Core subspec - App-only functionality (camera, microphone, audio session)
  s.subspec 'Core' do |core|
    core.source_files = 'Sources/Core/**/*.swift', 'Sources/LKObjCHelpers/**/*.{h,m}'
    core.dependency 'Starscream', '~> 4.0'
    core.dependency 'SwiftProtobuf', '~> 1.25.0'
    core.dependency 'PromisesSwift', '~> 2.3'
    core.dependency 'WebRTC-SDK', '~> 114.5735.08'
    core.dependency 'LiveKitWebRTC-LK', '~> 125.6422.33'
    core.dependency 'SwiftLogJM', '1.6.5'
  end
  
  # ScreenShare subspec - Extension-safe functionality (video rendering, broadcast)
  s.subspec 'ScreenShare' do |screenshare|
    screenshare.source_files = 'Sources/ScreenShare/**/*.swift', 'Sources/LKObjCHelpers/**/*.{h,m}'
    screenshare.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
    screenshare.dependency 'Starscream', '~> 4.0'
    screenshare.dependency 'SwiftProtobuf', '~> 1.25.0'
    screenshare.dependency 'PromisesSwift', '~> 2.3'
    screenshare.dependency 'WebRTC-SDK', '~> 114.5735.08'
    screenshare.dependency 'LiveKitWebRTC-LK', '~> 125.6422.33'
    screenshare.dependency 'SwiftLogJM', '1.6.5'
  end
  
  # Default subspec includes everything (for backward compatibility)
  s.default_subspec = 'Core'
end
