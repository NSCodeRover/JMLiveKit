# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'JMMediaStackSDK' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  # Pods for JMMediaStackSDK
  pod "SwiftyJSON"
  pod "Socket.IO-Client-Swift"
  pod 'MMWormhole'
  #pod 'Mediasoup', :path => '~/Desktop/Projects/JioMeetReuableFrameworks_iOSmacOS'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'No'
    end
  end
end
