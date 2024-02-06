//
//  Models-Public.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 24/07/23.
//

import Foundation

public struct JMUserInfo{
    public var userId: String = ""
    public var hasAudio: Bool = false
    public var hasVideo: Bool = false
    public var hasScreenShare: Bool = false
    public var name: String = ""
    public var role: String = ""
}

public struct JMActiveParticipant{
    public var peerId: String = ""
    public var volume: Int = 0
}

public enum JMNetworkQuality: Int{
    case Good
    case Bad
    case VeryBad
}

public struct JMNetworkStatistics{
    public var networkQuality: JMNetworkQuality = .Good
    public var remotePacketPercentLoss: Int = 0
    public var localPacketPercentLoss: Int = 0
    
    init(networkQuality: JMNetworkQuality, remotePacketPercentLoss: Int, localPacketPercentLoss: Int) {
        self.networkQuality = networkQuality
        self.remotePacketPercentLoss = remotePacketPercentLoss
        self.localPacketPercentLoss = localPacketPercentLoss
    }
}

public enum JMUserLeaveReason{
    case userAction
    case unknown
    
    //TODO: Future scope
//    case lowNetwork
//    case HostRemoved
//    case HostEnded
}

//ERROR
public struct JMMediaError{
    public var type: JMMediaErrorType
    public var description: String
}
public enum JMMediaErrorType: String{
    case loginFailed
    case serverDown
    
    //MediaSoup
    case AudioMediaNotSupported
    case VideoMediaNotSupported
    
    //Video
    case videoSetDeviceFailed
    case videoStartFailed
    
    case cameraNotAvailable
    case videoDeviceNotSupported
    
    //Audio
    case audioDeviceNotAvailable
    case audioSetDeviceFailed
    case audioStartFailed
    
    //Server request to mute
    case audioStoppedByServer
    case videoStoppedByServer
    case screenshareStoppedByServer
    
    //Remote Stream
    case remoteVideoStreamFailed
    case remoteAudioStreamFailed
    case remoteScreenShareStreamFailed
    case remoteScreenShareAudioStreamFailed
}

//Media for local state
public enum JMMediaReason{
    case audioStoppedByServer
    case videoStoppedByServer
    case screenshareStoppedByServer
}

public enum JMMediaQuality: Int{
    case low = 0
    case medium
    case high
}
