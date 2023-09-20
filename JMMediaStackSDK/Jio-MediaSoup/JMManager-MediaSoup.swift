//
//  VM-JMManager-MediaSoup.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 03/07/23.
//

//MARK: JMManager - Media Soup class

import Foundation

import Mediasoup
import WebRTC

extension JMManagerViewModel{
    internal func initMediaSoupEngine(with data: [String: Any]){
        
        if let rtpCapabilities = getRTPCapabilities() {
            
            let device = Device()
            handleMediaSoupErrors("Device-") {
                
                /*
                if let transportConfigurationObject = getReceiveTransport(),
                    let iceServers = getIceServer(fromReceiveTransport: transportConfigurationObject)
                {
                    LOG.debug("Device- Custom version with ice servers and relay")
                    let isRelayTransportPolicy = isRelayTransportPolicy(fromReceiveTransport: transportConfigurationObject)
                    try device.load(with: rtpCapabilities, peerConnectionOptions: iceServers, isRelayTransportPolicy: isRelayTransportPolicy)
                }
                else{
                    LOG.debug("Device- Default version")
                    try device.load(with: rtpCapabilities)
                }
                */
                
                try device.load(with: rtpCapabilities)
                
                let canProduceAudio = try device.canProduce(.audio)
                let canProduceVideo = try device.canProduce(.video)
                
                if !canProduceAudio {
                    LOG.error("Device- Cant Produce Audio")
                    delegateBackToManager?.sendClientError(error: JMMediaError.init(type: .AudioMediaNotSupported, description: ""))
                }
                
                if !canProduceVideo {
                    LOG.error("Device- Cant Produce Video")
                    delegateBackToManager?.sendClientError(error: JMMediaError.init(type: .VideoMediaNotSupported, description: ""))
                }
                
                self.device = device
                self.jioSocket?.emit(action: .join, parameters: getRoomConfiguration())
            }
        }
    }
    
    internal func initFactoryAndStream() {
        if peerConnectionFactory == nil {
            peerConnectionFactory = RTCPeerConnectionFactory()
        }
        if mediaStream == nil {
            mediaStream = peerConnectionFactory?.mediaStream(withStreamId: JioMediaId.cameraStreamId)
            mediaStreamScreenCapture = peerConnectionFactory?.mediaStream(withStreamId: JioMediaId.screenShareStreamId)
        }
    }
}

//MARK: Audio
extension JMManagerViewModel{
    func startAudio(_ completion: ((_ isSuccess: Bool)->())){
        LOG.debug("Audio- startAudio")
        
        if let producer = audioProducer{
            LOG.debug("Audio- audio producer resume")
            producer.resume()
            socketEmitResumeProducer(for: producer.id)
            completion(true)
            return
        }
        
        guard let audioTrack = self.peerConnectionFactory?.audioTrack(withTrackId: JioMediaId.audioTrackId) else {
            LOG.error("Audio- audioTrack failed")
            completion(false)
            return
        }
        
        audioTrack.isEnabled = true
        self.mediaStream?.addAudioTrack(audioTrack)
        
        guard let sendTransport = sendTransport else {
            LOG.error("Audio- send Transport not available")
            completion(false)
            return
        }
        
        LOG.debug("Audio- startAudio createProducer")
        
        let result = handleMediaSoupErrors("Audio-") {
            let producer = try sendTransport.createProducer(for: audioTrack, encodings: nil, codecOptions: getAudioCodec(), codec: nil, appData: JioMediaAppData.audioAppData)
            self.audioProducer = producer
            self.audioTrack = audioTrack
            self.totalProducers[producer.id] = producer
            LOG.info("Audio- startAudio producer created")
            producer.resume()
        }
        completion(result)
    }
}

