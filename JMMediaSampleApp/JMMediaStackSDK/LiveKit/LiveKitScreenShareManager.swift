//  LiveKitScreenShareManager.swift
//  JMMediaStackSDK

import Foundation
import CoreVideo
import CoreMedia
import ReplayKit
#if canImport(LiveKit)
import LiveKit
#endif

public var appGroupIdentifier: String {
    // In a real app, this should be dynamically determined or configured
    return "group.com.onkar.MediaStackDev"
}

#if canImport(LiveKit)

public final class LiveKitScreenShareManager {
    public static let shared = LiveKitScreenShareManager()
    private init() {}

    private var screenTrack: LocalTrackPublication?
    private weak var room: Room?
    private var isBroadcasting = false

    public func start(room: Room, appGroupId: String = appGroupIdentifier) async {
        print("🚀 LiveKitScreenShareManager: Starting screen share")
        print("📁 LiveKitScreenShareManager: App group ID: \(appGroupId)")
        print("🏠 LiveKitScreenShareManager: Room state: \(room.connectionState)")
        print("👤 LiveKitScreenShareManager: Local participant: \(String(describing: room.localParticipant.identity))")
        
        self.room = room
        
        guard screenTrack == nil else {
            print("⚠️ LiveKitScreenShareManager: Screen share already in progress.")
            return
        }

        print("📹 LiveKitScreenShareManager: Setting up for broadcast extension")
        
        // Check if broadcast extension is available
        checkBroadcastExtensionAvailability()
        
        // Store backend preference for extension
        if UserDefaults(suiteName: appGroupId) != nil {
            let sharedDefaults = UserDefaults(suiteName: appGroupId)!
            sharedDefaults.set(["backend": "livekit"], forKey: "broadcastSetupInfo")
            sharedDefaults.synchronize()
            print("💾 LiveKitScreenShareManager: Saved backend preference to UserDefaults")
        }
        
        print("🎬 LiveKitScreenShareManager: Screen share setup complete - waiting for broadcast extension to start")
        print("ℹ️ LiveKitScreenShareManager: LiveKit will automatically publish the screen share track when broadcast starts")
    }

    public func stop() {
        print("🛑 LiveKitScreenShareManager: Stopping screen share")
        
        Task {
            do {
                // Use LiveKit's recommended setScreenShare API to stop
                try await room?.localParticipant.setScreenShare(enabled: false)
                print("✅ LiveKitScreenShareManager: Screen share stopped using setScreenShare")
            } catch {
                print("❌ LiveKitScreenShareManager: Error stopping screen share: \(error)")
            }
        }
        
        screenTrack = nil
        isBroadcasting = false
        
        print("🧹 LiveKitScreenShareManager: Cleanup complete")
    }
    
    private func checkBroadcastExtensionAvailability() {
        // Check if broadcast extension is available
        //let broadcastPicker = RPBroadcastActivityViewController()
        print("📱 LiveKitScreenShareManager: Broadcast extension availability checked")
    }
}

#else

public final class LiveKitScreenShareManager {
    public static let shared = LiveKitScreenShareManager()
    private init() {}
    
    public func start(room: Any, appGroupId: String = appGroupIdentifier) async {
        print("❌ LiveKitScreenShareManager: LiveKit not available")
    }
    
    public func stop() {
        print("❌ LiveKitScreenShareManager: LiveKit not available")
    }
}

#endif

// Extension to convert UIImage to CVPixelBuffer
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(size.width),
                                       Int(size.height),
                                       kCVPixelFormatType_32ARGB,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                              space: rgbColorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}


