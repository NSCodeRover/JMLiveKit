//
//  JMWebRTCManager.swift
//  JMMediaStackSDK
//
//  Dual WebRTC Stack Runtime Manager
//  Handles switching between MediaSoup (RTC*) and LiveKit (LKRTC*) engines
//

import Foundation
import LiveKit

// MARK: - WebRTC Engine Types
public enum JMWebRTCEngineType {
    case mediaSoup  // Uses RTC* classes from MediaSoup
    case liveKit    // Uses LKRTC* classes from LiveKit
}

// MARK: - Dual WebRTC Stack Manager
/// Manages runtime switching between MediaSoup and LiveKit WebRTC implementations
public class JMWebRTCManager: NSObject {
    
    // MARK: - Singleton
    public static let shared = JMWebRTCManager()
    
    // MARK: - Properties
    private var currentEngineType: JMWebRTCEngineType = .mediaSoup
    private var liveKitEngine: JMLiveKitEngine?
    
    // MARK: - Delegates
    public weak var delegate: JMWebRTCManagerDelegate?
    
    private override init() {
        super.init()
        setupEngines()
    }
    
    // MARK: - Engine Setup
    private func setupEngines() {
        liveKitEngine = JMLiveKitEngine.shared
        liveKitEngine?.delegate = self
    }
    
    // MARK: - Engine Switching
    public func switchToEngine(_ engineType: JMWebRTCEngineType) async {
        guard currentEngineType != engineType else {
            delegate?.webRTCManager(self, didSwitchToEngine: engineType)
            return
        }
        
        // Disconnect current engine
        await disconnectCurrentEngine()
        
        // Switch to new engine
        currentEngineType = engineType
        
        LOG.info("WebRTC Manager: Switched to \(engineType == .mediaSoup ? "MediaSoup (RTC*)" : "LiveKit (LKRTC*)")")
        delegate?.webRTCManager(self, didSwitchToEngine: engineType)
    }
    
    private func disconnectCurrentEngine() async {
        switch currentEngineType {
        case .mediaSoup:
            // Disconnect MediaSoup engine
            // Note: Implement MediaSoup disconnection as needed
            break
        case .liveKit:
            await liveKitEngine?.disconnect()
        }
    }
    
    // MARK: - Connection Management
    public func connect(to url: String, with token: String) async throws {
        switch currentEngineType {
        case .mediaSoup:
            // Use existing MediaSoup connection logic
            throw JMWebRTCError.mediaSoupConnectionNotImplemented
        case .liveKit:
            try await liveKitEngine?.connect(to: url, with: token)
        }
    }
    
    public func disconnect() async {
        await disconnectCurrentEngine()
    }
    
    // MARK: - Media Controls
    public func enableCamera(_ enable: Bool) async throws {
        switch currentEngineType {
        case .mediaSoup:
            // Use existing MediaSoup camera logic
            throw JMWebRTCError.mediaSoupControlNotImplemented
        case .liveKit:
            try await liveKitEngine?.enableCamera(enable)
        }
    }
    
    public func enableMicrophone(_ enable: Bool) async throws {
        switch currentEngineType {
        case .mediaSoup:
            // Use existing MediaSoup microphone logic
            throw JMWebRTCError.mediaSoupControlNotImplemented
        case .liveKit:
            try await liveKitEngine?.enableMicrophone(enable)
        }
    }
    
    public func enableScreenShare(_ enable: Bool) async throws {
        switch currentEngineType {
        case .mediaSoup:
            // Use existing MediaSoup screen share logic
            throw JMWebRTCError.mediaSoupControlNotImplemented
        case .liveKit:
            try await liveKitEngine?.enableScreenShare(enable)
        }
    }
    
    // MARK: - Current State
    public var isConnected: Bool {
        switch currentEngineType {
        case .mediaSoup:
            // Return MediaSoup connection state
            return false // Placeholder
        case .liveKit:
            return liveKitEngine?.isConnected ?? false
        }
    }
    
