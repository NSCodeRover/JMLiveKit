//
//  JMCameraCapturer.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 07/11/23.
//

import Foundation

import WebRTC

public protocol previewDelegate{
    func onError(error: JMMediaError)
    func onLogMessage(message: String)
}
extension previewDelegate{
    func onLogMessage(message: String){}
}

public class JMPreviewManager: NSObject{

    var videoCapture:RTCCameraVideoCapturer?
    
    var videoSelfRenderView:UIView?
    var videoSelfRTCRenderView: RTCMTLVideoView?
    
    let qJMMediaMainQueue: DispatchQueue = DispatchQueue.main
    let qJMMediaVBQueue: DispatchQueue = DispatchQueue(label: "jmmedia.vb",qos: .default)
    
    var isVirtualBackgroundEnabled: Bool = false
    var virtualBackgroundManager: JMVirtualBackgroundManager?
    
    var delegate: previewDelegate?
    public init(withView view: UIView, delegate: previewDelegate? = nil) {
        super.init()
        
        self.delegate = delegate
        JMVideoDeviceManager.shared.setupSession()
        setupCapturer(with: view)
    }
}

extension JMPreviewManager{
    
    public func enablePreview(isEnabled: Bool){
        log("Preview- enablePreview \(isEnabled)")
        
        if isEnabled{
            setupCapturer()
            startCapture()
        }
        else{
            dispose()
        }
        
        enableLocalRenderView(isEnabled)
    }
    
    @available(iOS 15.0, *)
    public func enableVirtualBackground(_ isEnabled: Bool, withOption option: JMVirtualBackgroundOption){
        log("Preview- VB- Virtual background enabled \(isEnabled)")
        
        if isEnabled{
            initVirtualBackground()
            virtualBackgroundManager?.enableVirtualBackground(option: option)
        }
        else {
            disposeVirtualBackground()
        }
        
        isVirtualBackgroundEnabled = isEnabled
    }
    
    internal func onError(error: JMMediaError){
        qJMMediaMainQueue.async {
            self.delegate?.onError(error: error)
        }
    }
    
    internal func log(_ message: String){
        print(message)
        qJMMediaMainQueue.async {
            self.delegate?.onLogMessage(message: message)
        }
    }
}

extension JMPreviewManager{
    
    internal func stopCapture(){
        videoCapture?.stopCapture()
    }
    
    internal func setupCapturer(with view: UIView? = nil){
        if videoCapture == nil {
            self.videoCapture = RTCCameraVideoCapturer(delegate: self)
        }
        
        if let renderView = view, videoSelfRenderView == nil{
            addLocalRenderView(renderView)
        }
        
        if let rtcview = videoSelfRTCRenderView, rtcview.isHidden{
            enableLocalRenderView(true)
        }
    }
    
    internal func dispose(){
        videoCapture?.stopCapture()
        videoCapture = nil
        enableLocalRenderView(false)
    }
    
    internal func startCapture(){
        
        guard let cameraDevice = JMVideoDeviceManager.shared.getCameraDevice() else {
            log("Preview- No camera device found")
            onError(error: JMMediaError.init(type: .cameraNotAvailable, description: "No camera device found"))
            return
        }
        
        let fps = JioMediaStackDefaultCameraCaptureResolution.fps
        guard let format = JMVideoDeviceManager.shared.fetchPreferredResolutionFormat(cameraDevice) else {
            log("Preview- No format found")
            onError(error: JMMediaError.init(type: .videoDeviceNotSupported, description: "No format found \(cameraDevice.localizedName)"))
            return
        }
        
        log("Preview- start capture")
        self.videoCapture?.startCapture(with: cameraDevice, format:format, fps: Int(fps))
    }

}

extension JMPreviewManager{
    func addLocalRenderView(_ renderView: UIView){
        log("Preview- local renderview ready")
        self.videoSelfRenderView = renderView
        
        qJMMediaMainQueue.async {
            let localView = RTCMTLVideoView()
            renderView.addSubview(localView)
            self.setConstrainsts(of: localView, toView: renderView)
            self.videoSelfRTCRenderView = localView
        }
    }
    
    func enableLocalRenderView(_ isEnabled: Bool){
        log("Preview- update renderview ready")
        
        qJMMediaMainQueue.async {
            if let localView = self.videoSelfRenderView{
                for subviewRtc in localView.subviews where subviewRtc is RTCMTLVideoView {
                    subviewRtc.isHidden = !isEnabled
                }
            }
        }
    }
}

extension JMPreviewManager: RTCVideoCapturerDelegate{
    
    public func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {

        qJMMediaVBQueue.async {
            if self.isVirtualBackgroundEnabled{
                if let processedRTCVideoFrame = self.applyVirtualBackground(for: frame){
                        self.log("Preview- VB frame")
                        self.videoSelfRTCRenderView?.renderFrame(processedRTCVideoFrame)
                    return
                }
            }
            
            self.videoSelfRTCRenderView?.renderFrame(frame)
        }
    }
}

//Helper
extension JMPreviewManager{
    func setConstrainsts(of firstView:RTCMTLVideoView, toView: UIView){
        firstView.translatesAutoresizingMaskIntoConstraints = false
        firstView.leadingAnchor.constraint(equalTo: toView.leadingAnchor).isActive = true
        firstView.trailingAnchor.constraint(equalTo: toView.trailingAnchor).isActive = true
        firstView.topAnchor.constraint(equalTo: toView.topAnchor).isActive = true
        firstView.bottomAnchor.constraint(equalTo: toView.bottomAnchor).isActive = true
    }
}

//MARK: Virtual Background
extension JMPreviewManager{
    
    func initVirtualBackground(){
        if virtualBackgroundManager == nil{
            virtualBackgroundManager = JMVirtualBackgroundManager(fps: JioMediaStackDefaultCameraCaptureResolution.fps)
        }
    }
    
    func applyVirtualBackground(for frame: RTCVideoFrame) -> RTCVideoFrame?{
        if let frameBufferPixel = self.convertRTCVideoFrameToPixelBuffer(frame), let vbManager = self.virtualBackgroundManager{
            let processedframeBufferPixel = vbManager.process(buffer: frameBufferPixel)
            let processedRTCVideoFrame = self.convertPixelBufferToRTCVideoFrame(processedframeBufferPixel,rotation: frame.rotation, timeStamp: frame.timeStampNs)
            return processedRTCVideoFrame
        }
        
        log("VB- convertRTCVideoFrameToPixelBuffer failed")
        return nil
    }
    
    func disposeVirtualBackground(){
        if virtualBackgroundManager != nil{
            self.virtualBackgroundManager?.dispose()
            self.virtualBackgroundManager = nil
        }
    }
}

extension JMPreviewManager{
    func convertRTCVideoFrameToPixelBuffer(_ rtcVideoFrame: RTCVideoFrame) -> CVPixelBuffer? {
        guard let rtcPixelBuffer = rtcVideoFrame.buffer as? RTCCVPixelBuffer else {
            return nil
        }
        
        let pixelBuffer = rtcPixelBuffer.pixelBuffer
        return pixelBuffer
    }
    
    func convertPixelBufferToRTCVideoFrame(_ unwrappedPixelBuffer: CVPixelBuffer,rotation: RTCVideoRotation = ._0, timeStamp: Int64) -> RTCVideoFrame{
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: unwrappedPixelBuffer)
        
        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: rotation, timeStampNs: timeStamp)
        return rtcVideoFrame
    }
}
