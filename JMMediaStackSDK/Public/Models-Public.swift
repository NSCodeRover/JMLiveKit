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

public struct JMNetworkStatistics{
    public var networkQuality: Int = 0
    public var remotePacketLoss: Int = 0
    public var localPacketLoss: Int = 0
    public var jitter: Int = 0
}

public enum JMUserLeaveReason{
    case userAction
    case lowNetwork
}

//ERROR
public struct JMMediaError{
    public var type: JMMediaErrorType
    public var description: String
}
public enum JMMediaErrorType: String{
    case loginFailed
    case serverDown
    
    case audioDeviceFailed
    case videoDeviceFailed
}
