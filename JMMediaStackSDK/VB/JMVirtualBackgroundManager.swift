//
//  JMVirtualBackgroundManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 27/09/23.
//

import Foundation

extension Bundle {
    static let resources: Bundle = {
        let bundle = Bundle(for: BundleToken.self)
        let path = bundle.path(forResource: "JMResources", ofType: "bundle")
        return Bundle(path: path!)!
    }()
}
private class BundleToken {}

class JMVirtualBackgroundManager: NSObject {

    private var jmVBHelper: JMVirtualBackgroundHelper?
    private var rateLimiter: RateLimiter?
    
    private var blurRadius: CGFloat?
    private var coreBackgroundImage: CIImage?
    private var backgroundImage: UIImage? {
        didSet {
            if let cgImage = backgroundImage?.cgImage {
                LOG.debug("Video- VB- image ready")
                coreBackgroundImage = CIImage(cgImage: cgImage)
            }
            else {
                LOG.debug("Video- VB- no image")
                coreBackgroundImage = nil
            }
        }
    }

    public init(backgroundImage: UIImage?, fps: Int32, blurRadius: NSNumber? = nil) {
        self.backgroundImage = backgroundImage
        self.blurRadius = blurRadius != nil ? CGFloat(blurRadius!.doubleValue) : nil
        self.rateLimiter = {.init(limit: 1/Double(fps))}()
        self.jmVBHelper = JMVirtualBackgroundHelper()
        
        super.init()
        
        // This defer is to make didSet get triggered for backgroundImage from init
        defer {
            self.backgroundImage = backgroundImage
        }
    }

    public func process(buffer: CVPixelBuffer) -> CVPixelBuffer {
        let processedPixelBuffer = jmVBHelper?.replaceBackground(in: buffer,with: coreBackgroundImage,blurRadius: blurRadius ?? 10,
        shouldSkip: {
            return !(rateLimiter?.shouldFeed() ?? false)
        })
        return processedPixelBuffer ?? buffer
    }
    
    public func dispose(){
        backgroundImage = nil
        coreBackgroundImage = nil
        
        jmVBHelper?.dispose()
        rateLimiter?.dispose()
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
