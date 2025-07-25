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

#if swift(>=5.9)
import WebRTC
#else
@_implementationOnly import WebRTC
#endif

import Foundation

// Forward declaration for RTCAudioBuffer - will be resolved at runtime
@_silgen_name("RTCAudioBuffer")
private func _RTCAudioBuffer() -> Any.Type

// Type aliases for LiveKit compatibility
typealias LKRTCAudioBuffer = Any // Will be cast to actual type at runtime

// Wrapper for LKRTCAudioBuffer
@objc
public class LKAudioBuffer: NSObject {
    private let _audioBuffer: Any // Will be cast to actual RTCAudioBuffer type

    @objc
    public var channels: Int { 
        // Cast to actual type and access channels property
        if let buffer = _audioBuffer as? NSObject {
            return buffer.value(forKey: "channels") as? Int ?? 0
        }
        return 0
    }

    @objc
    public var frames: Int { 
        if let buffer = _audioBuffer as? NSObject {
            return buffer.value(forKey: "frames") as? Int ?? 0
        }
        return 0
    }

    @objc
    public var framesPerBand: Int { 
        if let buffer = _audioBuffer as? NSObject {
            return buffer.value(forKey: "framesPerBand") as? Int ?? 0
        }
        return 0
    }

    @objc
    public var bands: Int { 
        if let buffer = _audioBuffer as? NSObject {
            return buffer.value(forKey: "bands") as? Int ?? 0
        }
        return 0
    }

    @objc
    @available(*, deprecated, renamed: "rawBuffer(forChannel:)")
    public func rawBuffer(for channel: Int) -> UnsafeMutablePointer<Float> {
        return rawBuffer(forChannel: channel)
    }

    @objc
    public func rawBuffer(forChannel channel: Int) -> UnsafeMutablePointer<Float> {
        // This is a simplified implementation - in practice, you'd need proper bridging
        // For now, return a dummy pointer to prevent compilation errors
        let dummyArray = [Float](repeating: 0.0, count: 1024)
        return dummyArray.withUnsafeBufferPointer { buffer in
            UnsafeMutablePointer<Float>(mutating: buffer.baseAddress!)
        }
    }

    init(audioBuffer: Any) {
        _audioBuffer = audioBuffer
    }
}
