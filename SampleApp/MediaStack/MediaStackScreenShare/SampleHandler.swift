//
//  SampleHandler.swift
//  MediaStackScreenShare
//
//  Created by Onkar Dhanlobhe on 21/06/23.
//

import ReplayKit
import CoreVideo
import JMMediaStackSDK
import MMWormhole


class SampleHandler: RPBroadcastSampleHandler {
    
    let screenShareBufferListen = MMWormhole(applicationGroupIdentifier: JMScreenShareManager.appGroupIdentifierEX, optionalDirectory: "wormhole")
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) { JMScreenShareManager.sendScrenshareState(.ScreenShareStateStarting)
        screenShareBufferListen.listenForMessage(withIdentifier: "StopScreen") { message in
            let userInfo = [NSLocalizedFailureReasonErrorKey: "failed to broadcast because...."]

            self.finishBroadcastWithError( NSError(domain: "ScreenShare", code: -1, userInfo: userInfo))
        }

    }
    override func broadcastPaused() {JMScreenShareManager.sendScrenshareState(.ScreenShareStatePause)}
    override func broadcastResumed() {JMScreenShareManager.sendScrenshareState(.ScreenShareStateResume)}
    override func broadcastFinished() {JMScreenShareManager.sendScrenshareState(.ScreenShareStateStopping)}
    override func finishBroadcastWithError(_ error: Error) {
        print(error)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        
        switch sampleBufferType {
            
        case RPSampleBufferType.video:
            JMScreenShareManager.sendSampleBuffer(sampleBuffer)
            break
            
        case RPSampleBufferType.audioApp:
            break
        case RPSampleBufferType.audioMic:
            break
        @unknown default:
            fatalError("Unknown type of sample buffer")
        }
    }

}


//OTHER CONVERSIONS-----------------------------------------------