//MARK: Video
extension JMManagerViewModel{
    func startVideo(_ completion: ((_ isSuccess: Bool)->())){
        LOG.debug("Video- startVideo")
        
        if let producer = videoProducer{
            LOG.debug("Video- video producer resumed")
            startVideoCameraCapture()
            enableLocalRenderView(true)
            videoTrack?.isEnabled = true
            producer.resume()
            socketEmitResumeProducer(for: producer.id)
            completion(true)
            return
        }
        
        guard let videoSource = self.peerConnectionFactory?.videoSource() else{
            LOG.error("Video- peerConnection source failed")
            completion(false)
            return
        }
        self.videoSource = videoSource
        
        let isSuccess = checkVideoCameraCapture()
        if !isSuccess{
            LOG.error("Video- failed startVideoCameraCapture")
            completion(false)
            return
        }
        
        guard let sendTransport = sendTransport,let videoTrack = videoTrack else {
            LOG.error("Video- send Transport not available | transport:\(sendTransport) | track:\(videoTrack)")
            completion(false)
            return
        }
        
        let result = handleMediaSoupErrors("Video-") {
            let producer = try sendTransport.createProducer(for: videoTrack, encodings: getVideoMediaLayers(), codecOptions:  nil, codec: nil, appData: JioMediaAppData.videoAppData)
            self.videoProducer = producer
            self.updateProducerLayers()
            self.totalProducers[producer.id] = producer
            LOG.info("Video- startVideo producer created")
            producer.resume()
        }
        completion(result)
    }
    
    private func startVideoCameraCapture() -> Bool{
        guard let cameraDevice = JMVideoDeviceManager.shared.getCameraDevice() else {
            LOG.error("Video- No camera device found")
            delegateBackToManager?.sendClientError(error: JMMediaError.init(type: .cameraNotAvailable, description: "No camera device found"))
            return false
        }
        
        let fps = JioMediaStackDefaultCameraCaptureResolution.fps
        guard let format = JMVideoDeviceManager.shared.fetchPreferredResolutionFormat(cameraDevice) else {
            LOG.error("Video- No format found")
            delegateBackToManager?.sendClientError(error: JMMediaError.init(type: .videoDeviceNotSupported, description: "No format found \(cameraDevice.localizedName)"))
            return false
        }
        videoCaptureFormat = format
        
        if #available(iOS 13.0, *) {
            self.videoSource.adaptOutputFormat(toWidth: format.formatDescription.dimensions.width, height: format.formatDescription.dimensions.height, fps: fps)
        } else {
            self.videoSource.adaptOutputFormat(toWidth: JioMediaStackDefaultCameraCaptureResolution.width, height: JioMediaStackDefaultCameraCaptureResolution.height, fps: fps)
        }
        
