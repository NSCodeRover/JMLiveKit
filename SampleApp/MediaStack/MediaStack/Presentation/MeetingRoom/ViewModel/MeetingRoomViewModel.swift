//
//  MeetingRoomViewModel.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 07/02/23.
//

import Foundation
import WebRTC

import JMMediaStackSDK

class MeetingRoomViewModel {
    private var client:JMMediaEngine!
    
    var selectedDevice: ((JMAudioDevice) -> ())?
    var devices: (([JMAudioDevice]) -> ())?
    var videoDevices: (([JMVideoDevice]) -> ())?
    var pushToMeetingRoom: ((Bool,String) -> Void)?
    var joinChannelLoader: (() -> ())?
    var onErrorShowToast: ((JMMediaError) -> Void)?
    
    var isMicEnabled: Bool = false
    var isCameraEnabled: Bool = false
    var isAudioOnly: Bool = false
    var displayName: String = ""

    enum MeetingRoomEvent {
        case join(roomId: String, pin: String, name: String)
        case startMeeting
        case endCall
        
        case audio
        case video
        
        case audioDevice
        case videoDevice
        
        case setDevice(device: JMAudioDevice)
        case setVideoDevice(device: JMVideoDevice)
        
        case audioOnly(_ enabled: Bool)
        
        case setupLocalView(_ view: UIView)
        case setupRemoteView(_ view: UIView, remoteId: String)
    
        case setStartScreenShare
        case setStopScreenShare(error:String = "")
    }
    
    var getLocalRenderView: (() -> UIView)?
    var getLocalScreenShareView: (() -> UIView)?

    var reloadData: (() -> Void)?
    var popScreen: (() -> Void)?
    var handleAudioState: ((_ state: Bool) -> Void)?
    var handleVideoState: ((_ state: Bool) -> Void)?
    var handleConnectionState: ((_ state: JMSocketConnectionState) -> Void)?
    
    private var peers: [JMUserInfo] = [] {
        didSet {
            if let closure = self.reloadData {
                closure()
            }
        }
    }
}

// MARK: - Public Methods
extension MeetingRoomViewModel {
    func getPeers() -> [JMUserInfo] {
        return self.peers
    }
    
    func handleEvent(event: MeetingRoomEvent) {
        switch event {
        case .join(roomId: let roomId, pin: let pin, name: let name):
            displayName = name
            self.createEngine(meetingId: roomId, meetingPin: pin, userName: name, meetingUrl: AppConfiguration().baseUrl)
            
        case .startMeeting:
            client.setupLocalVideo(getLocalRenderView!())
            
        case .endCall:
            self.client.leave()
            
        case .audioOnly(let enabled):
            self.isAudioOnly = enabled
            self.client.enableAudioOnlyMode(enabled)
            
        case .audio:
            self.handleAudio()
        case .video:
            self.handleVideo()
        case .setDevice(let device):
            self.setAudioDevice(device)
        case .setVideoDevice(let device):
            self.setVideoDevice(device)
            
        case .audioDevice:
            self.getAudioDevices()
        case .videoDevice:
            self.getVideoDevices()
            
        case .setupLocalView(let view):
            client.setupLocalVideo(view)
            
        case .setupRemoteView(let view,let remoteId):
            client.setupRemoteVideo(view, remoteId: remoteId)
            
        case .setStartScreenShare:
            client.startScreenShare()
            client.sendPublicMessage(JMRTMMessage.PARTRICIPANT_START_SHARE.rawValue)
            
        case .setStopScreenShare(error: let error):
            client.stopScreenShare(error: error)
            client.sendPublicMessage(JMRTMMessage.PARTRICIPANT_STOP_SHARE.rawValue)
        }
    }
}

// MARK: - AudioDevice
extension MeetingRoomViewModel {
    func getAudioDevices(){
        let audioDevices = client.getAudioDevices()
        if !audioDevices.isEmpty{
            devices?(audioDevices)
        }
    }
    
    func setAudioDevice(_ device: JMAudioDevice){
        client.setAudioDevice(device)
    }
    
    func getVideoDevices(){
        let devices = client.getVideoDevices()
        if !devices.isEmpty{
            videoDevices?(devices)
        }
    }
    
    func setVideoDevice(_ device: JMVideoDevice){
        client.setVideoDevice(device)
    }
    
    func setRemoteView(_ remoteId: String, view: UIView){
        client.setupRemoteVideo(view, remoteId: remoteId)
    }
    
