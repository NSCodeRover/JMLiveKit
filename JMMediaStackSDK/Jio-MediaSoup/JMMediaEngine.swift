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
    private var vm_manager: JMManagerViewModel!
}

//MARK: Communicating back to Client (send data and event to client app)
extension JMMediaEngine: delegateManager{
    func sendRemoteNetworkQuality(id:String,quality:JMNetworkQuality,mediaType:JMMediaType) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onRemoteNetworkQuality(id: id, quality: quality, mediaType: mediaType)
        }
    }
    
    func sendRemoteVideoLayerChange(_ msg: [String : Any]) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onRemoteVideoLayerChange(msg)
        }
    }
    
    //Join
    func sendClientJoinSocketSuccess(selfId: String) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onJoinSuccess(id: selfId)
            self.setupDeviceManager()
        }
    }
    
    func sendClientError(error: JMMediaError){
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onError(error: error)
        }
    }
    
    func sendClientUserJoined(user: JMUserInfo) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onUserJoined(user: user)
        }
    }
    
    func sendClientUserLeft(id: String, reason: JMUserLeaveReason) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onUserLeft(id: id, reason: reason)
        }
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
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onBroadcastMessage(msg: msg)
        }
    }
    
    func sendClientBroadcastMessageToPeer(msg: [String: Any]) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onBroadcastMessageToPeer(msg: msg)
        }
    }
    
    //Devices
    func sendClientAudioDeviceInUse(_ device: AVAudioDevice) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onAudioDeviceChanged(device.format())
        }
    }

    func sendClientVideoDeviceInUse(_ device: AVVideoDevice) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onVideoDeviceChanged(device.format())
        }
    }
    
    func sendClientTopSpeakers(listActiveParticipant: [JMActiveParticipant]) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onTopSpeakers(listActiveParticipant: listActiveParticipant)
        }
    }
    
    //Network
    func sendClientConnectionStateChanged(state: JMSocketConnectionState) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onConnectionStateChanged(state: state)
        }
    }
        
    func sendClientNetworkQuality(stats: JMNetworkStatistics) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onNetworkQuality(stats: stats)
        }
    }
    
    //End
    func sendClientEndCall(){
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onChannelLeft()
        }
    }
}

public struct JMMediaOptions{
    public var isHDEnabled: Bool = false
    public var isMicOn: Bool = false
    public var isCameraOn: Bool = false
    public init(){}
}

extension JMMediaEngine: JMMediaEngineAbstract {

    public func create(withAppId appID: String, mediaOptions: JMMediaOptions, delegate: JMMediaEngineDelegate?) -> JMMediaEngine{
        LOG.debug("\(#function) - \(appID)")
        delegateBackToClient = delegate
        vm_manager = JMManagerViewModel(delegate: self, mediaOptions: mediaOptions)
        return JMMediaEngine.shared
    }
    
    public func join(meetingId: String, meetingPin: String, userName: String, meetingUrl: String, isRejoin: Bool = false){
        LOG.debug("\(#function) - \(meetingId)|\(meetingPin)|\(userName)|\(meetingUrl)")
        vm_manager.userState.selfUserName = userName
        vm_manager.qJMMediaBGQueue.async {
            JMJoinViewApiHandler.validateJoiningDetails(meetingId: meetingId, meetingPin: meetingPin, userName: userName, meetingUrl: meetingUrl) { (result) in
                switch result{
                case .success(let model):
                    self.vm_manager.connect(socketUrl: model.mediaServer.publicBaseUrl, roomId: model.jiomeetId, jwtToken: model.jwtToken, isRejoin: isRejoin)
                case .failure(let error):
                    self.sendClientError(error: error)
                }
            }
        }
    }

    public func leave() {
        vm_manager.isCallEnded = true
        vm_manager.socketEmitSelfPeerLeave()
        sendClientEndCall()
    }
    
    public func enableLog(_ isEnable: Bool,withPath path: String = "") -> String{
        LOG.info("LOG- isEnabled:\(isEnable)|path:\(path == "" ? "Default" : path)")
        return JMLogManager.shared.enableLogger(isEnable,withPath: path)
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
    
    public func setRemoteFeed(for remoteId: String, preferredQuality: JMMediaQuality) {
        vm_manager.setPreferredFeedQuality(remoteId: remoteId, preferredQuality: preferredQuality)
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
    public func sendPublicMessage(_ message: [String:Any], _ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil) {
        vm_manager.sendJMBroadcastPublicMessage(messageInfo: message, resultCompletion)
    }
    public func sendPrivateMessage(_ message: [String:Any], _ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil) {
        vm_manager.sendJMBroadcastPrivateMessage(messageInfo: message, resultCompletion)
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
        if vm_manager.userState.selfCameraEnabled{
            LOG.debug("AVVideoDevice- PARTICIPANT_BACKGROUND_ACTIVATED")
            vm_manager.sendJMBroadcastPublicMessage(messageInfo: vm_manager.createMessageInfo(message: JMRTMMessage.PARTICIPANT_BACKGROUND_ACTIVATED.rawValue, senderName: vm_manager.userState.selfUserName, senderParticipantId: vm_manager.userState.selfPeerId))
        }
    }
    
    internal func handleForegroundVideoEvent(){
        if vm_manager.userState.selfCameraEnabled{
            LOG.debug("AVVideoDevice- PARTICIPANT_BACKGROUND_INACTIVATED")
            vm_manager.sendJMBroadcastPublicMessage(messageInfo: vm_manager.createMessageInfo(message: JMRTMMessage.PARTICIPANT_BACKGROUND_INACTIVATED.rawValue, senderName: vm_manager.userState.selfUserName, senderParticipantId: vm_manager.userState.selfPeerId))
        }
    }
    
    private func handleVideo(_ enable: Bool, _ completion: ((_ isSuccess: Bool) -> ())? = nil){
        if enable{
            vm_manager.qJMMediaBGQueue.async { [weak self] in
                guard let self = self else { return }
                self.vm_manager.startVideo { isSuccess in
                    self.vm_manager.userState.selfCameraEnabled = isSuccess ? enable : self.vm_manager.userState.selfCameraEnabled
                    
                    self.vm_manager.qJMMediaMainQueue.async {
                        completion?(isSuccess)
                    }
                }
            }
        }
        else{
            vm_manager.disableVideo()
            vm_manager.userState.selfCameraEnabled = false
            
            self.vm_manager.qJMMediaMainQueue.async {
                completion?(true)
            }
        }
    }
    
    private func handleAudio(_ enable: Bool, _ completion: ((_ isSuccess: Bool) -> ())? = nil){
        if enable{
            vm_manager.qJMMediaBGQueue.async { [weak self] in
                guard let self = self else { return }
                self.vm_manager.startAudio { isSuccess in
                    self.vm_manager.userState.selfMicEnabled = isSuccess ? enable : self.vm_manager.userState.selfMicEnabled
                    
                    self.vm_manager.qJMMediaMainQueue.async {
                        completion?(isSuccess)
                    }
                    
                    if !isSuccess{
                        self.sendClientError(error: JMMediaError.init(type: .audioStartFailed, description: ""))
                    }
                }
            }
        }
        else{
            vm_manager.disableMic()
            vm_manager.userState.selfMicEnabled = false
            
            self.vm_manager.qJMMediaMainQueue.async {
                completion?(true)
            }
        }
    }
}
