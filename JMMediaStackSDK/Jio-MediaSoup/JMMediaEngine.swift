//
//  JMManager.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 30/06/23.
//

import Foundation
import AVFoundation
import WebRTC

import SwiftyJSON

import SwiftyBeaver
let LOG = SwiftyBeaver.self

public class JMMediaEngine : NSObject{
    
    static public let shared = JMMediaEngine()
    private override init() {
        super.init()
        JMLogManager.shared.setupLogger()
    }
    
    public var delegateBackToClient:JMMediaEngineDelegate?
    private let vm_manager = JMManagerViewModel()
    
    private var isMicEnabled:Bool = false
    private var isVideoEnabled:Bool = false
}

//MARK: Communicating back to Client (send data and event to client app)
extension JMMediaEngine: delegateManager{
    
    //Join
    func sendClientJoinSocketSuccess(selfId: String) {
        delegateBackToClient?.onJoinSuccess(id: selfId)
        setupDeviceManager()
    }
    
    func sendClientError(error: JMMediaError){
        delegateBackToClient?.onError(error: error)
    }
    
    func sendClientUserJoined(user: JMUserInfo) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onUserJoined(user: user)
        }
    }
    
    func sendClientUserLeft(id: String, reason: String) {
        delegateBackToClient?.onUserLeft(id: id, reason: reason)
    }
    
    //Media States
    func sendClientUserPublished(id: String, type: JMMediaType) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onUserPublished(id: id, type: type)
        }
    }
    
    func sendClientUserUnPublished(id: String, type: JMMediaType) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onUserUnPublished(id: id, type: type)
        }
    }
    
    //Messaging
    func sendClientBroadcastMessage(msg: [String: Any]) {
        delegateBackToClient?.onBroadcastMessage(msg: msg)
    }
    
    func sendClientBroadcastMessageToPeer(msg: [String: Any]) {
        delegateBackToClient?.onBroadcastMessageToPeer(msg: msg)
    }
    
    //Devices
    func sendClientAudioDeviceInUse(_ device: AVAudioDevice) {
        delegateBackToClient?.onAudioDeviceChanged(device.format())
    }

    func sendClientVideoDeviceInUse(_ device: AVVideoDevice) {
        delegateBackToClient?.onVideoDeviceChanged(device.format())
    }
    
    func sendClientTopSpeakers(listActiveParticipant: [JMActiveParticipant]) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onTopSpeakers(listActiveParticipant: listActiveParticipant)
        }
    }
    
    //Network
    func sendClientConnectionStateChanged(state: JMSocketConnectionState) {
        delegateBackToClient?.onConnectionStateChanged(state: state)
    }
        
    func sendClientNetworkQuality(stats: JMNetworkStatistics) {
        delegateBackToClient?.onNetworkQuality(stats: stats)
    }
    
    //End
    func sendClientEndClientCall(){
        delegateBackToClient?.onChannelLeft()
    }
}

extension JMMediaEngine: JMMediaEngineAbstract {
    public func create(withAppId appID: String, delegate: JMMediaEngineDelegate?) -> JMMediaEngine{
        LOG.debug("\(#function) - \(appID)")
        delegateBackToClient = delegate
        vm_manager.delegateBackToManager = self
        return JMMediaEngine.shared
    }
    
    public func join(meetingId: String, meetingPin: String, userName: String, meetingUrl: String){
        LOG.debug("\(#function) - \(meetingId)|\(meetingPin)|\(userName)|\(meetingUrl)")
        vm_manager.selfDisplayName = userName
        vm_manager.qJMMediaBGQueue.async {
            JMJoinViewApiHandler.validateJoiningDetails(meetingId: meetingId, meetingPin: meetingPin, userName: userName, meetingUrl: meetingUrl) { (result) in
                switch result{
                case .success(let model):
                    self.vm_manager.connect(socketUrl: model.mediaServer.publicBaseUrl, roomId: model.jiomeetId, jwtToken: model.jwtToken)
                case .failure(let error):
                    self.sendClientError(error: error)
                }
            }
        }
    }
    
    public func leave() {
        vm_manager.isCallEnded = true
        
        vm_manager.selfPeerLeave()
        sendClientEndClientCall()
    }
}

//MARK: AUDIO PUBLIC ACCESS
extension JMMediaEngine{
    public func getAudioDevices() -> [JMAudioDevice] {
        let jmAudioDevices = convertToJMAudioDevice(JMAudioDeviceManager.shared.getAllDevices())
        return jmAudioDevices
    }
    
    public func setAudioDevice(_ jmDevice: JMAudioDevice) {
        if let avDevice = jmDevice.device{
            JMAudioDeviceManager.shared.setAudioDevice(avDevice)
        }
        else{
            LOG.error("AVAudioDevice: failed to get device for object")
        }
    }
    
    public func setLocalAudioEnabled(_ isEnabled: Bool, _ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil){
        handleAudio(isEnabled, resultCompletion)
    }
    
    public func getVideoDevices() -> [JMVideoDevice] {
        let jmAudioDevices = convertToJMVideoDevice(JMVideoDeviceManager.shared.getAllDevices())
        return jmAudioDevices
    }
    
