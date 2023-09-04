//
//  JMManager-Public.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 03/07/23.
//

import Foundation

//Note: These callback will be received by SDK to Client
public protocol JMMediaEngineDelegate {
    func onJoinSuccess(id: String)
    func onError(error: JMMediaError)
    
    func onUserJoined(user: JMUserInfo)
    func onUserLeft(id: String, reason: JMUserLeaveReason)
    
    func onUserPublished(id: String, type: JMMediaType)
    func onUserUnPublished(id: String, type: JMMediaType)
    
    func onBroadcastMessage(msg: [String: Any])
    func onBroadcastMessageToPeer(msg: [String: Any])
    
    func onAudioDeviceChanged(_ device: JMAudioDevice)
    func onVideoDeviceChanged(_ device: JMVideoDevice)
    func onTopSpeakers(listActiveParticipant: [JMActiveParticipant])
    
    func onConnectionStateChanged(state: JMSocketConnectionState)
    func onNetworkQuality(stats: JMNetworkStatistics)
    
    func onChannelLeft()
}

//Note: Optional callbacks - All methods mentioned below will become optional.
extension JMMediaEngineDelegate{
    func onBroadcastMessage(msg: [String: Any]){}
    func onBroadcastMessageToPeer(msg: [String: Any]){}
    
    func onAudioDeviceChanged(_ device: JMAudioDevice){}
    func onVideoDeviceChanged(_ device: JMVideoDevice){}
    
    func onTopSpeakers(listActiveParticipant: [JMActiveParticipant]){}
    
    func onConnectionStateChanged(state: JMSocketConnectionState){}
    func onNetworkQuality(stats: JMNetworkStatistics){}
    
    func setRemoteFeed(for remoteId: String, preferredQuality: JMMediaQuality){}
}

//Note: These SDK functions are available for Client to call.
protocol JMMediaEngineAbstract{
    func create(withAppId appID: String, mediaOptions: JMMediaOptions, delegate: JMMediaEngineDelegate?) -> JMMediaEngine
    func join(meetingId: String, meetingPin: String, userName: String, meetingUrl: String)
    func rejoin()
    
    func getAudioDevices() -> [JMAudioDevice]
    func setAudioDevice(_ device: JMAudioDevice)
    func getVideoDevices() -> [JMVideoDevice]
    func setVideoDevice(_ device: JMVideoDevice)
    
    func setupLocalVideo(_ view: UIView)
    func setupRemoteVideo(_ view: UIView, remoteId: String)
    
    func setLocalAudioEnabled(_ isEnabled: Bool, _ resultCompletion: ((_ isSuccess: Bool) -> ())?)
    func setLocalVideoEnabled(_ isEnabled: Bool, _ resultCompletion: ((_ isSuccess: Bool) -> ())?)
    
    func subscribeFeed(_ isSubscribe: Bool, remoteId: String, mediaType: JMMediaType)
    func setRemoteFeed(for remoteId: String, preferredQuality: JMMediaQuality)
    
    func enableAudioOnlyMode(_ flag: Bool, userList: [String])
    
    //Screenshare
    func setupShareVideo(_ view: UIView, remoteId: String)
    func startScreenShare()
    func stopScreenShare(error: String)
    
    func sendPublicMessage(_ message: String,reactionsType:JMReactions)
    func sendPrivateMessage(_ message: String, targetParticipantId: String)
    
    func enableLog(_ isEnable: Bool,withPath path: String) -> String
}
