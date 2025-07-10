//
//  JMManager.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 30/06/23.
//

import Foundation
import AVFoundation
import WebRTC        // MediaSoup WebRTC (RTC* classes) - original functionality
import Mediasoup     // MediaSoup framework  
import LiveKit       // LiveKit WebRTC (LKRTC* classes) - dual stack addition

@_implementationOnly import SwiftyJSON

let LOG = JMLogManager.self

public class JMMediaEngine : NSObject{
    
    static public let shared = JMMediaEngine()
    private override init() {
        super.init()
        setupDualWebRTCStack()
    }
    
    public var delegateBackToClient:JMMediaEngineDelegate?
    private var vm_manager: JMManagerViewModel!
    var socketChecker: SocketChecker?
    
    // MARK: - Dual WebRTC Stack Support
    private var webRTCManager: JMWebRTCManager?
    
    // MARK: - Dual WebRTC Stack Setup
    private func setupDualWebRTCStack() {
        webRTCManager = JMWebRTCManager.shared
        LOG.info("JMMediaEngine: Dual WebRTC stack initialized - MediaSoup (RTC*) + LiveKit (LKRTC*)")
    }
    
    // MARK: - WebRTC Engine Switching (Public API)
    public func switchWebRTCEngine(to engineType: JMWebRTCEngineType) async {
        await webRTCManager?.switchToEngine(engineType)
        LOG.info("JMMediaEngine: Switched to \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit") WebRTC engine")
    }
    
    public func getCurrentWebRTCEngine() -> JMWebRTCEngineType {
        return webRTCManager?.getCurrentEngine() ?? .mediaSoup
    }
}

//MARK: Communicating back to Client (send data and event to client app)
extension JMMediaEngine: delegateManager{
    func handleForegroundSocketEvent() {
        socketChecker = SocketChecker.init(attemptCount: 3, vm_manager: vm_manager, handleForegroundVideoEvent: {
        print("Current  ")
        })
        socketChecker?.startCheckingSocketConnection()
    }
    
    func handleForegroundSocketEvent(retryCount: Int = 1) {
        if retryCount > 3 {
            // Stop after 3 retries
            return
        }

        if let socketStatus = self.vm_manager.jioSocket?.getSocket()?.status, socketStatus != .connected {
            print("Attempt \(retryCount) - Current status is rejoin attempt \(socketStatus)")
            // Reconnect or handle disconnected socket
            // rejoin() // Uncomment if rejoin logic is needed

            // Schedule next retry after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.handleForegroundSocketEvent(retryCount: retryCount + 1)
            }
        } else {
            // Handle connected socket
            handleForegroundVideoEvent()
            print("Current status is \(String(describing: self.vm_manager.jioSocket?.getSocket()?.status))")
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
            self.vm_manager.qJMMediaMainQueue.async {
                self.delegateBackToClient?.onUserJoined(user: user)
            }
    }
    
    func sendClientUserLeft(id: String, reason: JMUserLeaveReason) {
            self.vm_manager.qJMMediaMainQueue.async {
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
    
    //Local media state
    func sendClientSelfLocalMediaState(type: JMMediaType, reason: JMMediaReason) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onLocalMediaStateChange(type: type, reason: reason)
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
    
    func sendClientSpeakOnMute() {
        vm_manager.qJMMediaMainQueue.async {
            if !self.vm_manager.userState.selfMicEnabled {
                self.delegateBackToClient?.onUserSpeakingOnMute()
            }
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
    
    func sendClientRemoteNetworkQuality(id: String, quality: JMNetworkQuality, mediaType: JMMediaType) {
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onRemoteNetworkQuality(id: id, quality: quality, mediaType: mediaType)
        }
    }
    
    //End
    func sendClientEndCall(){
        vm_manager.qJMMediaMainQueue.async {
            self.delegateBackToClient?.onChannelLeft()
        }
    }
    
    //log
    func sendClientLogMsg(log: String) {
        vm_manager.qJMMediaLogQueue.sync {
            self.delegateBackToClient?.onLogMessage(message: log)
       }
    }
}

public struct JMMediaOptions{
    public var isHDEnabled: Bool = false
    public var isMicOn: Bool = false
    public var isCameraOn: Bool = false
    public var isWatchPartyEnabled: Bool = false
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
                    //send disconnect to client
                    self.vm_manager.didConnectionStateChange(.disconnected)
                    self.sendClientError(error: error)
                }
            }
        }
    }

    public func leave() {
        vm_manager.isCallEnded = true
        vm_manager.socketEmitSelfPeerLeave()
        sendClientEndCall()
        JMAudioDeviceManager.shared.dispose() //To clean up audio session, in case no internet.
    }
    
    public func enableLog(_ isEnabled: Bool, severity: JMLogSeverity = .info){
        JMLogManager.shared.enableLogs(isEnabled: isEnabled, severity: severity, delegate: self)
    }
}

