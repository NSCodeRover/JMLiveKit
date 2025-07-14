Pod::Spec.new do |s|
  s.name             = 'JMLiveKit'
  s.version          = '1.1.6'
  s.summary          = 'LiveKit iOS SDK fork for JMLiveKit'
  s.homepage         = 'https://github.com/NSCodeRover/JMLiveKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Onkar Dhanlobhe' => 'onkar.dhanlobhe@ril.com' }
  s.source           = { :git => 'https://github.com/NSCodeRover/JMLiveKit.git', :commit => '06c5d29e66db5825bea25cfef00f28e5ec5e1f5e' }
  s.ios.deployment_target = '14.0'
  s.source_files     = 'Sources/LiveKit/**/*.{swift,h,m}', 'Sources/LKObjCHelpers/**/*.{swift,h,m}', 'LiveKitWebRTC.h'
  s.swift_version    = '5.9'
  s.dependency 'Starscream', '~> 4.0'
  s.dependency 'SwiftProtobuf', '~> 1.25.0'
  s.dependency 'PromisesSwift', '~> 2.3'
  s.dependency 'WebRTC-SDK', '~> 114.5735.08'
  
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(PODS_ROOT)/WebRTC-SDK/WebRTC.xcframework/ios-arm64/WebRTC.framework/Headers $(PODS_ROOT)/WebRTC-SDK/WebRTC.xcframework/ios-arm64/WebRTC.framework/Modules',
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/WebRTC-SDK/WebRTC.xcframework/ios-arm64',
    'OTHER_LDFLAGS' => '-framework WebRTC'
  }
  
  s.script_phase = {
    :name => 'Create LiveKitWebRTC Module Map',
    :script => 'WEBRTC_FRAMEWORK_PATH="$PODS_ROOT/WebRTC-SDK/WebRTC.xcframework/ios-arm64/WebRTC.framework"
MODULE_MAP_PATH="$WEBRTC_FRAMEWORK_PATH/Modules/LiveKitWebRTC.modulemap"

# Create module map in WebRTC framework
if [ ! -f "$MODULE_MAP_PATH" ]; then
  mkdir -p "$WEBRTC_FRAMEWORK_PATH/Modules"
  cat > "$MODULE_MAP_PATH" << "EOF"
framework module LiveKitWebRTC {
  umbrella header "WebRTC.h"
  
  export *
  module * { export * }
}
EOF
  echo "Created LiveKitWebRTC.modulemap in WebRTC framework"
fi',
    :output_files => ['$(PODS_ROOT)/WebRTC-SDK/WebRTC.xcframework/ios-arm64/WebRTC.framework/Modules/LiveKitWebRTC.modulemap']
  }
end
