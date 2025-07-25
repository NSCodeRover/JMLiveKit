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

public enum VideoRotation: Int, Sendable, Codable {
    case _0 = 0
    case _90 = 90
    case _180 = 180
    case _270 = 270
}

extension LKRTCVideoRotation {
    func toLKType() -> VideoRotation {
        VideoRotation(rawValue: rawValue)!
    }
}

extension VideoRotation {
    func toRTCType() -> LKRTCVideoRotation {
        LKRTCVideoRotation(rawValue: rawValue)!
    }
}