//MARK: AUDIO PUBLIC ACCESS
extension JMMediaEngine{
    public func getAudioDevices() -> [JMAudioDevice] {
        return JMAudioDeviceManager.shared.getAllJMDevices()
    }
    
    public func setAudioDevice(_ jmDevice: JMAudioDevice) {
        JMAudioDeviceManager.shared.setJMAudioDevice(jmDevice)
    }
    
    public func setRemotePeerVolume(_ volume: Double){
        vm_manager.setRemotePeerVolume(volume: volume)
    }
    
    public func enableRemotePeerAudio(_ isEnable: Bool = true){
        vm_manager.enableRemotePeerAudio(isEnable)
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
    
    public func enableAudioOnlyMode(_ flag: Bool, userList: [String] = [], includeScreenShare: Bool = true) {
        vm_manager.enableAudioOnlyMode(flag, userList: userList , includeScreenShare: includeScreenShare)
        self.handleAudioOnlyForSelfCamera(flag)
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
    
    @available(iOS 15.0, *)
    public func enableVirtualBackground(_ isEnabled: Bool, withOption option: JMVirtualBackgroundOption = .none){
        vm_manager.enableVirtualBackground(isEnabled, withOption: option)
    }
    
    //ScreenShare
    public func setupShareVideo(_ view: UIView, remoteId: String) {
        vm_manager.addRemoteScreenShareRenderView(view,remoteId: remoteId)
    }
    public func startScreenShare(with appId: String) {
        vm_manager.updateStartScreenShare(with: appId)
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
    public func sendPrivateMessage(_ message: [String : Any], toPeer: String, _ resultCompletion: ((Bool) -> ())?) {
        vm_manager.sendJMBroadcastPrivateMessage(messageInfo: message,toPeer: toPeer,resultCompletion)
    }
}

//MARK: INTERNAL LAYER

//MARK: AudioDeviceManager
extension JMMediaEngine{
    internal func setupDeviceManager(){
        JMAudioDeviceManager.shared.delegateToManager = self
        JMVideoDeviceManager.shared.delegateToManager = self
        if vm_manager.mediaOptions.isWatchPartyEnabled {
            JMAudioDeviceManager.shared.isWatchPartyEnabled = true
            LOG.info("Video- Client set isWatchPartyEnabled ON")
        }else{
            JMAudioDeviceManager.shared.isWatchPartyEnabled = false
            LOG.info("Video- Client set isWatchPartyEnabled false")
        }
        JMAudioDeviceManager.shared.setupSession()
        JMVideoDeviceManager.shared.setupSession()
        
        
        // Retry logic to ensure send transport is available before handling video or audio
            retryGetSendTransport(attempts: 10, delay: 1.0)
        //Client Initial values
//        if vm_manager.mediaOptions.isCameraOn{
//            LOG.info("Video- Client set initial value ON")
//            handleVideo(true)
//        }
//        
//        if vm_manager.mediaOptions.isMicOn{
//            LOG.info("Audio- Client set initial value ON")
//            handleAudio(true)
//        }
    }
    
    // Function to retry getting the send transport
    private func retryGetSendTransport(attempts: Int, delay: TimeInterval) {
        guard attempts > 0 else {
            LOG.error("Video- send Transport not available after multiple attempts")
            return
        }
        
        if let sendTransport = vm_manager.sendTransport {
            LOG.info("Video- send Transport available | transport: \(sendTransport)")
            
            // Client Initial values
            if vm_manager.mediaOptions.isCameraOn {
                LOG.info("Video- Client set initial value ON")
                handleVideo(true)
            }
            
            if vm_manager.mediaOptions.isMicOn {
                LOG.info("Audio- Client set initial value ON")
                handleAudio(true)
            }
        } else {
            LOG.warning("Video- send Transport not available, retrying in \(delay) seconds | attempts left: \(attempts)")
            
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.retryGetSendTransport(attempts: attempts - 1, delay: delay)
            }
        }
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
    
    internal func handleAudioOnlyForSelfCamera(_ enable: Bool){
        if enable{
            if vm_manager.userState.selfCameraEnabled{
                LOG.info("Video- AudioOnly- \(enable) | self camera turning OFF.")
                vm_manager.userState.selfCameraForceOff = true
                handleVideo(false)
            }
        }
        else{
            if vm_manager.userState.selfCameraForceOff{
                vm_manager.userState.selfCameraForceOff = false
                LOG.info("Video- AudioOnly- \(enable) | self camera turning ON.")
                handleVideo(true)
            }
        }
    }
    
    private func handleVideo(_ enable: Bool, _ completion: ((_ isSuccess: Bool) -> ())? = nil){
        vm_manager.userState.selfCameraEnabled = enable
        
        if enable{
            vm_manager.qJMMediaBGQueue.async { [weak self] in
                guard let self = self else { return }
                self.vm_manager.startVideo { isSuccess in
                    self.vm_manager.qJMMediaMainQueue.async {
                        completion?(isSuccess)
                    }
                }
            }
        }
        else{
            vm_manager.disableVideo()
            self.vm_manager.qJMMediaMainQueue.async {
                completion?(true)
            }
        }
    }
    
    private func handleAudio(_ enable: Bool, _ completion: ((_ isSuccess: Bool) -> ())? = nil){
        vm_manager.userState.selfMicEnabled = enable
        
        if enable{
            vm_manager.qJMMediaBGQueue.async { [weak self] in
                guard let self = self else { return }
                self.vm_manager.startAudio { isSuccess in
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
            self.vm_manager.qJMMediaMainQueue.async {
                completion?(true)
            }
        }
    }
}
import Foundation

class SocketChecker {
    var timer: Timer?
    var currentAttempt = 0
    var attemptCount: Int
    var vm_manager: JMManagerViewModel // Replace with actual type
    var handleForegroundVideoEvent: (() -> Void)

    init(attemptCount: Int, vm_manager: JMManagerViewModel, handleForegroundVideoEvent: @escaping () -> Void) {
        self.attemptCount = attemptCount
        self.vm_manager = vm_manager
        self.handleForegroundVideoEvent = handleForegroundVideoEvent
    }

    func startCheckingSocketConnection() {
        resetTimer()
        timer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(handleForegroundSocketEvent), userInfo: nil, repeats: true)
    }

    @objc private func handleForegroundSocketEvent() {
        currentAttempt += 1

        if let status = vm_manager.jioSocket?.getSocket()?.status, status != .connected {
            print("Attempt \(currentAttempt) - Current status is rejoin attempt \(status)")
                vm_manager.jioSocket?.disconnectSocket()
                resetTimer()
        } else {
            if currentAttempt >= attemptCount {
                resetTimer()
                print("Maximum attempts reached. stopping socket check.")
            }
            print("Socket is connected \(currentAttempt) and \(attemptCount).")
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        currentAttempt = 0
    }
}