/*
 
 
 override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
     switch sampleBufferType {
     case RPSampleBufferType.video:
//            if let data = extractCVImageBuffer(from: sampleBuffer) {
//                let dataN = convertCVImageBufferToData(imageBuffer: data)
//                wormhole.passMessageObject(dataN as NSCoding?, identifier: "MediaSoupScreenShare")
//            }
         let dataSample = convertSampleBufferToUIImage(sampleBuffer: sampleBuffer)
         wormhole.passMessageObject(dataSample as NSCoding?, identifier: "MediaSoupScreenShare")
        // let imgDataForFrame = sampleBufferToData(sampleBuffer: sampleBuffer)!
         //let imgDataForFrame = sampleBufferToData(sampleBuffer: sampleBuffer)!
         
         break
     case RPSampleBufferType.audioApp:
         // Handle audio sample buffer for app audio
         break
     case RPSampleBufferType.audioMic:
         // Handle audio sample buffer for mic audio
         break
     @unknown default:
         // Handle other sample buffer types
         fatalError("Unknown type of sample buffer")
     }
 }
 
 
 func convertSampleBufferToUIImage(sampleBuffer: CMSampleBuffer) -> NSData? {


        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }


        // Create a Core Graphics image from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        // Create a CIContext
        let context = CIContext(options: nil)

        // Create a CGImage from the CIImage
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // Create a UIImage from the CGImage
        let uiImage = UIImage(cgImage: cgImage)

//        guard let imageData = uiImage.pngData() else {
//            return nil
//        }
//
        // Alternatively, you can use JPEG representation
        let imageData = uiImage.jpegData(compressionQuality: 1.0)!

        return NSData(data: imageData)
        //        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        //
        //        let width = CVPixelBufferGetWidth(imageBuffer)
        //        let height = CVPixelBufferGetHeight(imageBuffer)
        //        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        //        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        //
        //        let colorSpace = CGColorSpaceCreateDeviceRGB()
        //        let bitmapInfo: CGBitmapInfo = [
        //            .byteOrderDefault,
        //               CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        //           ]
        //
        //        guard let context = CGContext(data: baseAddress,
        //                                      width: width,
        //                                      height: height,
        //                                      bitsPerComponent: 12,
        //                                      bytesPerRow: bytesPerRow,
        //                                      space: colorSpace,
        //                                      bitmapInfo: bitmapInfo.rawValue) else {
        //            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        //            return nil
        //        }
        //
        //        guard let cgImage = context.makeImage() else {
        //            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        //            return nil
        //        }
        //
        //        let image = UIImage(cgImage: cgImage)
        //
        //        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

    }
 
 func sampleBufferToData(sampleBuffer: CMSampleBuffer) -> Data? {
     guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
         return nil
     }

     var length = 0
     var dataPointer: UnsafeMutablePointer<Int8>?
     if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) != noErr {
         return nil
     }

     let data = Data(bytes: dataPointer!, count: length)
     return data
 }
 
 
 func extractCVImageBuffer(from sampleBuffer: CMSampleBuffer) -> CVImageBuffer? {
     guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
         return nil
     }
     
     // Lock the base address of the image buffer
     CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
     
     // You can access the image buffer's data using CVPixelBufferGetBaseAddress and its properties like width, height, etc.
     let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
     let width = CVPixelBufferGetWidth(imageBuffer)
     let height = CVPixelBufferGetHeight(imageBuffer)
     
     // Process the image buffer or extract data as needed
     
     // Unlock the base address of the image buffer
     CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
     
     return imageBuffer
 }


 func convertCVImageBufferToData(imageBuffer: CVImageBuffer) -> Data? {
     CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

     let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
     let dataSize = CVPixelBufferGetDataSize(imageBuffer)

     let data = Data(bytes: baseAddress!, count: dataSize)

     CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

     return data
 }
 
 func setOrientationFromBuffer(_ sampleBuffer: CMSampleBuffer) {
     if #available(iOS 11.0, *) {
         if let orientationNumber = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
             let orientation = CGImagePropertyOrientation(rawValue: orientationNumber.uint32Value)
            // self.orientation = orientation
         }
     }
 }
 
 
 func getCIImageFromCVPixelBuffer(_ pixelBuffer: CVPixelBuffer, with width: CGFloat, height: CGFloat, originX: CGFloat, splitWidth: CGFloat) -> CIImage? {
     let leftPadding: CGFloat = (originX == 0) ? splitWidth : 0

     let isLandscape = (orientation == .left) || (orientation == .right)

     let leftPaddingW = isLandscape ? 0 : leftPadding
     var leftPaddingH: CGFloat = 0

     if (orientation == .right) && (originX != 0) {
         leftPaddingH = splitWidth
     }

     let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
     let cropRect = CGRect(x: leftPaddingW, y: leftPaddingH, width: width, height: height)

     let croppedImage = ciImage.cropped(to: cropRect)

     let transTrans = CGAffineTransform(translationX: -leftPaddingW, y: -leftPaddingH)
     var finalImage = croppedImage.transformed(by: transTrans)

     if orientation == .up {
         return finalImage
     }

     if #available(iOS 11.0, *) {
         var or: CGImagePropertyOrientation = CGImagePropertyOrientation(rawValue: orientation!.rawValue) ?? CGImagePropertyOrientation.down

         if orientation == .left {
             or = .right
         } else if orientation == .right {
             or = .left
         }

        let transformOr = croppedImage.orientationTransform(forExifOrientation: Int32(or.rawValue))

         finalImage = croppedImage.transformed(by: transformOr)
     }

     return finalImage
 }

 func getCIImage(from pixelBuffer: CVPixelBuffer, with width: CGFloat, height: CGFloat, originX: CGFloat, splitWidth: CGFloat) -> CIImage? {
     let leftPadding = (originX == 0) ? splitWidth : 0
     let isLandscape = (orientation == .left) || (orientation == .right)
     let leftPaddingW = isLandscape ? 0 : leftPadding
     var leftPaddingH: CGFloat = 0
     
     if (orientation == .right) && (originX != 0) {
         leftPaddingH = splitWidth
     }
     
     let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
     let cropRect = CGRect(x: leftPaddingW, y: leftPaddingH, width: width, height: height)
     var croppedImage = ciImage.cropped(to: cropRect)
     let transTrans = CGAffineTransform(translationX: -leftPaddingW, y: -leftPaddingH)
     croppedImage = croppedImage.transformed(by: transTrans)
     
     if orientation == .up {
         return croppedImage
     }
     
     var finalImage = croppedImage
     
     if #available(iOS 11.0, *) {
         var or = orientation
         
         if orientation == .left {
             or = .right
         } else if orientation == .right {
             or = .left
         }
         
         let transformOr = croppedImage.orientationTransform(forExifOrientation: Int32(or!.rawValue))
         finalImage = croppedImage.transformed(by: transformOr)
     }
     
     return finalImage
 }

 func makeCVPixelBuffer(with image: CIImage, width: CGFloat, height: CGFloat) -> CVPixelBuffer? {
     var pixelBuffer: CVPixelBuffer?
     let pixelBufferAttributes = [
         kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
         kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
     ] as CFDictionary

     let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_32ARGB, pixelBufferAttributes, &pixelBuffer)
     guard status == kCVReturnSuccess else {
         return nil
     }

     CVPixelBufferLockBaseAddress(pixelBuffer!, .readOnly)
     let ciContext = CIContext()
     ciContext.render(image, to: pixelBuffer!)
     CVPixelBufferUnlockBaseAddress(pixelBuffer!, .readOnly)

     return pixelBuffer
 }

 func saveInfoToSharedUsedDefaultWidth(_ width: size_t, height: size_t, size: size_t) {
     let w = Int(width)
     let h = Int(height)
     let s = Int(size)
     sharedDefaults?.set(w, forKey: "width")
     sharedDefaults?.set(h, forKey: "height")
     sharedDefaults?.set(s, forKey: "size")
     sharedDefaults?.synchronize()
 }



 func getBuffer(with sampleBuffer: CMSampleBuffer) -> Data? {
     setOrientationFromBuffer(sampleBuffer)
     
     guard let oldPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
         return nil
     }
     CVPixelBufferLockBaseAddress(oldPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
     
     let splitWidth = 44//sharedDefaults?.integer(forKey: "splitWidth")
     let originX = 0//sharedDefaults?.integer(forKey: "originX")
     
     let isLandscape = (orientation == .left) || (orientation == .right)
     var bufferWidth = CGFloat(CVPixelBufferGetWidth(oldPixelBuffer))
     var bufferHeight = CGFloat(CVPixelBufferGetHeight(oldPixelBuffer))
     
     if isLandscape {
         bufferHeight -= CGFloat(splitWidth)
     } else {
         bufferWidth -= CGFloat(splitWidth)
     }
     
     let outImage = getCIImage(from: oldPixelBuffer, with: bufferWidth, height: bufferHeight, originX: CGFloat(originX ?? 0), splitWidth: CGFloat(splitWidth ?? 0))!
     
     CVPixelBufferUnlockBaseAddress(oldPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
     
     if isLandscape {
         let bufferTempWidth = bufferWidth
         bufferWidth = bufferHeight
         bufferHeight = bufferTempWidth
     }
     
     guard let pixelBuffer = makeCVPixelBuffer(with: outImage, width: bufferWidth, height: bufferHeight) else {
         return nil
     }
     CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
     
     let size = (CVPixelBufferGetHeightOfPlane(pixelBuffer, 1) * CVPixelBufferGetWidthOfPlane(pixelBuffer, 1) * 2)
         + (CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) * CVPixelBufferGetWidthOfPlane(pixelBuffer, 0))
     let width = CVPixelBufferGetWidth(pixelBuffer)
     let height = CVPixelBufferGetHeight(pixelBuffer)
     saveInfoToSharedUsedDefaultWidth(width, height: height, size: size)
     
     let finalBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
     var finalBufferPtr = finalBuffer
     
     let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
     
     for i in 0..<planeCount {
         guard let planeBuff = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i) else {
             continue
         }
         
         let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i)
         let planeWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, i)
         let planeHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, i)
         
         let bytesSize = planeWidth * (i + 1)
         
         for j in 0..<planeHeight {
             let sourceAddress = planeBuff + bytesPerRow * j
             memcpy(finalBufferPtr, sourceAddress, bytesSize)
             finalBufferPtr += bytesSize
         }
     }
     
     let data = Data(bytesNoCopy: finalBuffer, count: size, deallocator: .free)
     CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
     
     return data
 }




 */
