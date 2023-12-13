//
//  MeetingRoomViewModel.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 07/02/23.
//

import Foundation
import JMMediaStackSDK
import UIKit

class MeetingRoomViewModel {
    private var client:JMMediaEngine!
    
    var selectedDevice: ((JMAudioDevice) -> ())?
    var devices: (([JMAudioDevice]) -> ())?
    var videoDevices: (([JMVideoDevice]) -> ())?
    var pushToMeetingRoom: ((Bool,String) -> Void)?
    var joinChannelLoader: (() -> ())?
    var onErrorShowToast: ((JMMediaError) -> Void)?
    var onShowToast: (() -> Void)?
    
    var isMicEnabled: Bool = false
    var isCameraEnabled: Bool = false
    var isAudioOnly: Bool = false
    var displayName: String = ""
    var meetingPin = ""
    var meetingId = ""
    var isRejoin: Bool = false
    var isVirtualBackgroundEnabled: Bool = false
    enum MeetingRoomEvent {
        case join(roomId: String, pin: String, name: String, isHd: Bool)
        case startMeeting
        case endCall
        
        case audio
        case video
        case virtualBackground(_ enabled: Bool)
        
        case audioDevice
        case videoDevice
        
        case setDevice(device: JMAudioDevice)
        case setVideoDevice(device: JMVideoDevice)
        
        case audioOnly(_ enabled: Bool)
        
        case setupLocalView(_ view: UIView)
        case setupRemoteView(_ view: UIView, remoteId: String)
    
        case setStartScreenShare
        case setStopScreenShare(error:String = "")
        
        case retryJoin
        case setVolume(volumn: Double)
        case setNoAudio(isDisabled: Bool)
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
        case .join(roomId: let roomId, pin: let pin, name: let name, let isHD):
           
            displayName = name
            meetingPin = pin
            meetingId = roomId
            
            self.createEngine(meetingId: roomId, meetingPin: pin, userName: name, meetingUrl: AppConfiguration().baseUrl, isHd: isHD)
            
        case .startMeeting:
            client.setupLocalVideo(getLocalRenderView!())
            
        case .endCall:
            self.client.leave()
            
        case .audioOnly(let enabled):
            self.isAudioOnly = enabled
            
            if enabled{
                self.client.enableAudioOnlyMode(enabled,includeScreenShare: false)
            }
            else{
                let ids = peers.map { $0.userId }
                self.client.enableAudioOnlyMode(enabled,userList: ids,includeScreenShare: false)
            }
            
            //Screenshare subscribe/unsubscribe testing (one user only)
//            self.client.subscribeFeed(!enabled, remoteId: peers.first!.userId, mediaType: .shareScreen)
            
        case .audio:
            self.handleAudio()
        case .video:
            self.handleVideo()
            
        case .virtualBackground(let enabled):
            self.enableVB(enabled)

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
            client.startScreenShare(with: "group.com.onkar.MediaStackDev")
            
        case .setStopScreenShare(error: let error):
            client.stopScreenShare(error: error)
            
        case .retryJoin:
            self.isRejoin = true
            client.join(meetingId: meetingId, meetingPin: meetingPin, userName: displayName, meetingUrl: AppConfiguration().baseUrl)
        case .setVolume(volumn: let volumn):
            client.setRemotePeerVolume(volumn)
        case .setNoAudio(isDisabled: let isDisable):
            client.enableRemotePeerAudio(!isDisable)
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
    
    func enableVB(_ enabled: Bool){
        if #available(iOS 15.0, *){
            if enabled{
                //IMAGE
                self.client.enableVirtualBackground(enabled, withOption: .image(data: UIImage(named: "vb1")!.pngData()!))
                //BLUR
                //self.client.enableVirtualBackground(enabled, withOption: .blur(intensity: 20))
                //COLOR
                //self.client.enableVirtualBackground(enabled, withOption: .color(color: .cyan))
            }
            else{
                self.client.enableVirtualBackground(enabled)
            }
        }
    }
    
    func endMeetingClearData(){
        peers = []
        isMicEnabled = false
        isCameraEnabled = false
        client = nil
    }
}


//MARK: - JMMediaEngine
extension MeetingRoomViewModel {
     func getJoin(_ meetingId: String, _ meetingPin: String, _ userName: String, _ meetingUrl: String) {
        client.join(meetingId: meetingId, meetingPin: meetingPin, userName: userName, meetingUrl: meetingUrl)
    }
    
    func createEngine(meetingId: String,meetingPin: String,userName: String,meetingUrl: String,isHd: Bool){
        var jmMediaOptions = JMMediaOptions()
        jmMediaOptions.isHDEnabled = isHd
        jmMediaOptions.isMicOn = isMicEnabled
        jmMediaOptions.isCameraOn = isCameraEnabled
        
        client = JMMediaEngine.shared.create(withAppId: "", mediaOptions: jmMediaOptions, delegate: self)
        enableLogs()
        getJoin(meetingId, meetingPin, userName, meetingUrl)
    }
    
    func enableLogs(){
        JMLoggerOption.shared.setLogFileName(fileName: "JMMediaStack-\(meetingId)")
        client.enableLog(true,severity: .error)
    }
    
    func onRejoined() {
        self.isRejoin = false
        self.peers.removeAll()
        isCameraEnabled = false
        isMicEnabled = false
        if let closure = self.handleVideoState {
            closure(false)
        }
        if let closure = self.handleVideoState {
            closure(false)
        }
        self.handleEvent(event: .startMeeting)
    }
}

//MARK: handle client delegate helper
extension MeetingRoomViewModel{
    func mediaState(isEnabled: Bool,id: String,type: JMMediaType){
        print("Subscribe- Screenshare- CLIENT- \(isEnabled)|\(id)|\(type)")
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
                
                if isEnabled{
                    startRemoteScreenShare(id)
                }                
            }
            
            self.peers[index] = updatedPeer
        }
    }
    
    func startRemoteScreenShare(_ id: String){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.client.setupShareVideo(self.getLocalScreenShareView!(), remoteId: id)
            self.client.subscribeFeed(true, remoteId: id, mediaType: .shareScreen)
        }
    }
}

extension MeetingRoomViewModel: JMMediaEngineDelegate {
    
    func onUserJoined(user: JMUserInfo) {
        self.peers.append(user)
        if user.hasScreenShare {
            startRemoteScreenShare(user.userId)
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
        if isRejoin {
            onRejoined()
            return
        }
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
    
    func onRemoteNetworkQuality(id: String, quality: JMNetworkQuality, mediaType: JMMediaType) {
    }
    
    func onAudioDeviceChanged(_ device: JMAudioDevice) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            self.selectedDevice?(device)
        })
    }
    
    func onVideoDeviceChanged(_ device: JMVideoDevice) {
    }
    
    func onLogMessage(message: String) {
        JMLoggerOption.shared.log(message)
        print(message)
    }
    
    func onUserSpeakingOnMute() {
        self.onShowToast?()
    }
    
    func onLocalMediaStateChange(type: JMMediaType, reason: JMMediaReason) {
    }
}
