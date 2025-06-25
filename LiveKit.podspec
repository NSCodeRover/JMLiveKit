Pod::Spec.new do |s|
  s.name             = 'LiveKit'
  s.version          = '1.1.6'
  s.summary          = 'LiveKit iOS SDK fork for JMLiveKit'
  s.homepage         = 'https://github.com/NSCodeRover/JMLiveKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Onkar Dhanlobhe' => 'onkar.dhanlobhe@ril.com' }
  s.source           = { :git => 'https://github.com/NSCodeRover/JMLiveKit.git', :commit => '33d2fe0c57cc830af2698b4d5b8fdec76d22c9e4' }
  s.ios.deployment_target = '14.0'
  s.source_files     = 'Sources/LiveKit/**/*.{swift,h,m}', 'Sources/LKObjCHelpers/**/*.{swift,h,m}'
  s.swift_version    = '5.9'
  s.dependency 'Starscream', '~> 4.0'
  s.dependency 'SwiftProtobuf', '~> 1.25.0'
  s.dependency 'PromisesSwift', '~> 2.3'
  s.dependency 'WebRTC-SDK', '~> 114.5735.08'
end
