import Foundation
import AVFoundation
import CoreImage
import UIKit
@_implementationOnly import JMMMWormhole

public class JMScreenShareManager {
    static var wormhole = MMWormhole(applicationGroupIdentifier: appId, optionalDirectory: "wormhole")
    static let desiredFps = 5.0
    static var lastFrameTimestamp: CMTime = CMTime.zero
    
    public static var MediaSoupScreenShareId = "MediaSoupScreenShare"
    public static var ScreenShareState = "ScreenShareState"
    public static var appId: String = "group.\(Bundle.main.bundleIdentifier!)"
    {
        didSet{
            wormhole = MMWormhole(applicationGroupIdentifier: appId, optionalDirectory: "wormhole")
        }
    }
    
    public static func sendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        
        if !validateBufferForDesiredFrameRate(sampleBuffer){
            return
        }
        
        if let dataSample = convertSampleBufferToImageData(sampleBuffer: sampleBuffer) {
            let timestamp = Int64(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value) * 1000
            let object = ["buffer": dataSample as Any, "timeStamp": timestamp] as [String: Any]
            wormhole.passMessageObject(object as NSCoding?, identifier: MediaSoupScreenShareId)
        }
    }
    
    private static func validateBufferForDesiredFrameRate(_ sampleBuffer: CMSampleBuffer) -> Bool{
        let currentTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delta = CMTimeSubtract(currentTimestamp, lastFrameTimestamp).seconds
        let threshold = Double(1.0/desiredFps)
        guard delta > threshold else { return false }
        lastFrameTimestamp = currentTimestamp
        return true
    }

    private static func convertSampleBufferToImageData(sampleBuffer: CMSampleBuffer) -> NSData? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        let imageData = uiImage.jpegData(compressionQuality: 1.0)!
        return NSData(data: imageData)
    }
}

//Future reference - IF we want to handle all the state of screenshare broadcasting, use below states.

extension JMScreenShareManager {
    public static func sendScrenshareState(_ state: JMScreenShareState) {
        wormhole.passMessageObject(state.rawValue as NSCoding, identifier: ScreenShareState)
    }
}
public enum JMScreenShareState: String {
    case ScreenShareStatePause = "ScreenShareStatePause"
    case ScreenShareStateStarting = "ScreenShareStateStarting"
    case ScreenShareStateResume = "ScreenShareStateResume"
    case ScreenShareStateStopping = "ScreenShareStateStopping"
    case ScreenShareStateError = "ScreenShareStateError"
}

