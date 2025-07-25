/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef JMLiveKitSubspecs_h
#define JMLiveKitSubspecs_h

// MARK: - Subspec Compilation Flags
// These flags are automatically set by CocoaPods based on which subspec is being used

#ifdef JMLIVEKIT_CORE
    // Core subspec - includes camera, UI, and full functionality
    #define JMLIVEKIT_SUPPORTS_CAMERA 1
    #define JMLIVEKIT_SUPPORTS_UI 1
    #define JMLIVEKIT_SUPPORTS_WEBRTC 1
    #define JMLIVEKIT_SUPPORTS_SCREENSHARE 1
#endif

#ifdef JMLIVEKIT_SCREENSHARE
    // ScreenShare subspec - extension-safe APIs only
    #define JMLIVEKIT_SUPPORTS_CAMERA 0
    #define JMLIVEKIT_SUPPORTS_UI 0
    #define JMLIVEKIT_SUPPORTS_WEBRTC 0
    #define JMLIVEKIT_SUPPORTS_SCREENSHARE 1
#endif

#ifdef JMLIVEKIT_WEBRTC
    // WebRTC subspec - Core + additional WebRTC features
    #define JMLIVEKIT_SUPPORTS_CAMERA 1
    #define JMLIVEKIT_SUPPORTS_UI 1
    #define JMLIVEKIT_SUPPORTS_WEBRTC 1
    #define JMLIVEKIT_SUPPORTS_SCREENSHARE 1
#endif

// MARK: - Default Values (if no subspec flag is set)
#ifndef JMLIVEKIT_SUPPORTS_CAMERA
    #define JMLIVEKIT_SUPPORTS_CAMERA 1
#endif

#ifndef JMLIVEKIT_SUPPORTS_UI
    #define JMLIVEKIT_SUPPORTS_UI 1
#endif

#ifndef JMLIVEKIT_SUPPORTS_WEBRTC
    #define JMLIVEKIT_SUPPORTS_WEBRTC 1
#endif

#ifndef JMLIVEKIT_SUPPORTS_SCREENSHARE
    #define JMLIVEKIT_SUPPORTS_SCREENSHARE 1
#endif

// MARK: - Feature Macros
// These macros can be used in Swift code to conditionally compile features

#if JMLIVEKIT_SUPPORTS_CAMERA
    #define JMLIVEKIT_CAMERA_AVAILABLE 1
#else
    #define JMLIVEKIT_CAMERA_AVAILABLE 0
#endif

#if JMLIVEKIT_SUPPORTS_UI
    #define JMLIVEKIT_UI_AVAILABLE 1
#else
    #define JMLIVEKIT_UI_AVAILABLE 0
#endif

#if JMLIVEKIT_SUPPORTS_WEBRTC
    #define JMLIVEKIT_WEBRTC_AVAILABLE 1
#else
    #define JMLIVEKIT_WEBRTC_AVAILABLE 0
#endif

#if JMLIVEKIT_SUPPORTS_SCREENSHARE
    #define JMLIVEKIT_SCREENSHARE_AVAILABLE 1
#else
    #define JMLIVEKIT_SCREENSHARE_AVAILABLE 0
#endif

#endif /* JMLiveKitSubspecs_h */ 