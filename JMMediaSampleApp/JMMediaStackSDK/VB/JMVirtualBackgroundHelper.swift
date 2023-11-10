//
//  JMVirtualBackgroundHelper.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 29/09/23.
//

import Foundation
import AVFoundation
import UIKit

class JMVirtualBackgroundHelper: NSObject {
        
    private var ciContext = CIContext()
    private var previousBuffer: CVImageBuffer?
    private var _pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPool: CVPixelBufferPool! {
        get {
            if _pixelBufferPool == nil {
                var pixelBufferPool: CVPixelBufferPool?
                CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
                _pixelBufferPool = pixelBufferPool
            }
            return _pixelBufferPool!
        }
        set {
            _pixelBufferPool = newValue
        }
    }
    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else { return }
            pixelBufferPool = nil
        }
    }
    
    private static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferIOSurfacePropertiesKey : [:] as NSDictionary
    ]
    private var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = Self.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: Int(extent.width))
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: Int(extent.height))
        return attributes
    }
    
    func dispose(){
        previousBuffer = nil
        _pixelBufferPool = nil
        pixelBufferPool = nil
    }
    
    func replaceBackground(in framePixelBuffer: CVPixelBuffer,with backgroundType: JMVirtualBackgroundOption, backgroundImage: CIImage?, blurRadius: CGFloat?, backgroundColor: UIColor?, shouldSkip: ()->Bool) -> CVImageBuffer {
        
        guard !shouldSkip() else { return previousBuffer ?? framePixelBuffer }
        
        var maskPixelBuffer: CVPixelBuffer?
        if #available(iOS 15.0, *){
            maskPixelBuffer =  JMAppleMLKitManager.shared.getMask(for: framePixelBuffer) ?? previousBuffer ?? framePixelBuffer
        }

        guard let maskPixelBuffer = maskPixelBuffer
        else {
            LOG.error("VB- ML- maskPixelBuffer failed")
            return framePixelBuffer
        }

        //Blend the images and mask.
        return blend(original: framePixelBuffer, mask: maskPixelBuffer, backgroundType: backgroundType, backgroundImage: backgroundImage, blurRadius: blurRadius, backgroundColor: backgroundColor) ?? framePixelBuffer
    }
    
    private func blend(original framePixelBuffer: CVPixelBuffer, mask maskPixelBuffer: CVPixelBuffer,backgroundType: JMVirtualBackgroundOption, backgroundImage: CIImage? = nil, blurRadius: CGFloat?,backgroundColor: UIColor?) -> CVImageBuffer? {

        var imageBuffer: CVImageBuffer?
        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        // Scale the mask image to fit the bounds of the video frame.
        scaleToFit(image: &maskImage, originalImage: originalImage)

        // Create a clear colored background image.
        var background: CIImage
        if case .image = backgroundType, let backgroundImage = backgroundImage {
            background = backgroundImage.oriented(.left)
        }
        else if case .color = backgroundType, let backgroundColor = backgroundColor {
            background = CIImage(color: CIColor(color: backgroundColor))
        }
        else {
            background = originalImage.clampedToExtent()
                .applyingFilter(
                    "CIBokehBlur",
                    parameters: [
                        kCIInputRadiusKey: blurRadius ?? 15,
                    ]
                )
                .cropped(to: originalImage.extent)
        }

        // Scale the background image to fit the bounds of the video frame.
        scaleToFit(image: &background, originalImage: originalImage)

        // Blend the original, background, and mask images.
        let blendFilter = blendWithRedMask(inputImage: originalImage, inputBackgroundImage: background, inputMaskImage: maskImage)

        // Redner image to a new buffer.
        if let finalImage = blendFilter?.outputImage {
            extent = originalImage.extent
            imageBuffer = renderToBuffer(image: finalImage)
        }
        else{
            LOG.error("VB- ML- Blend failed")
        }

        previousBuffer = imageBuffer
        return imageBuffer
    }
    
    private func renderToBuffer(image: CIImage) -> CVImageBuffer? {
        var imageBuffer: CVImageBuffer?
        //extent = image.extent //This is breaking for color.

        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &imageBuffer)
        if let imageBuffer = imageBuffer {
            ciContext.render(image, to: imageBuffer)
        }
        return imageBuffer
    }

    private func scaleToFit(image: inout CIImage, originalImage: CIImage) {
        // Scale the image to fit the bounds of the video frame.
        let scaleX = originalImage.extent.width / image.extent.width
        let scaleY = originalImage.extent.height / image.extent.height
        image = image.transformed(by: .init(scaleX: scaleX, y: scaleY))
    }
    
    private func blendWithRedMask(inputImage: CIImage, inputBackgroundImage: CIImage, inputMaskImage: CIImage) -> CIFilter? {
        guard let filter = CIFilter(name: "CIBlendWithRedMask") else {
            return nil
        }
        filter.setDefaults()
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(inputBackgroundImage, forKey: kCIInputBackgroundImageKey)
        filter.setValue(inputMaskImage, forKey: kCIInputMaskImageKey)
        
        return filter
    }
}

class RateLimiter {
   private let limit: TimeInterval
   private var lastExecutedAt: Date?

   init(limit: TimeInterval) {
       self.limit = limit
   }
    
    func dispose(){
        lastExecutedAt = nil
    }

   func shouldFeed() -> Bool {
       let now = Date()
       let timeInterval = now.timeIntervalSince(lastExecutedAt ?? .distantPast)

       if timeInterval > limit {
           lastExecutedAt = now

           return true
       }

       return false
   }
}