    public func setVideoDevice(_ jmDevice: JMVideoDevice) {
        if let avDevice = jmDevice.device{
            JMVideoDeviceManager.shared.setVideoDevice(avDevice)
            vm_manager.switchCamera()
        }
        else{
            LOG.error("AVAudioDevice: failed to get device for object")
        }
    }
    
    public func setLocalVideoEnabled(_ isEnabled: Bool, _ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil){
        handleVideo(isEnabled, resultCompletion)
    }
    
    public func subscribeFeed(_ isSubscribe: Bool, remoteId: String, mediaType: JMMediaType) {
        vm_manager.subscribeFeed(isSubscribe, remoteId: remoteId, mediaType: mediaType)
    }
    
    public func enableAudioOnlyMode(_ flag: Bool, userList: [String] = []) {
        vm_manager.enableAudioOnlyMode(flag, userList: userList)
    }
}

//MARK: UI for local and remote view
extension JMMediaEngine{
    public func setupLocalVideo(_ view: UIView) {
        vm_manager.addLocalRenderView(view)
    }
    public func setupRemoteVideo(_ view: UIView, remoteId: String) {
        vm_manager.addRemoteRenderView(view,remoteId: remoteId)
    }
    
    //ScreenShare
    public func setupShareVideo(_ view: UIView, remoteId: String) {
        vm_manager.addRemoteScreenShareRenderView(view,remoteId: remoteId)
    }
    public func startScreenShare() {
        vm_manager.updateStartScreenShare()
    }
    public func stopScreenShare(error: String = "") {
        vm_manager.updateStopScreenShare(error: error)
    }
}

//MARK: Broadcast Message
extension JMMediaEngine{
    public func sendPublicMessage(_ message: JMRTMMessage,reactionsType:JMReactions = .None) {
        vm_manager.sendJMBroadcastPublicMessage(message: message, reactionsType: reactionsType)
    }
    public func sendPrivateMessage(_ message: JMRTMMessage, targetParticipantId: String) {
        vm_manager.sendJMBroadcastPrivateMessage(message: message, targetParticipantId: targetParticipantId)
    }
}

//MARK: INTERNAL LAYER

//MARK: AudioDeviceManager
extension JMMediaEngine{
    internal func setupDeviceManager(){
        JMAudioDeviceManager.shared.delegateToManager = self
        JMVideoDeviceManager.shared.delegateToManager = self
        
        JMAudioDeviceManager.shared.setupSession()
        JMVideoDeviceManager.shared.setupSession()
    }
    
    //MARK: Conversion from AVAudioDevice to JMAudioDevice
    func convertToJMAudioDevice(_ device: [AVAudioDevice]) -> [JMAudioDevice]{
        return device.map { $0.format() }
    }
    
    func convertToJMVideoDevice(_ device: [AVVideoDevice]) -> [JMVideoDevice]{
        return device.map { $0.format() }
    }
}

extension JMMediaEngine{
    private func startVideoAndAudio() {
        if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (isGranted: Bool) in
                LOG.debug("Audio- Permission granted: \(isGranted)")
            })
        }
        
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (isGranted: Bool) in
                LOG.debug("Video- Permission granted: \(isGranted)")
            })
        }
    }
    
    internal func handleBackgroundVideoEvent(){
        if isVideoEnabled{
            LOG.debug("AVVideoDevice- PARTICIPANT_BACKGROUND_ACTIVATED")
            vm_manager.sendJMBroadcastPublicMessage(message: .PARTICIPANT_BACKGROUND_ACTIVATED)
        }
    }
    
    internal func handleForegroundVideoEvent(){
        if isVideoEnabled{
            LOG.debug("AVVideoDevice- PARTICIPANT_BACKGROUND_INACTIVATED")
            vm_manager.sendJMBroadcastPublicMessage(message: .PARTICIPANT_BACKGROUND_INACTIVATED)
        }
    }
    
    private func handleVideo(_ enable: Bool, _ completion: ((_ isSuccess: Bool) -> ())? = nil){
        if enable{
            vm_manager.qJMMediaBGQueue.async { [weak self] in
                guard let self = self else { return }
                self.vm_manager.startVideo { isSuccess in
                    self.isVideoEnabled = isSuccess ? enable : self.isVideoEnabled
                    completion?(isSuccess)
                }
            }
        }
        else{
            vm_manager.disableVideo()
            self.isVideoEnabled = false
            completion?(true)
        }
    }
    
    private func handleAudio(_ enable: Bool, _ completion: ((_ isSuccess: Bool) -> ())? = nil){
        if enable{
            vm_manager.qJMMediaBGQueue.async { [weak self] in
                guard let self = self else { return }
                self.vm_manager.startAudio { isSuccess in
                    self.isMicEnabled = isSuccess ? enable : self.isMicEnabled
                    completion?(isSuccess)
                }
            }
        }
        else{
            vm_manager.disableMic()
            self.isMicEnabled = false
            completion?(true)
        }
    }
}
