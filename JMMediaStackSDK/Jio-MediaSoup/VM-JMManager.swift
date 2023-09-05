//
//  VM-JMManager.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 30/06/23.
//

import Foundation
import Network

import SwiftyJSON
import Mediasoup
import WebRTC
import MMWormhole

//Note - VM to manager communication
protocol delegateManager: AnyObject{
    //Core events
    func sendClientJoinSocketSuccess(selfId: String)
    func sendClientNetworkQuality(stats: JMNetworkStatistics)
    func sendClientTopSpeakers(listActiveParticipant: [JMActiveParticipant])
    func sendClientError(error: JMMediaError)
    func sendClientRetrySocketSuccess(selfId: String)
    
    //DeviceManager
    func sendClientAudioDeviceInUse(_ device: AVAudioDevice)
    func sendClientVideoDeviceInUse(_ device: AVVideoDevice)
    
    //Remote User actions
    func sendClientUserPublished(id: String, type: JMMediaType)
    func sendClientUserUnPublished(id: String, type: JMMediaType)
    func sendClientBroadcastMessage(msg: [String: Any])
    func sendClientBroadcastMessageToPeer(msg: [String: Any])
    func sendClientUserJoined(user: JMUserInfo)
    func sendClientUserLeft(id: String, reason: JMUserLeaveReason)
    func sendClientConnectionStateChanged(state: JMSocketConnectionState)
    
    //BackgroundEvents
    func handleBackgroundVideoEvent()
    func handleForegroundVideoEvent()
}

class JMManagerViewModel: NSObject{
    var delegateBackToManager: delegateManager?
    
    //State
    var userState = LocalState()
    
    //SOCKET
    var jioSocket: JioSocket = JioSocket()
    
    //MEDIA SOUP
    var device:Device?
    var peerConnectionFactory:RTCPeerConnectionFactory?
    var mediaOptions: JMMediaOptions!
    
    //Audio
    var audioProducer:Producer?
    var audioTrack:RTCAudioTrack?
    
    //Video
    var videoTrack:RTCVideoTrack?
    var videoProducer:Producer?
    var mediaStream:RTCMediaStream?
    var videoSource:RTCVideoSource!
    var videoCaptureFormat:AVCaptureDevice.Format?
    var videoCapture:RTCCameraVideoCapturer?
    var videoSelfRTCRenderView: RTCMTLVideoView?
    var videoSelfRenderView:UIView?
    
    //SreenShare
    var screenShareProducer:Producer?
    var mediaStreamScreenCapture:RTCMediaStream?
    var videoTrackScreen:RTCVideoTrack?
    var videoSourceScreen:RTCVideoSource!
    var videoSourceScreenCapture:RTCVideoCapturer?
        
    //Transport
    var sendTransport:SendTransport?
    var recvTransport:ReceiveTransport?
    
    //stats transport
    var transportStatsParam:[String:Any] = [:]

    //Data
    var socketConnectedData: [String: Any] = [:]
    
    //Subscribe
    var peersMap:[String:Peer] = [:]
    var subscriptionVideoList: [String] = []
    
    //ScreenShare producer
    var subscriptionScreenShareVideo: String = ""
    var screenShareProducerID = ""
    
    //AudioOnly
    var isAudioOnlyModeEnabled: Bool = false
    
    var totalProducers:[String:Producer] = [:]
    var totalVideoConsumer:[String:String] = [:]
    var currentMediaQualityPreference: JMMediaQuality = .high
        
    //TODO: need to remove this hardcoding.
    let width = 1170
    let height = 2532
    
    var isCallEnded: Bool = false
    let qJMMediaBGQueue: DispatchQueue = DispatchQueue(label: "jmmedia.background",qos: .background)
    let qJMMediaNWQueue: DispatchQueue = DispatchQueue(label: "jmmedia.network",qos: .background)
    let qJMMediaMainQueue: DispatchQueue = DispatchQueue.main
    
    var connectionState: JMSocketConnectionState = .connecting
    
    var networkMonitor: NWPathMonitor?
    var connectionNetworkType: JMNetworkType = .NoInternet
    var isRetryAttempt: Bool = false
    
    init(delegate: delegateManager,mediaOptions: JMMediaOptions)
    {
        super.init()
        
        self.delegateBackToManager = delegate
        self.mediaOptions = mediaOptions
        //self.setupConfig()
        self.startNetworkMonitor()
    }
    
