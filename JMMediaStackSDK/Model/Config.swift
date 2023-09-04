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

let JioMediaStackDefaultCameraCaptureResolution: (Int32,Int32,Int32) = (1280,720,15)
let JioMediaStackDefaultScreenShareCaptureResolution: (Int32,Int32,Int32) = (1920,1080,5)

enum JioMediaStackAudioCodec: String{
    case opusStereo
    case opusDtx
}

enum JioMediaStackVideoMaxBitrate: NSNumber{
    case high = 700000
    case medium = 400000
    case low = 100000
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