        self.videoCapture?.startCapture(with: cameraDevice, format:format, fps: Int(fps))
        LOG.debug("Video- started capture with \(cameraDevice.localizedName)")
        return true
    }
    
    private func checkVideoCameraCapture() -> Bool{
        self.videoCapture = RTCCameraVideoCapturer(delegate: self.videoSource)
        
        let isResumeSuccess = self.startVideoCameraCapture()
        if isResumeSuccess == false{
            LOG.error("Video- camera capture resume failed")
            return false
        }
        
        //Update the track, if camera is switched
        if let videoTrack = videoTrack{
            addViewToRender()
            self.mediaStream?.removeVideoTrack(videoTrack)
            LOG.debug("Video- track removed")
        }
        
        guard let videoTrack = self.peerConnectionFactory?.videoTrack(with: self.videoSource, trackId: JioMediaId.videoTrackId) else{
            LOG.error("Video- new track failed")
            delegateBackToManager?.sendClientError(error: JMMediaError.init(type: .videoStartFailed, description: "Video track failed"))
            return false
        }
        
        videoTrack.isEnabled = true
        self.mediaStream?.addVideoTrack(videoTrack)
        self.videoTrack = videoTrack
        addViewToRender()
        LOG.debug("Video- track added")
        return true
    }
    
    func addLocalRenderView(_ renderView: UIView){
        LOG.debug("Video- local renderview ready")
        self.videoSelfRenderView = renderView
        
        qJMMediaMainQueue.async {
            let localView = RTCMTLVideoView()
            renderView.addSubview(localView)
            self.setConstrainsts(of: localView, toView: renderView)
            self.videoSelfRTCRenderView = localView
            self.removeViewFromRendering()
            self.addViewToRender()
        }
    }
    
    func enableLocalRenderView(_ isEnabled: Bool){
        LOG.debug("Video- update renderview ready")
        
        qJMMediaMainQueue.async {
            if let localView = self.videoSelfRenderView{
                for subviewRtc in localView.subviews where subviewRtc is RTCMTLVideoView {
                    subviewRtc.isHidden = !isEnabled
                }
            }
        }
    }
    
    func addRemoteRenderView(_ renderView: UIView, remoteId: String){
        if var updatedPeer = self.peersMap[remoteId]
        {
            updatedPeer.remoteView = renderView
            peersMap[remoteId] = updatedPeer
            updateRemoteRenderViewTrack(for: remoteId)
        }
    }
    
    func updateRemoteRenderViewTrack(for remoteId: String){
        if var updatedPeer = self.peersMap[remoteId],
           let renderView = updatedPeer.remoteView,
           let consumer = updatedPeer.consumerVideo,
           let rtcVideoTrack = consumer.track as? RTCVideoTrack
            
        {
            LOG.debug("Subscribe- UI updated - name-\(updatedPeer.displayName)")
            
            qJMMediaMainQueue.async {
                for subview in renderView.subviews where subview is RTCMTLVideoView{
                    if let previousVideoView = subview as? RTCMTLVideoView{
                        rtcVideoTrack.remove(previousVideoView)
                    }
                    subview.removeFromSuperview()
                }
                updatedPeer.remoteView = self.bindRenderViewAndTrack(rtcVideoTrack, renderView: renderView)
            }
            
            peersMap[remoteId] = updatedPeer
        }
    }
    
    private func addViewToRender(){
        if let renderView = self.videoSelfRTCRenderView{
            videoTrack?.add(renderView)
        }
    }
    
    private func removeViewFromRendering(){
        if let renderView = self.videoSelfRTCRenderView{
            videoTrack?.remove(renderView)
        }
    }
    
    private func bindRenderViewAndTrack(_ rtcVideoTrack: RTCVideoTrack, renderView: UIView) -> UIView{
        let remoteView = RTCMTLVideoView()
        rtcVideoTrack.add(remoteView)
        rtcVideoTrack.isEnabled = true
        renderView.addSubview(remoteView)
        setConstrainsts(of: remoteView, toView: renderView)
        return renderView
    }
    
    func switchCamera() {
        videoCapture?.stopCapture { [weak self] in
            guard let self = self else { return }
            self.checkVideoCameraCapture()
        }
    }
}

//MARK: Constraints
extension JMManagerViewModel{
    func setConstrainsts(of firstView:RTCMTLVideoView, toView: UIView){
        firstView.translatesAutoresizingMaskIntoConstraints = false
        firstView.leadingAnchor.constraint(equalTo: toView.leadingAnchor).isActive = true
        firstView.trailingAnchor.constraint(equalTo: toView.trailingAnchor).isActive = true
        firstView.topAnchor.constraint(equalTo: toView.topAnchor).isActive = true
        firstView.bottomAnchor.constraint(equalTo: toView.bottomAnchor).isActive = true
    }
}

//MARK: Audio Only Mode
extension JMManagerViewModel{
    func isVideoFeedDisable(_ mediaType: JMMediaType) -> Bool{
        return isAudioOnlyModeEnabled && mediaType == .video
    }
    
    func enableAudioOnlyMode(_ enable: Bool, userList: [String], includeScreenShare: Bool){
        LOG.info("Video- AudioOnly- \(enable) | includeScreenShare:\(includeScreenShare)")
        isAudioOnlyModeEnabled = enable
                
        if includeScreenShare{
            handleAudioOnlyModeForScreenShare()
        }
        
        if enable{
            LOG.debug("Subscribe- DeSubscribing List \(subscriptionVideoList)")
            subscriptionVideoList.forEach({ feedHandler(false, remoteId: $0, mediaType: .video) })
            subscriptionVideoList = []
        }
        else{
            if !userList.isEmpty{
                LOG.debug("Subscribe- Subscribing List \(userList)")
                subscriptionVideoList = userList
                subscriptionVideoList.forEach({ feedHandler(true, remoteId: $0, mediaType: .video) })
            }
        }
        
    }
}