    func setupConfig(){
        if mediaOptions.isHDEnabled{
            JioMediaStackDefaultCameraCaptureResolution.width = 1280
            JioMediaStackDefaultCameraCaptureResolution.height = 720
        }
        else{
            JioMediaStackDefaultCameraCaptureResolution.width = 640
            JioMediaStackDefaultCameraCaptureResolution.height = 360
        }
    }
}

extension JMManagerViewModel{
    func onSocketConnection(data: [String: Any]){
        socketConnectedData = data
    }
        
    func dispose() {
        LOG.debug("End- dispose")
        
        totalProducers.forEach({
            $0.value.close()
            socketCloseProducer(producerId: $0.key)
        })
        
        self.jioSocket.disconnectSocket()
        self.stopNetworkMonitor()
        
        peersMap.forEach({
            $0.value.consumerAudio?.close()
            $0.value.consumerVideo?.close()
            $0.value.consumerScreenShare?.close()
        })
        
        peersMap = [:]
        subscriptionVideoList = []
        
        if let screenShareProducer = screenShareProducer{
            screenShareProducer.close()
            socketCloseProducer(producerId: subscriptionScreenShareVideo)
            subscriptionScreenShareVideo = ""
        }
        sendTransport?.close()
        recvTransport?.close()
        JMAudioDeviceManager.shared.dispose()
        JMVideoDeviceManager.shared.dispose()
        
        self.disposeVideoAudioTrack()
        
        if device != nil{
            device = nil
        }
    }
}

//MARK: Audio Video configurations
extension JMManagerViewModel{
    func getAudioCodec() -> String {
        let audioCodec: [String: Any] = [
            JioMediaStackAudioCodec.opusDtx.rawValue:true,
            JioMediaStackAudioCodec.opusStereo.rawValue:true,
        ]
        
        let json:JSON = JSON(audioCodec)
        return json.description
    }
        
    func getVideoMediaLayers() -> [RTCRtpEncodingParameters] {
        func genRtpEncodingParameters(rid: String?,active: Bool,bitRatePriority: Double,networkPriority: RTCPriority,maxBitrateBps: NSNumber?,minBitrateBps: NSNumber?,maxFramerate: NSNumber?,numTemporalLayers: NSNumber?,scaleResolutionDownBy: NSNumber?,adaptativeAudioPacketTime: Bool) -> RTCRtpEncodingParameters
        {
            let encodingParams = RTCRtpEncodingParameters()
            encodingParams.rid = rid
            encodingParams.isActive = active
            encodingParams.bitratePriority = bitRatePriority
            encodingParams.networkPriority = networkPriority
            encodingParams.maxBitrateBps = maxBitrateBps
            encodingParams.minBitrateBps = minBitrateBps
            encodingParams.maxFramerate = maxFramerate
            encodingParams.numTemporalLayers = numTemporalLayers
            encodingParams.scaleResolutionDownBy = scaleResolutionDownBy
            encodingParams.adaptiveAudioPacketTime = adaptativeAudioPacketTime
            return encodingParams
        }
        
        let lowLayer = genRtpEncodingParameters(
            rid: "layer1",
            active: true,
            bitRatePriority: JioMediaStackBitratePriority.low.rawValue,
            networkPriority: RTCPriority.high,
            maxBitrateBps: JioMediaStackVideoMaxBitrate.low.value,
            minBitrateBps: 0,
            maxFramerate: JioMediaStackVideoFPS.medium.rawValue,
            numTemporalLayers: 3,
            scaleResolutionDownBy: JioMediaStackScaleDownResolution.low.rawValue,
            adaptativeAudioPacketTime: true
        )
        
        let midLayer = genRtpEncodingParameters(
            rid: "layer2",
            active: true,
            bitRatePriority: JioMediaStackBitratePriority.medium.rawValue,
            networkPriority: RTCPriority.high,
            maxBitrateBps: JioMediaStackVideoMaxBitrate.medium(isHD: mediaOptions.isHDEnabled).value,
            minBitrateBps: 0,
            maxFramerate: JioMediaStackVideoFPS.medium.rawValue,
            numTemporalLayers: 3,
            scaleResolutionDownBy: JioMediaStackScaleDownResolution.medium.rawValue,
            adaptativeAudioPacketTime: true
        )
        
        var layers = [lowLayer, midLayer]
        
        if mediaOptions.isHDEnabled{
            let highLayer = genRtpEncodingParameters(
                rid: "layer3",
                active: true,
                bitRatePriority: JioMediaStackBitratePriority.high.rawValue,
                networkPriority: RTCPriority.high,
                maxBitrateBps: JioMediaStackVideoMaxBitrate.high.value,
                minBitrateBps: 0,
                maxFramerate: JioMediaStackVideoFPS.medium.rawValue,
                numTemporalLayers: 3,
                scaleResolutionDownBy: JioMediaStackScaleDownResolution.high.rawValue,
                adaptativeAudioPacketTime: true
            )
            
            layers.append(highLayer)
        }
        
        LOG.debug("Video- layers count: \(layers.count)")
        return layers
    }
}

