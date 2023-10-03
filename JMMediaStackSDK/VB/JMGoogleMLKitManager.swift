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
    
    private let segmenter: Segmenter = {
        let options = SelfieSegmenterOptions()
        options.segmenterMode = .stream
        options.shouldEnableRawSizeMask = true

        let segmenter = Segmenter.segmenter(options: options)
        return segmenter
    }()
    
    func getMask(for sampleBuffer: CMSampleBuffer) -> CVPixelBuffer?{
        
        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = imageOrientation(
          deviceOrientation: UIDevice.current.orientation,
          cameraPosition: .front)

        var mask: SegmentationMask?
        do {
            mask = try segmenter.results(in: image)
        }
        catch let error {
            LOG.error("VB- ML- Failed to perform segmentation with error: \(error.localizedDescription).")
        }

        // Get the pixel buffer that contains the mask image.
        return mask?.buffer
    }
    
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
