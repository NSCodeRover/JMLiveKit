# JMLiveKit Subspecs Guide

## Overview

JMLiveKit now supports multiple subspecs to properly handle different target types (main app vs app extensions) while maintaining compliance with Apple's API restrictions.

## Subspecs

### 1. Core Subspec (`JMLiveKit` or `JMLiveKit/Core`)
**Use for:** Main iOS applications
**Includes:** Full LiveKit functionality with camera, UI, and WebRTC support

```ruby
target 'MyApp' do
  # Use either of these (both work the same):
  pod 'JMLiveKit', '~> 2.6.22'           # Defaults to Core subspec
  # OR
  pod 'JMLiveKit/Core', '~> 2.6.22'      # Explicit Core subspec
end
```

**Features:**
- Camera and microphone access
- UI components and SwiftUI views
- Full WebRTC functionality
- Audio/video processing
- All LiveKit core features

### 2. ScreenShare Subspec (`JMLiveKit/ScreenShare`)
**Use for:** App extensions (Broadcast Upload Extensions, etc.)
**Includes:** Extension-safe APIs only

```ruby
target 'BroadcastExtension' do
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end
```

**Features:**
- ReplayKit integration
- Screen capture and broadcasting
- Extension-safe networking
- No camera/microphone access
- No UI components

### 3. WebRTC Subspec (`JMLiveKit/WebRTC`)
**Use for:** Advanced users who need explicit WebRTC control
**Includes:** Core + additional WebRTC features

```ruby
target 'MyApp' do
  pod 'JMLiveKit/WebRTC', '~> 2.6.22'
end
```

## Folder Structure

```
Sources/
├── LiveKit/           # Core functionality (main app)
│   ├── Audio/
│   ├── Core/
│   ├── Participant/
│   ├── Track/
│   ├── Views/
│   └── ... (all other LiveKit features)
├── ScreenShare/       # Extension-safe code
│   ├── BroadcastManager.swift
│   ├── BroadcastScreenCapturer.swift
│   ├── LKSampleHandler.swift
│   └── IPC/          # Inter-process communication
├── LKObjCHelpers/     # Objective-C helpers
└── LiveKitWebRTCForMediaSoup/  # WebRTC integration
```

## Usage Examples

### Main App Podfile
```ruby
target 'MyApp' do
  use_frameworks!
  
  # Core functionality for main app (both work the same)
  pod 'JMLiveKit', '~> 2.6.22'           # Defaults to Core subspec
  # OR
  # pod 'JMLiveKit/Core', '~> 2.6.22'    # Explicit Core subspec
  
  # Other dependencies
  pod 'MMWormhole', '~> 2.2'
end
```

### Broadcast Extension Podfile
```ruby
target 'BroadcastExtension' do
  use_frameworks!
  
  # Extension-safe APIs only
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end
```

### Complete Project Podfile
```ruby
platform :ios, '13.0'
use_frameworks!

target 'MyApp' do
  pod 'JMLiveKit', '~> 2.6.22'           # Defaults to Core subspec
  pod 'MMWormhole', '~> 2.2'
end

target 'BroadcastExtension' do
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

## API Availability

### Core APIs (Main App Only)
- `LocalVideoTrack.createCameraTrack()`
- `LocalAudioTrack.createMicrophoneTrack()`
- `VideoView` and other UI components
- Camera switching functionality
- Audio device management

### Extension-Safe APIs (Available in Both)
- `BroadcastManager`
- `BroadcastScreenCapturer`
- `LKSampleHandler`
- IPC communication
- Screen sharing functionality

## Compilation Flags

The subspecs automatically set the following compilation flags:

- **Core:** `JMLIVEKIT_CORE=1`
- **ScreenShare:** `JMLIVEKIT_SCREENSHARE=1` + `APPLICATION_EXTENSION_API_ONLY=YES`
- **WebRTC:** `JMLIVEKIT_WEBRTC=1`

## Migration Guide

### From Single Pod to Subspecs

**Before:**
```ruby
target 'MyApp' do
  pod 'JMLiveKit', '~> 2.6.21'
end

target 'BroadcastExtension' do
  # No JMLiveKit (caused camera errors)
end
```

**After:**
```ruby
target 'MyApp' do
  pod 'JMLiveKit', '~> 2.6.22'           # Defaults to Core subspec
end

target 'BroadcastExtension' do
  pod 'JMLiveKit/ScreenShare', '~> 2.6.22'
end
```

## Troubleshooting

### Common Issues

1. **Camera API errors in extensions:**
   - Ensure you're using `JMLiveKit/ScreenShare` for extensions
   - Check that `APPLICATION_EXTENSION_API_ONLY=YES` is set

2. **Missing WebRTC symbols:**
   - Use `JMLiveKit/Core` or `JMLiveKit/WebRTC` for main app
   - Ensure WebRTC-SDK dependency is included

3. **Compilation errors:**
   - Clean build folder: `Product > Clean Build Folder`
   - Delete Pods folder and reinstall: `pod deintegrate && pod install`

### Build Settings

Ensure these settings in your project:

```bash
# For main app targets
ENABLE_BITCODE = NO
IPHONEOS_DEPLOYMENT_TARGET = 13.0

# For extension targets
APPLICATION_EXTENSION_API_ONLY = YES
ENABLE_BITCODE = NO
IPHONEOS_DEPLOYMENT_TARGET = 13.0
```

## Version History

- **2.6.22:** Introduced subspecs for proper app extension support
- **2.6.21:** Previous version with single pod structure

## Support

For issues or questions about the subspec structure, please refer to:
- [CocoaPods Subspecs Documentation](https://guides.cocoapods.org/syntax/podspec.html#subspec)
- [Apple App Extension Guidelines](https://developer.apple.com/app-extensions/) 