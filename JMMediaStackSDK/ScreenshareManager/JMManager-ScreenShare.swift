//
//  JMManager-ScreenShare.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 03/07/23.
//

import Foundation

import MMWormhole
import WebRTC

var wormholeBufferListener: MMWormhole?
extension JMManagerViewModel{
    
     func setSampleBufferwithTimestamp(_ messageObject: [String:Any]) {
        if let object: [String:Any] = messageObject as? [String:Any],
           let buffer = object["buffer"] as? Data,
           let timeStamp = object["timeStamp"] as? Int64{
            
            guard let frameNew = self.convertDataToRTCCVPixelBuffer(data: buffer, timeStamp: timeStamp),
                  let capturer = self.videoSourceScreenCapture
            else {
                LOG.debug("ScreenShare- convertor failed, capture is \(videoSourceScreenCapture)")
                return
            }
            
            self.createScreenShareProducer()
            self.videoSourceScreen?.capturer(capturer, didCapture: frameNew)
        }
    }
    
    func screenShareStart(with appId: String){
        addOrientationObserver()
        
        wormholeBufferListener = MMWormhole(applicationGroupIdentifier: appId,optionalDirectory: "wormhole")
        qJMMediaBGQueue.async {
            wormholeBufferListener?.listenForMessage(withIdentifier: JMScreenShareManager.MediaSoupScreenShareId, listener: { (messageObject) -> Void in
                if let messageBuffer = messageObject as? [String:Any]{
                    self.setSampleBufferwithTimestamp(messageBuffer)
                }
            })
        }
    }
    
    func screenShareStop(){
        removeOrientationObserver()
        if userState.selfScreenShareEnabled{
            socketScreenShareCloseProducer(producerId: userState.selfScreenShareProducerId)
        }
    }
    
    func createScreenShareProducer(){
        if screenShareProducer != nil{
            return
        }
        
        videoSourceScreen = peerConnectionFactory?.videoSource(forScreenCast: true)
        guard let screenShareSource = videoSourceScreen else {
            LOG.error("ScreenShare- source nil")
            return
        }
        
        getDeviceResolution()
        screenShareSource.adaptOutputFormat(toWidth: JioMediaStackDefaultScreenShareCaptureResolution.width, height: JioMediaStackDefaultScreenShareCaptureResolution.height, fps: JioMediaStackDefaultScreenShareCaptureResolution.fps)
        
        videoSourceScreenCapture = RTCVideoCapturer(delegate: screenShareSource)
    
        videoTrackScreen = self.peerConnectionFactory?.videoTrack(with: screenShareSource, trackId: JioMediaId.screenShareTrackId)
        guard let screenShareTrack = videoTrackScreen else {
            LOG.error("ScreenShare- track nil")
            return
        }
        
        screenShareTrack.isEnabled = true
        mediaStreamScreenCapture?.addVideoTrack(screenShareTrack)
        
        guard let sendTransport = sendTransport,let videoTrackScreen = videoTrackScreen else {
            LOG.error("ScreenShare- send Transport not available | transport:\(sendTransport) | track:\(videoTrack)")
            return
        }
        
        handleMediaSoupErrors("ScreenShare-") {
            let producer = try sendTransport.createProducer(for: videoTrackScreen, encodings: nil, codecOptions:  nil, codec: nil, appData: JioMediaAppData.screenShareAppData)
            LOG.debug("ScreenShare- \(producer.id)")
            screenShareProducer = producer
            totalProducers[producer.id] = producer
            producer.resume()
        }
    }
    
     func convertDataToRTCCVPixelBuffer(data: Data,timeStamp: Int64) -> RTCVideoFrame? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(image.size.width),
            kCVPixelBufferHeightKey as String: Int(image.size.height)
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(truncating: pixelBufferAttributes[kCVPixelBufferWidthKey as String] as! NSNumber),
            Int(truncating: pixelBufferAttributes[kCVPixelBufferHeightKey as String] as! NSNumber),
            kCVPixelFormatType_32BGRA,
            pixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let unwrappedPixelBuffer = pixelBuffer else {
            print("Failed to create pixel buffer")
            return nil
        }

        CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let baseAddress = CVPixelBufferGetBaseAddress(unwrappedPixelBuffer)
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]
        let context = CGContext(
            data: baseAddress,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(unwrappedPixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        )

        guard let unwrappedContext = context, let cgImage = image.cgImage else {
            CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }

        unwrappedContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))

        CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: unwrappedPixelBuffer)
        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: screenShareFrameRotation, timeStampNs: timeStamp)
        return rtcVideoFrame
    }
    
    public func updateStartScreenShare(with appId: String) {
        LOG.debug("ScreenShare- start")
        screenShareStart(with: appId)
    }
    
    public func updateStopScreenShare(error:String = "") {
        LOG.debug("ScreenShare- stop with error \(error)")
        wormholeBufferListener?.stopListeningForMessage(withIdentifier:  JMScreenShareManager.MediaSoupScreenShareId)
        
        if userState.selfScreenShareEnabled{
            socketEmitCloseProducer(for: userState.selfScreenShareProducerId)
        }
        screenShareProducer = nil
        userState.disableSelfScreenShare()
    }
    
    public func handleAudioOnlyModeForScreenShare() {
        if userState.remoteScreenShareEnabled {
            feedHandler(!isAudioOnlyModeEnabled, remoteId: userState.remoteScreenShareRemoteId, mediaType: .shareScreen)
       }
   }
}

