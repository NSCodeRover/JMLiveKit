import Foundation
import UIKit

// MARK: - Import Both WebRTC Engine Implementations
// Standard WebRTC Engine (RTC* classes v114.x) - handled in JMMediasoupEngine
// LiveKit WebRTC Engine (LKRTC* classes v125.x) - handled in JMLiveKitEngine

// MARK: - WebRTC Engine Type
public enum JMWebRTCEngineType {
    case mediasoup  // Uses standard WebRTC (RTC* classes)
    case livekit    // Uses LKRTC-prefixed WebRTC classes
}

// MARK: - Unified WebRTC Manager
@MainActor
public class JMWebRTCManager: ObservableObject {
    
    // MARK: - Properties
    @Published public private(set) var currentEngineType: JMWebRTCEngineType?
    @Published public private(set) var isEngineInitialized = false
    
    // Engine instances - lazy loaded to avoid conflicts
    private var mediasoupEngine: JMMediasoupEngine?
    private var livekitEngine: JMLiveKitEngine?
    
    // Thread safety
    private let engineQueue = DispatchQueue(label: "com.jm.webrtc.engine", qos: .userInitiated)
    private var isInitializing = false
    
    public static let shared = JMWebRTCManager()
    
    private init() {
        print("🔧 JMWebRTCManager: Initializing dual WebRTC stack manager")
    }
    
    deinit {
        Task {
            await cleanup()
        }
    }
    
    // MARK: - Engine Selection & Initialization
    
    /// Switches to Mediasoup engine (standard WebRTC RTC* classes)
    public func switchToMediasoup() async throws {
        guard currentEngineType != .mediasoup else {
            print("📺 JMWebRTCManager: Already using Mediasoup engine")
            return
        }
        
        try await switchEngine(to: .mediasoup)
    }
    
    /// Switches to LiveKit engine (LKRTC-prefixed WebRTC classes)
    public func switchToLiveKit() async throws {
        guard currentEngineType != .livekit else {
            print("📺 JMWebRTCManager: Already using LiveKit engine")
            return
        }
        
        try await switchEngine(to: .livekit)
    }
    
    private func switchEngine(to engineType: JMWebRTCEngineType) async throws {
        guard !isInitializing else {
            throw NSError(domain: "JMWebRTCError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Engine busy"])
        }
        
        isInitializing = true
        defer { isInitializing = false }
        
        print("🔄 JMWebRTCManager: Switching to \(engineType) engine")
        
        // Cleanup current engine
        await cleanup()
        
        // Initialize new engine
        switch engineType {
        case .mediasoup:
            if mediasoupEngine == nil {
                mediasoupEngine = JMMediasoupEngine()
            }
            try await mediasoupEngine?.initialize()
            
        case .livekit:
            if livekitEngine == nil {
                livekitEngine = JMLiveKitEngine()
            }
            try await livekitEngine?.initialize()
        }
        
        currentEngineType = engineType
        isEngineInitialized = true
        
        print("✅ JMWebRTCManager: Successfully switched to \(engineType) engine")
    }
    
    // MARK: - Unified Interface Methods
    
    public func joinRoom(roomId: String, serverUrl: String, token: String? = nil, displayName: String, audioEnabled: Bool = true, videoEnabled: Bool = true, enableDataChannel: Bool = false, engineType: JMWebRTCEngineType) async throws {
        
        // Switch engine if needed
        if currentEngineType != engineType {
            try await switchEngine(to: engineType)
        }
        
        // Prepare config
        let config: [String: Any] = [
            "serverUrl": serverUrl,
            "token": token as Any,
            "displayName": displayName,
            "audioEnabled": audioEnabled,
            "videoEnabled": videoEnabled,
            "enableDataChannel": enableDataChannel
        ]
        
        // Join room with selected engine
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.joinRoom(roomId: roomId, config: config)
        case .livekit:
            try await livekitEngine?.joinRoom(roomId: roomId, config: config)
        }
    }
    
    public func leaveRoom() async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.leaveRoom()
        case .livekit:
            try await livekitEngine?.leaveRoom()
        }
    }
    
    public func publishLocalAudio(enabled: Bool) async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.publishLocalAudio(enabled: enabled)
        case .livekit:
            try await livekitEngine?.publishLocalAudio(enabled: enabled)
        }
    }
    
    public func publishLocalVideo(enabled: Bool) async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.publishLocalVideo(enabled: enabled)
        case .livekit:
            try await livekitEngine?.publishLocalVideo(enabled: enabled)
        }
    }
    
    public func publishScreenShare() async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.publishScreenShare()
        case .livekit:
            try await livekitEngine?.publishScreenShare()
        }
    }
    
    public func stopScreenShare() async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.stopScreenShare()
        case .livekit:
            try await livekitEngine?.stopScreenShare()
        }
    }
    
    public func subscribeToRemoteAudio(peerId: String) async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.subscribeToRemoteAudio(peerId: peerId)
        case .livekit:
            try await livekitEngine?.subscribeToRemoteAudio(peerId: peerId)
        }
    }
    
    public func subscribeToRemoteVideo(peerId: String) async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.subscribeToRemoteVideo(peerId: peerId)
        case .livekit:
            try await livekitEngine?.subscribeToRemoteVideo(peerId: peerId)
        }
    }
    
    public func unsubscribeFromPeer(peerId: String) async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 9, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.unsubscribeFromPeer(peerId: peerId)
        case .livekit:
            try await livekitEngine?.unsubscribeFromPeer(peerId: peerId)
        }
    }
    
    public func sendDataMessage(_ data: Data, to peerId: String?) async throws {
        guard let engineType = currentEngineType else {
            throw NSError(domain: "JMWebRTCError", code: 10, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        switch engineType {
        case .mediasoup:
            try await mediasoupEngine?.sendDataMessage(data, to: peerId)
        case .livekit:
            try await livekitEngine?.sendDataMessage(data, to: peerId)
        }
    }
    
    // MARK: - Engine Information
    
    public var engineInfo: String {
        guard let engineType = currentEngineType else {
            return "No engine selected"
        }
        
        switch engineType {
        case .mediasoup:
            return "Mediasoup (Standard WebRTC RTC* v114.x)"
        case .livekit:
            return "LiveKit (LKRTC-prefixed WebRTC v125.x)"
        }
    }
    
    public var webRTCVersion: String {
        guard let engineType = currentEngineType else {
            return "Unknown"
        }
        
        switch engineType {
        case .mediasoup:
            return "114.x (Standard WebRTC)"
        case .livekit:
            return "125.x (LiveKit WebRTC)"
        }
    }
    
    public var detailedEngineInfo: String {
        guard let engineType = currentEngineType else {
            return "No engine active"
        }
        
        switch engineType {
        case .mediasoup:
            return mediasoupEngine?.webRTCInfo ?? "Mediasoup engine info unavailable"
        case .livekit:
            return livekitEngine?.webRTCInfo ?? "LiveKit engine info unavailable"
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() async {
        print("🧹 JMWebRTCManager: Cleaning up current engine")
        
        if let engineType = currentEngineType {
            switch engineType {
            case .mediasoup:
                await mediasoupEngine?.cleanup()
            case .livekit:
                await livekitEngine?.cleanup()
            }
        }
        
        currentEngineType = nil
        isEngineInitialized = false
    }
    
    public func shutdown() async {
        print("🔌 JMWebRTCManager: Shutting down all engines")
        
        await cleanup()
        
        // Cleanup both engine instances
        mediasoupEngine = nil
        livekitEngine = nil
    }
} 