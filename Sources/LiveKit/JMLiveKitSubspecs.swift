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

import Foundation

/// JMLiveKit Subspecs Feature Availability
/// This file provides conditional compilation and feature availability based on which subspec is being used.
public enum JMLiveKitFeatures {
    
    // MARK: - Feature Availability
    
    /// Whether camera functionality is available in the current subspec
    public static var isCameraAvailable: Bool {
        #if JMLIVEKIT_CAMERA_AVAILABLE
        return true
        #else
        return false
        #endif
    }
    
    /// Whether UI components are available in the current subspec
    public static var isUIAvailable: Bool {
        #if JMLIVEKIT_UI_AVAILABLE
        return true
        #else
        return false
        #endif
    }
    
    /// Whether WebRTC functionality is available in the current subspec
    public static var isWebRTCAvailable: Bool {
        #if JMLIVEKIT_WEBRTC_AVAILABLE
        return true
        #else
        return false
        #endif
    }
    
    /// Whether screen sharing functionality is available in the current subspec
    public static var isScreenShareAvailable: Bool {
        #if JMLIVEKIT_SCREENSHARE_AVAILABLE
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Subspec Detection
    
    /// The current subspec being used
    public static var currentSubspec: String {
        #if JMLIVEKIT_CORE
        return "Core"
        #elseif JMLIVEKIT_SCREENSHARE
        return "ScreenShare"
        #elseif JMLIVEKIT_WEBRTC
        return "WebRTC"
        #else
        return "Unknown"
        #endif
    }
    
    /// Whether the current subspec is extension-safe
    public static var isExtensionSafe: Bool {
        #if JMLIVEKIT_SCREENSHARE
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Runtime Validation
    
    /// Validates that the required features are available for the current use case
    /// - Parameter requiredFeatures: Array of required features
    /// - Returns: True if all required features are available
    public static func validateFeatures(_ requiredFeatures: [Feature]) -> Bool {
        return requiredFeatures.allSatisfy { feature in
            switch feature {
            case .camera:
                return isCameraAvailable
            case .ui:
                return isUIAvailable
            case .webrtc:
                return isWebRTCAvailable
            case .screenShare:
                return isScreenShareAvailable
            }
        }
    }
    
    /// Throws an error if required features are not available
    /// - Parameter requiredFeatures: Array of required features
    /// - Throws: JMLiveKitError.featureNotAvailable if any required feature is missing
    public static func requireFeatures(_ requiredFeatures: [Feature]) throws {
        let missingFeatures = requiredFeatures.filter { feature in
            !validateFeatures([feature])
        }
        
        if !missingFeatures.isEmpty {
            throw JMLiveKitError.featureNotAvailable(
                features: missingFeatures,
                currentSubspec: currentSubspec
            )
        }
    }
}

// MARK: - Feature Enum

/// Available features in JMLiveKit
public enum Feature {
    case camera
    case ui
    case webrtc
    case screenShare
}

// MARK: - Error Types

/// Errors specific to JMLiveKit subspecs
public enum JMLiveKitError: LocalizedError {
    case featureNotAvailable(features: [Feature], currentSubspec: String)
    
    public var errorDescription: String? {
        switch self {
        case .featureNotAvailable(let features, let subspec):
            let featureNames = features.map { feature in
                switch feature {
                case .camera: return "Camera"
                case .ui: return "UI Components"
                case .webrtc: return "WebRTC"
                case .screenShare: return "Screen Share"
                }
            }.joined(separator: ", ")
            
            return "Features not available in current subspec (\(subspec)): \(featureNames). Please use the appropriate subspec for your use case."
        }
    }
}

// MARK: - Conditional Compilation Helpers

/// Conditional compilation helper for camera-related code
public func withCameraSupport<T>(_ operation: () throws -> T) rethrows -> T? {
    guard JMLiveKitFeatures.isCameraAvailable else {
        return nil
    }
    return try operation()
}

/// Conditional compilation helper for UI-related code
public func withUISupport<T>(_ operation: () throws -> T) rethrows -> T? {
    guard JMLiveKitFeatures.isUIAvailable else {
        return nil
    }
    return try operation()
}

/// Conditional compilation helper for WebRTC-related code
public func withWebRTCSupport<T>(_ operation: () throws -> T) rethrows -> T? {
    guard JMLiveKitFeatures.isWebRTCAvailable else {
        return nil
    }
    return try operation()
}

/// Conditional compilation helper for screen share-related code
public func withScreenShareSupport<T>(_ operation: () throws -> T) rethrows -> T? {
    guard JMLiveKitFeatures.isScreenShareAvailable else {
        return nil
    }
    return try operation()
} 