//
//  JMMLKitManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 29/09/23.
//

import Foundation
import AVFoundation

import MLKitSegmentationCommon
import MLKitSegmentationSelfie
import MLKitVision

class JMGoogleMLKitManager: NSObject {
    
    public static let shared = JMGoogleMLKitManager()
    private override init() {}
    
    private var segmenter: Segmenter?
    
    func setupSession(){
        let options = SelfieSegmenterOptions()
        options.segmenterMode = .stream
        options.shouldEnableRawSizeMask = true
        segmenter = Segmenter.segmenter(options: options)
        
        LOG.info("Video- VB- JMVirtualBackgroundManager configured with Google MLKit.")
    }
    
    func dispose(){
        segmenter = nil
    }
    
    func getMask(for sampleBuffer: CMSampleBuffer) -> CVPixelBuffer?{
        
        let image = VisionImage(buffer: sampleBuffer)
        //image.orientation = imageOrientation(deviceOrientation: UIDevice.current.orientation,cameraPosition: .front)

        var mask: SegmentationMask?
        do {
            mask = try segmenter?.results(in: image)
        }
        catch let error {
            LOG.error("VB- ML- Failed to perform segmentation with error: \(error.localizedDescription).")
        }

        return mask?.buffer
    }
}

//MARK: Helpers
extension JMGoogleMLKitManager{
    func convertPixelToBuffer(_ framePixelBuffer: CVPixelBuffer) -> CMSampleBuffer?{
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = CMTime.zero
        info.duration = CMTime.invalid
        info.decodeTimeStamp = CMTime.invalid

        var formatDesc: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: framePixelBuffer, formatDescriptionOut: &formatDesc)

        var sampleBuffer: CMSampleBuffer? = nil
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: framePixelBuffer,
                                                 formatDescription: formatDesc!,
                                                 sampleTiming: &info,
                                                 sampleBufferOut: &sampleBuffer);
        
        return sampleBuffer
    }
    
    //NOT IN USE
    func imageOrientation(deviceOrientation: UIDeviceOrientation, cameraPosition: AVCaptureDevice.Position) -> UIImage.Orientation
    {
        switch deviceOrientation {
        case .portrait:
          return cameraPosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
          return cameraPosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
          return cameraPosition == .front ? .rightMirrored : .left
        case .landscapeRight:
          return cameraPosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
          return .up
        }
    }
}