    public func getCurrentEngine() -> JMWebRTCEngineType {
        return currentEngineType
    }
    
    // MARK: - LiveKit Access
    public func getLiveKitRoom() -> Room? {
        guard currentEngineType == .liveKit else { return nil }
        return liveKitEngine?.currentRoom
    }
    
    public func getLiveKitLocalParticipant() -> LocalParticipant? {
        guard currentEngineType == .liveKit else { return nil }
        return liveKitEngine?.currentLocalParticipant
    }
}

// MARK: - LiveKit Engine Delegate
extension JMWebRTCManager: JMLiveKitEngineDelegate {
    
    public func liveKitEngine(_ engine: JMLiveKitEngine, didConnectToRoom room: Room) {
        delegate?.webRTCManager(self, didConnectWithEngine: .liveKit)
    }
    
    public func liveKitEngineDidDisconnect(_ engine: JMLiveKitEngine) {
        delegate?.webRTCManager(self, didDisconnectWithEngine: .liveKit)
    }
    
    public func liveKitEngine(_ engine: JMLiveKitEngine, didUpdateConnectionState state: ConnectionState) {
        delegate?.webRTCManager(self, didUpdateConnectionState: state, forEngine: .liveKit)
    }
    
    public func liveKitEngine(_ engine: JMLiveKitEngine, participantDidConnect participant: RemoteParticipant) {
        delegate?.webRTCManager(self, participantDidConnect: participant, inEngine: .liveKit)
    }
    
    public func liveKitEngine(_ engine: JMLiveKitEngine, participantDidDisconnect participant: RemoteParticipant) {
        delegate?.webRTCManager(self, participantDidDisconnect: participant, inEngine: .liveKit)
    }
    
    public func liveKitEngine(_ engine: JMLiveKitEngine, participant: RemoteParticipant, didSubscribeTrack track: Track, publication: RemoteTrackPublication) {
        delegate?.webRTCManager(self, participant: participant, didSubscribeTrack: track, publication: publication, inEngine: .liveKit)
    }
    
    public func liveKitEngine(_ engine: JMLiveKitEngine, participant: RemoteParticipant, didUnsubscribeTrack track: Track, publication: RemoteTrackPublication) {
        delegate?.webRTCManager(self, participant: participant, didUnsubscribeTrack: track, publication: publication, inEngine: .liveKit)
    }
}

// MARK: - WebRTC Manager Delegate Protocol
public protocol JMWebRTCManagerDelegate: AnyObject {
    func webRTCManager(_ manager: JMWebRTCManager, didSwitchToEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, didConnectWithEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, didDisconnectWithEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, didUpdateConnectionState state: ConnectionState, forEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, participantDidConnect participant: RemoteParticipant, inEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, participantDidDisconnect participant: RemoteParticipant, inEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, participant: RemoteParticipant, didSubscribeTrack track: Track, publication: RemoteTrackPublication, inEngine engineType: JMWebRTCEngineType)
    func webRTCManager(_ manager: JMWebRTCManager, participant: RemoteParticipant, didUnsubscribeTrack track: Track, publication: RemoteTrackPublication, inEngine engineType: JMWebRTCEngineType)
}

// MARK: - WebRTC Errors
public enum JMWebRTCError: Error {
    case mediaSoupConnectionNotImplemented
    case mediaSoupControlNotImplemented
    case engineSwitchFailed
    case invalidEngineType
    
    public var localizedDescription: String {
        switch self {
        case .mediaSoupConnectionNotImplemented:
            return "MediaSoup connection logic needs to be implemented"
        case .mediaSoupControlNotImplemented:
            return "MediaSoup media control logic needs to be implemented"
        case .engineSwitchFailed:
            return "Failed to switch WebRTC engines"
        case .invalidEngineType:
            return "Invalid WebRTC engine type specified"
        }
    }
} 