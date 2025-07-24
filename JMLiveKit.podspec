Pod::Spec.new do |s|
  s.name             = 'JMLiveKit'
  s.version          = '2.6.20'
  s.summary          = 'LiveKit iOS SDK fork for JMLiveKit'
  s.homepage         = 'https://github.com/NSCodeRover/JMLiveKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Onkar Dhanlobhe' => 'onkar.dhanlobhe@ril.com' }
  s.source           = { :git => 'https://github.com/NSCodeRover/JMLiveKit.git', :tag => 'v2.6.20' }
  s.ios.deployment_target = '13.0'
  s.source_files = 'Sources/LiveKit/**/*.swift', 'Sources/LKObjCHelpers/**/*.{h,m}'
  s.module_name      = 'JMLiveKit'
  s.swift_versions    = ['5.9']
  s.dependency 'Starscream', '~> 4.0'
  s.dependency 'SwiftProtobuf', '~> 1.25.0'
  s.dependency 'PromisesSwift', '~> 2.3'
  s.dependency 'WebRTC-SDK', '~> 114.5735.08'
  s.dependency 'LiveKitWebRTC-LK', '~> 125.6422.33'
  s.dependency 'SwiftLogJM', '1.6.5'
end