extension JMManagerViewModel{
    func addOrientationObserver(){
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func removeOrientationObserver(){
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func orientationChanged() {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            screenShareFrameRotation = ._0
            LOG.debug("ScreenShare- Rotation changed to portrait (0)")
        case .portraitUpsideDown:
            screenShareFrameRotation = ._180
            LOG.debug("ScreenShare- Rotation changed to portraitUpsideDown (180)")
        case .landscapeLeft:
            screenShareFrameRotation = ._270
            LOG.debug("ScreenShare- Rotation changed to landscapeLeft (270)")
        case .landscapeRight:
            screenShareFrameRotation = ._90
            LOG.debug("ScreenShare- Rotation changed to landscapeRight (90)")
        default:
            LOG.debug("ScreenShare- Ignore rotation \(orientation)")
            break
        }
    }
    
    func getDeviceResolution(){
        let screenSize = UIScreen.main.bounds.size
        
        //FUTURE REF
//        let screenScale = UIScreen.main.scale
//        let screenWidthPixels = screenSize.width * screenScale
//        let screenHeightPixels = screenSize.height * screenScale
//        LOG.debug("ScreenShare- Screen size (Pixels) with scale \(screenScale): \(screenWidthPixels)*\(screenHeightPixels)")

        LOG.debug("ScreenShare- Screen size (Points): \(screenSize.width)*\(screenSize.height)")
        JioMediaStackDefaultScreenShareCaptureResolution.width = Int32(screenSize.width)
        JioMediaStackDefaultScreenShareCaptureResolution.height = Int32(screenSize.height)
    }
}

//MARK: ScreenShare
extension JMManagerViewModel{
    func socketScreenShareCloseProducer(producerId: String) {
        var parameters = JioSocketProperty.getProducerProperty(with: producerId)
        parameters[SocketDataKey.appData.rawValue] = ["share":true]
        self.jioSocket?.emit(action: .closeProducer, parameters: parameters)
    }
    func socketScreenShareResumeProducer(producerId: String) {
        //TODO: future scope
    }
}


//MARK: ScreenShare UI Container Rendering
extension JMManagerViewModel:UIScrollViewDelegate{
    
    func addRemoteScreenShareRenderView(_ renderView: UIView, remoteId: String){
        if var updatedPeer = self.peersMap[remoteId],
           let consumer = updatedPeer.consumerScreenShare,
           let rtcVideoTrack = consumer.track as? RTCVideoTrack
        {
            updatedPeer.remoteScreenshareView = bindScreenShareRenderViewAndTrack(rtcVideoTrack, renderView: renderView)
            peersMap[remoteId] = updatedPeer
        }
    }
    
    func removeRemoteShareViews(_ view: UIView?) {
        qJMMediaMainQueue.async {
            if let remoteShareView = view{
                for subviewRtc in remoteShareView.subviews where subviewRtc is RTCMTLVideoView {
                    subviewRtc.removeFromSuperview()
                }
            }
        }
    }
    
    func updateRemoteScreenShareRenderViewTrack(for remoteId: String){
        if var updatedPeer = self.peersMap[remoteId],
           let renderView = updatedPeer.remoteScreenshareView,
           let consumer = updatedPeer.consumerScreenShare,
           let rtcVideoTrack = consumer.track as? RTCVideoTrack
            
        {
            qJMMediaMainQueue.async {
                for subview in renderView.subviews where subview is RTCMTLVideoView{
                    subview.removeFromSuperview()
                }
                updatedPeer.remoteScreenshareView = self.bindScreenShareRenderViewAndTrack(rtcVideoTrack, renderView: renderView)
            }
            
            peersMap[remoteId] = updatedPeer
            LOG.info("Subscribe- UI success")
        }
//        else{
//            LOG.error("Subscribe- UI failed - \( self.peersMap[remoteId]?.remoteScreenshareView)|\( self.peersMap[remoteId]?.consumerScreenShare)|\( self.peersMap[remoteId]?.consumerScreenShare?.track)")
//        }
    }
    
    private func bindScreenShareRenderViewAndTrack(_ rtcVideoTrack: RTCVideoTrack, renderView: UIView) -> UIView{
        let remoteView = RTCMTLVideoView()
        rtcVideoTrack.add(remoteView)
        remoteView.videoContentMode = .scaleAspectFit
        rtcVideoTrack.isEnabled = true
        renderView.addSubview(remoteView)
        renderView.contentMode = .scaleAspectFit
        setConstrainsts(of: remoteView, toView: renderView)
        return renderView
    }
}
