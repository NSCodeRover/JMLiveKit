//
//  LiveKitWebRTCForMediaSoup.swift
//  LiveKitWebRTCForMediaSoup
//
//  Created by AI Assistant for WebRTC compatibility
//

import Foundation

// Re-export LiveKitWebRTC symbols for MediaSoup compatibility
// This module provides a compatibility layer for MediaSoup to use LiveKit's WebRTC
@_exported import LiveKitWebRTC

// MARK: - MediaSoup Compatibility Layer
// 
// This module re-exports LiveKitWebRTC to provide a unified WebRTC interface
// for both MediaSoup and LiveKit backends. MediaSoup code can import this
// module and use the WebRTC types directly from LiveKitWebRTC.
//
// Usage in MediaSoup code:
// import LiveKitWebRTCForMediaSoup
// 
// Then use WebRTC types directly:
// let factory = RTCPeerConnectionFactory()
// let config = RTCConfiguration()
// etc.
// 
// All WebRTC types are available through the LiveKitWebRTC module that is
// re-exported here.

// MARK: - Documentation
//
// This compatibility layer enables:
// 1. Unified WebRTC library usage across MediaSoup and LiveKit backends
// 2. Elimination of framework conflicts between different WebRTC versions
// 3. Consistent WebRTC API surface for both backends
// 4. Simplified dependency management
//
// The LiveKitWebRTC module provides all the necessary WebRTC types and
// functionality that MediaSoup requires for WebRTC operations. 