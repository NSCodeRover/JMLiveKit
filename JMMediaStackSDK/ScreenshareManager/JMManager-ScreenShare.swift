//
//  JMManager-ScreenShare.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 03/07/23.
//

import Foundation

import MMWormhole
import WebRTC

let wormholeBufferListener = MMWormhole(applicationGroupIdentifier: JMScreenShareManager.appGroupIdentifier, optionalDirectory: "wormhole")
extension JMManagerViewModel{
    
     func setSampleBufferwithTimestamp(_ messageObject: [String:Any]) {
        if let object: [String:Any] = messageObject as? [String:Any],
           let buffer = object["buffer"] as? Data,
           let timeStamp = object["timeStamp"] as? Int64{
            
            guard let frameNew = self.convertDataToRTCCVPixelBuffer(data: buffer, timeStamp: timeStamp)
            else {
                LOG.debug("ScreenShare- convertor failed")
                return
            }
            
            self.createScreenShareProducer()
            self.videoSourceScreen?.capturer(self.videoSourceScreenCapture!, didCapture: frameNew)
        }
    }
    
    func screenShareStart(){
        qJMMediaBGQueue.async {
            wormholeBufferListener.listenForMessage(withIdentifier: JMScreenShareManager.MediaSoupScreenShareId, listener: { (messageObject) -> Void in
                if let messageBuffer = messageObject as? [String:Any]{
                    self.setSampleBufferwithTimestamp(messageBuffer)
                }
            })
        }
    }
    
    func screenShareStop(){
        if let producerId = screenShareProducerID as? String{
            socketScreenShareCloseProducer(producerId: producerId)
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
        screenShareSource.adaptOutputFormat(toWidth: JioMediaStackDefaultScreenShareCaptureResolution.0, height: JioMediaStackDefaultScreenShareCaptureResolution.1, fps: JioMediaStackDefaultScreenShareCaptureResolution.2)
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
        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStamp)
        return rtcVideoFrame
    }
    
    public func updateStartScreenShare() {
        LOG.debug("ScreenShare- start")
        screenShareStart()
    }
    
    public func updateStopScreenShare(error:String = "") {
        LOG.debug("ScreenShare- stop with error \(error)")
        wormholeBufferListener.stopListeningForMessage(withIdentifier:  JMScreenShareManager.MediaSoupScreenShareId)
        socketCloseProducer(producerId: screenShareProducerID)
        screenShareProducer = nil
    }
    
    public func handleAudioOnlyModeForScreenShare() {
       if !subscriptionScreenShareVideo.isEmpty {
           feedHandler(!isAudioOnlyModeEnabled, remoteId: subscriptionScreenShareVideo, mediaType: .shareScreen)
       }
   }
}

//MARK: ScreenShare
extension JMManagerViewModel{
    func socketScreenShareCloseProducer(producerId: String) {
        var parameters = JioSocketProperty.getCloseProducerProperty(producerId: producerId)
        parameters[SocketDataKey.appData.rawValue] = ["share":true]
        self.jioSocket.emit(action: .closeProducer, parameters: parameters)
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
                for subview in remoteShareView.subviews where subview is UIScrollView {
                    for subviewRtc in subview.subviews where subviewRtc is RTCMTLVideoView {
                        subviewRtc.removeFromSuperview()
                    }
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
        let scrollView = UIScrollView(frame: renderView.bounds)
        let remoteView = RTCMTLVideoView(frame: renderView.bounds)
        rtcVideoTrack.add(remoteView)
        rtcVideoTrack.isEnabled = true
        scrollView.addSubview(remoteView)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.isUserInteractionEnabled = true
        remoteView.isUserInteractionEnabled = true
        renderView.addSubview(scrollView)
        return renderView
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        for subview in scrollView.subviews {
            if let remoteView = subview as? RTCMTLVideoView {
                return remoteView
            }
        }
        return nil
    }
}
