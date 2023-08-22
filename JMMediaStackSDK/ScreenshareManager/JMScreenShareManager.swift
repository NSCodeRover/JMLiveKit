import Foundation
import AVFoundation
import MMWormhole

public class JMScreenShareManager {
    static let wormhole = MMWormhole(applicationGroupIdentifier: appGroupIdentifierEX, optionalDirectory: "wormhole")
    public static var MediaSoupScreenShareId = "MediaSoupScreenShare"
    public static var ScreenShareState = "ScreenShareState"
    
    public static var appGroupIdentifier: String {
        get {
            let id = Bundle.main.bundleIdentifier!
            return "group.\(id)"
        }
    }
    
    public static var appGroupIdentifierEX: String {
         get {
             let id = Bundle.main.bundleIdentifier!
             if let range = id.range(of: ".", options: .backwards) {
                 let updatedString = String(id[..<range.lowerBound])
                 let finalString = "group.\(updatedString)"
                 return finalString
             }
             return "group.\(id)"
         }
    }

    public static func sendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let dataSample = convertSampleBufferToImageData(sampleBuffer: sampleBuffer) {
            let timestamp = Int64(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value) * 1000
            let object = ["buffer": dataSample as Any, "timeStamp": timestamp] as [String: Any]
            wormhole.passMessageObject(object as NSCoding?, identifier: MediaSoupScreenShareId)
        }
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

