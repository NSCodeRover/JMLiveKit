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

@objc
public enum DegradationPreference: Int, Sendable {
    /// The SDK will decide which preference is suitable or will use WebRTC's default implementation.
    case auto
    case disabled
    /// Prefer to maintain FPS rather than resolution.
    case maintainFramerate
    /// Prefer to maintain resolution rather than FPS.
    case maintainResolution
    case balanced
}

extension DegradationPreference {
    func toRTCType() -> LKRTCDegradationPreference? {
        switch self {
        case .auto: return nil
        case .disabled: return .disabled
        case .maintainFramerate: return .maintainFramerate
        case .maintainResolution: return .maintainResolution
        case .balanced: return .balanced
        }
    }
}
