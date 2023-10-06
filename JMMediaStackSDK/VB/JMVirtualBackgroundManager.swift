//
//  JMVirtualBackgroundManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 27/09/23.
//

import Foundation
import UIKit
 
public enum JMVirtualBackgroundOption{
    case none
    case blur(intensity: JMVirtualBackgroundBlurIntensity)
    case image(data: Data)
    case color(color: UIColor)
}
public enum JMVirtualBackgroundBlurIntensity:Int{
    case low = 10
    case medium = 15
    case high = 25
}

class JMVirtualBackgroundManager: NSObject {

    private var jmVBHelper: JMVirtualBackgroundHelper?
    private var rateLimiter: RateLimiter?
    
    private var backgroundType: JMVirtualBackgroundOption = .none
    
    private var backgroundBlurRadius: CGFloat?
    private var backgroundColor: UIColor?
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
    private var coreBackgroundImage: CIImage?
    
    public init(fps: Int32) {
        self.rateLimiter = {.init(limit: 1/Double(fps))}()
        self.jmVBHelper = JMVirtualBackgroundHelper()
        
        if #available(iOS 15.0, *){
            JMAppleMLKitManager.shared.setupSession()
        }
        else{
            JMGoogleMLKitManager.shared.setupSession()
        }
        
        super.init()
    }

    public func process(buffer: CVPixelBuffer) -> CVPixelBuffer {
        let processedPixelBuffer = jmVBHelper?.replaceBackground(in: buffer, with: backgroundType, backgroundImage: coreBackgroundImage, blurRadius: backgroundBlurRadius, backgroundColor: backgroundColor, shouldSkip:{
            return !(rateLimiter?.shouldFeed() ?? false)
        })
        return processedPixelBuffer ?? buffer
    }
    
    public func dispose(){
        backgroundImage = nil
        coreBackgroundImage = nil
        backgroundColor = nil
        
        jmVBHelper?.dispose()
        rateLimiter?.dispose()
        
        if #available(iOS 15.0, *){
            JMAppleMLKitManager.shared.dispose()
        }
        else{
            JMGoogleMLKitManager.shared.dispose()
        }
    }
}

extension JMVirtualBackgroundManager{
    func enableVirtualBackground(option: JMVirtualBackgroundOption){
        backgroundType = option
        
        switch option {
        case .none:
            LOG.info("VB- Type set to NONE.")
            return
            
        case .color(let color):
            configureOptionForColor(for: color)
            
        case .blur(let intensity):
            configureOptionForBlur(withIntensity: intensity)
            
        case .image(let path):
            configureOptionForImage(from: path)
        }
    }
    private func configureOptionForColor(for color: UIColor){
        LOG.info("VB- Type set to color with \(color).")
        backgroundColor = color
    }
    
    private func configureOptionForBlur(withIntensity intensity: JMVirtualBackgroundBlurIntensity){
        LOG.info("VB- Type set to blur with intensity \(intensity).")
        backgroundBlurRadius = CGFloat(intensity.rawValue)
    }
    
    private func configureOptionForImage(from data: Data){
        LOG.info("VB- Type set to image.")
        if let image = UIImage(data: data){
            backgroundImage = image
        }
        else {
            LOG.error("VB- failed to fetch from data - \(data)")
        }
    }
}