extension JMManagerViewModel{
    
    func getRTPCapabilities() -> String? {
        if let rtpCapabilities = self.socketConnectedData[SocketDataKey.rtpCapabilities.rawValue] as? [String: Any] {
            let json:JSON = JSON(rtpCapabilities)
            return json.description
        }
        return nil
    }
    
    func getRoomConfiguration() -> [String: Any] {
        let joinMetaData: [String: Any] = [
            SocketDataKey.userType.rawValue:SocketDataKey.human.rawValue,
            SocketDataKey.userRole.rawValue:SocketDataKey.host.rawValue
        ]
        
        var joinArgs: [String: Any] = [:]
        joinArgs[SocketDataKey.device.rawValue] = SocketUtil.deviceInfo()
        joinArgs[SocketDataKey.rtpCapabilities.rawValue] = self.socketConnectedData[SocketDataKey.rtpCapabilities.rawValue]
        joinArgs[SocketDataKey.sctpCapabilities.rawValue] = ""
        joinArgs[SocketDataKey.metaData.rawValue] = joinMetaData
        return joinArgs
    }
    
    func getReceiveTransport() -> [String: Any]?{
        if let recvTransport = self.socketConnectedData[SocketDataKey.receiveTransport.rawValue] as? [String: Any] {
            return recvTransport
        }
        return nil
    }
    
    func getIceServer(fromReceiveTransport receiveTransport: [String:Any]) -> String? {
        if let object = receiveTransport[ReceiveTransportKey.iceServers.rawValue] as? [[String: Any]] {
            let json:JSON = JSON(object)
            return json.description
        }
        return nil
    }
    
    func isRelayTransportPolicy(fromReceiveTransport receiveTransport: [String:Any]) -> Bool {
        if let iceTransportPolicy = receiveTransport[ReceiveTransportKey.iceTransportPolicy.rawValue] as? String {
            return iceTransportPolicy.lowercased() == "relay"
        }
        return false
    }
}

//MARK: Peer to UserInfo Mapping
extension JMManagerViewModel {
    func formatToJMUserInfo(from peer: Peer) -> JMUserInfo{
        var userInfo = JMUserInfo()
        userInfo.userId = peer.peerId
        userInfo.hasAudio = peer.isAudioEnabled
        userInfo.hasVideo = isAudioOnlyModeEnabled ? false : peer.isVideoEnabled //TODO: check this
        userInfo.hasScreenShare = peer.isScreenShareEnabled
        userInfo.name = peer.displayName
        userInfo.role = "" //TODO: need to check in the future
        return userInfo
    }
    func createUserInfos(from peers: [Peer]) -> [JMUserInfo] {
        return peers.map { formatToJMUserInfo(from: $0) }
    }
}

//MARK: Helpers - Dictionary
extension JMManagerViewModel{
    func getJson(data: [Any]) -> [String: Any]? {
        if data.count > 0 {
            if let json = data[0] as? [String: Any] {
                return json
            }
        }
        return nil
    }
    func getJsonArr(data: [Any]) -> [[String: Any]]? {
        if data.count > 0 {
            if let json = data[0] as? [[String: Any]] {
                return json
            }
        }
        return nil
    }
    
    func getDataOf(key: String, dictionary:[String: Any]) -> [String: Any]? {
        if let json = dictionary[key] as? [String: Any] {
            return json
        }
        return nil
    }
}
