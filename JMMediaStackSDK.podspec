Pod::Spec.new do |spec|

  spec.name         = 'JMMediaStackSDK'
  spec.version      = '1.0.0'
  spec.summary      = 'Media stack SDK which will responsible to provide video conferencing experience.'
  spec.description  = 'Media stack SDK developed on top of MediaSoup and webrtc framework will handling everything related to join, streaming, communication, etc.'
  spec.homepage     = 'https://jiomeetpro.jio.com'
  spec.license      = { :type => 'Copyright', :text => 'COPYRIGHT 2022 JIO PLATFORMS LIMITED. ALL RIGHTS RESERVED.\n' }
  spec.author = {
      "Harsh Surati" => "harsh1.surati@ril.com",
      "Onkar Dhanlobhe" => "onkar.dhanlobhe@ril.com"
  }
  spec.platform     = :ios, '12'
  spec.swift_versions = ['5']
  spec.source = {
      :git => "https://devops.jio.com/JioPlatforms/JioMeet_Pilot/_git/JMMediaSoup_iOS",
      :branch => "develop"
  }
  spec.source_files = "JMMediaStackSDK/**/*.{h,m,swift}"
  spec.vendored_frameworks =
      "JMMediaFrameworks/Mediasoup.xcframework",
      "JMMediaFrameworks/WebRTC.xcframework"
      
  spec.frameworks =
      "AVFoundation",
      "AudioToolbox",
      "CoreAudio",
      "CoreMedia",
      "CoreVideo"
      
  spec.dependency 'SwiftyJSON'
  spec.dependency 'Socket.IO-Client-Swift', '~> 16.1.0'
  spec.dependency 'MMWormhole'
  spec.dependency 'SwiftyBeaver'
end