    func setRemoteScreenShareView(_ remoteId: String, view: UIView){
        client.setupShareVideo(view, remoteId: remoteId)
    }
    
    func handleAudio(){
        client.setLocalAudioEnabled(!isMicEnabled) { (isSuccess) in
            if isSuccess{
                self.isMicEnabled = !self.isMicEnabled
                if let closure = self.handleAudioState {
                    closure(self.isMicEnabled)
                }
            }
        }
    }
    
    func handleVideo(){
        client.setLocalVideoEnabled(!isCameraEnabled) { (isSuccess) in
            if isSuccess{
                self.isCameraEnabled = !self.isCameraEnabled
                if let closure = self.handleVideoState {
                    closure(self.isCameraEnabled)
                }
            }
        }
    }
    
    func endMeetingClearData(){
        peers = []
        isMicEnabled = false
        isCameraEnabled = false
    }
}


//MARK: - JMMediaEngine
extension MeetingRoomViewModel {
    func createEngine(meetingId: String,meetingPin: String,userName: String,meetingUrl: String){
        client = JMMediaEngine.shared.create(withAppId: "", delegate: self)
        enableLogs()
        client.join(meetingId: meetingId, meetingPin: meetingPin, userName: userName, meetingUrl: meetingUrl)
    }
    
    func enableLogs(){
        let logPath = client.enableLog(true)
        print("LOG- client \(logPath)")
    }
}

//MARK: handle client delegate helper
extension MeetingRoomViewModel{
    func mediaState(isEnabled: Bool,id: String,type: JMMediaType){
        if let index = peers.firstIndex(where: { $0.userId == id }){
            var updatedPeer = self.peers[index]
            
            switch type{
            case .audio:
                updatedPeer.hasAudio = isEnabled
            case .video:
                updatedPeer.hasVideo = isEnabled
            case .shareScreen:
                updatedPeer.hasScreenShare = isEnabled
                self.peers[index] = updatedPeer
                
                DispatchQueue.main.asyncAfter(deadline: .now()) { [self] in
                    setRemoteScreenShareView(updatedPeer.userId, view: getLocalScreenShareView!())
                }
            }
            
            self.peers[index] = updatedPeer
        }
    }
}

extension MeetingRoomViewModel: JMMediaEngineDelegate {
    
    func onUserJoined(user: JMUserInfo) {
        self.peers.append(user)
        
        if user.hasScreenShare {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.client.setupShareVideo(self.getLocalScreenShareView!(), remoteId: user.userId)
                self.client.subscribeFeed(true, remoteId: user.userId, mediaType: .shareScreen)
            }
        }
        
        client.subscribeFeed(true, remoteId: user.userId, mediaType: .video)
    }
    
    func onUserLeft(id: String, reason: JMUserLeaveReason) {
        if let index = peers.firstIndex(where: { $0.userId == id }){
            self.peers.remove(at: index)
        }
    }
    
    func onUserPublished(id: String, type: JMMediaType) {
        mediaState(isEnabled: true, id: id, type: type)
    }
    
    func onUserUnPublished(id: String, type: JMMediaType) {
        mediaState(isEnabled: false, id: id, type: type)
    }
    
    func onBroadcastMessage(msg: [String : Any]) {
    }
    
    func onBroadcastMessageToPeer(msg: [String : Any]) {
    }
    
    func onConnectionStateChanged(state: JMSocketConnectionState) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            self.handleConnectionState?(state)
        })
    }
    
    func onTopSpeakers(listActiveParticipant: [JMActiveParticipant]) {
    }
    
    func onJoinSuccess(id: String) {
        self.pushToMeetingRoom?(true,id)
    }
    
    func onError(error: JMMediaError) {
        
        switch error.type{
        case .serverDown:
            self.pushToMeetingRoom?(false,error.description)
        case .loginFailed:
            self.pushToMeetingRoom?(false,error.description)
        case .cameraNotAvailable:
            self.onErrorShowToast?(error)
        default:
            break
        }
    }
    
    func onChannelLeft() {
        endMeetingClearData()
        if let closure = self.popScreen {
            closure()
        }
    }
    
    func onNetworkQuality(stats: JMNetworkStatistics) {
        //print("NetworkQuality- \(stats.networkQuality)|\(stats.localPacketPercentLoss)|\(stats.remotePacketPercentLoss)")
    }
    
    func onAudioDeviceChanged(_ device: JMAudioDevice) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            self.selectedDevice?(device)
        })
    }
    
    func onVideoDeviceChanged(_ device: JMVideoDevice) {
    }
}
