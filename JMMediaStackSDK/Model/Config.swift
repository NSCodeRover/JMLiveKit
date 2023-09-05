//
//  Config.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 27/06/23.
//

import Foundation

struct JioMediaId {
    static let cameraStreamId = "stream-camera"
    static let screenShareStreamId = "stream-screen"
    static let audioTrackId = "track-audio"
    static let videoTrackId = "track-video"
    static let screenShareTrackId = "trackscreen"
}

struct JioMediaAppData {
    static let videoAppData = ["mediaTag":"video"].toString()
    static let audioAppData = ["mediaTag":"audio"].toString()
    static let screenShareAppData = ["mediaTag":"share"].toString()
}

public enum JMMediaType: String {
    case audio
    case video
    case shareScreen
}

var JioMediaStackDefaultCameraCaptureResolution: (width:Int32,height:Int32,fps:Int32) = (width:1280,height:720,fps:15)
let JioMediaStackDefaultScreenShareCaptureResolution: (width:Int32,height:Int32,fps:Int32) = (width:1920,height:1080,fps:5)

enum JioMediaStackAudioCodec: String{
    case opusStereo
    case opusDtx
}

enum JioMediaStackVideoMaxBitrate {
    case high
    case medium(isHD: Bool)
    case low

    var value: NSNumber {
        switch self {
        case .high:
            return 700000
        case .medium(let isHD):
            return isHD ? 200000 : 400000
        case .low:
            return 100000
        }
    }
}

enum JioMediaStackVideoFPS: NSNumber{
    case high = 30
    case medium = 15
    case low = 10
}

enum JioMediaStackBitratePriority: Double{
    case high = 4.0
    case medium = 2.0
    case low = 1.0
}

enum JioMediaStackScaleDownResolution: NSNumber{
    case high = 1.0
    case medium = 2.0
    case low = 4.0
}