extension JMManagerViewModel {
    
    func disableVideo() {
        if let track = self.videoTrack {
            track.isEnabled = false
        }
        if let producer = self.videoProducer {
            producer.pause()
            socketEmitPauseProducer(for: producer.id)
            enableLocalRenderView(false)
        }
        videoCapture?.stopCapture()
    }
    
    func disableMic() {
        if let track = self.audioTrack {
            track.isEnabled = false
        }
        if let producer = self.audioProducer {
            producer.pause()
            socketEmitPauseProducer(for: producer.id)
        }
    }
    
    func disposeVideoAudioTrack() {
        
        //Audio
        if let track = self.audioTrack {
            track.isEnabled = false
            self.audioTrack = nil
        }
        
        if self.audioProducer != nil {
            audioProducer = nil
        }
        
        //Video
        videoCapture?.stopCapture()
        if videoCapture != nil{
            self.videoCapture = nil
        }
        
        if videoSource != nil{
            self.videoSource = nil
        }
             
        if let track = self.videoTrack {
            track.isEnabled = false
            self.videoTrack = nil
        }
        
        if self.videoProducer != nil {
            videoProducer = nil
        }
        
        //Screenshare
        if let track = self.videoTrackScreen {
            track.isEnabled = false
            self.videoTrackScreen = nil
        }
        
        if self.screenShareProducer != nil {
            screenShareProducer = nil
        }
        
        //Stream
        if self.mediaStream != nil {
            self.mediaStream = nil
        }
        
        if self.mediaStreamScreenCapture != nil {
            self.mediaStreamScreenCapture = nil
        }
        
        //ConnectionFactory
        if self.peerConnectionFactory != nil {
            self.peerConnectionFactory = nil
        }
        
        //Device
        if self.device != nil{
            self.device = nil
        }
    }
}

//MARK: Media soup Transport and Stats
extension JMManagerViewModel{
     func createSendAndReceiveTransport(){
         onCreateSendTransport()
         onCreateRecvTransport()
         startTransportStatsScheduler()
    }
    
    private func onCreateSendTransport() {
        if let json = self.getDataOf(key: SocketDataKey.sendTransport.rawValue, dictionary: self.socketConnectedData) {
            self.sendTransport = self.createSendTransport(json: json, device: self.device)
            self.sendTransport?.delegate = self
        }
    }
    
    private func onCreateRecvTransport(){
        if let json = self.getDataOf(key: SocketDataKey.receiveTransport.rawValue, dictionary: self.socketConnectedData) {
            self.recvTransport = self.createReceiveTransport(json: json, device: self.device)
            self.recvTransport?.delegate = self
        }
    }
}

//MARK: Error handling
extension JMManagerViewModel{
    internal func handleMediaSoupErrors<T>(_ loggerPrefix: String = "", _ throwingClosure: () throws -> T) -> Bool {
        do {
            try throwingClosure()
            return true
        }
        catch let error as MediasoupError {
            switch error {
            case .unsupported(let error):
                LOG.error("\(loggerPrefix) MediaSoupError- Unsupported with error \(error)")
            case .invalidParameters(let error):
                LOG.error("\(loggerPrefix) MediaSoupError- invalidParameters with error \(error)")
            case .invalidState(let error):
                LOG.error("\(loggerPrefix) MediaSoupError- invalidState with error \(error)")
            case .unknown(let error):
                LOG.error("\(loggerPrefix) MediaSoupError- Unknown with error \(error)")
            default:
                LOG.error("\(loggerPrefix) MediaSoupError- default case")
            }
            return false
        }
        catch (let error) {
            LOG.error("\(loggerPrefix) MediaSoupError- error \(error.localizedDescription)")
            return false
        }
    }
}
