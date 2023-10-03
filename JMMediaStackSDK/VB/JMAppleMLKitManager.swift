//
//  JMAppleMLKitManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 03/10/23.
//

import Foundation

import Vision
import CoreImage

@available(iOS 15.0, *)
class JMAppleMLKitManager: NSObject {
    
    public static let shared = JMAppleMLKitManager()
    private override init() {}
    
    private let segmenter: VNGeneratePersonSegmentationRequest = {
        let segmenter = VNGeneratePersonSegmentationRequest()
        segmenter.qualityLevel = .balanced
        segmenter.outputPixelFormat = kCVPixelFormatType_OneComponent8
        
        return segmenter
    }()
    
    private var ciContext = CIContext(options: nil)
    
    func getMask(for framePixelBuffer: CVPixelBuffer) -> CVPixelBuffer?{

        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer)
        guard let originalCG = ciContext.createCGImage(originalImage, from: originalImage.extent)
        else {
            LOG.error("VB- AppleML- failed to convert into CGImage")
            return nil
        }
        
        let handler = VNImageRequestHandler(cgImage: originalCG)
        do{
            try handler.perform([segmenter])
        }
        catch(let error){
            LOG.error("VB- AppleML- failed to perform with error: \(error)")
            return nil
        }

        guard let maskPixelBuffer = segmenter.results?.first?.pixelBuffer else { return nil }
        return maskPixelBuffer
    }
}
