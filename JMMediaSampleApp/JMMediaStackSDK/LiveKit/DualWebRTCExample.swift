//
//  DualWebRTCExample.swift
//  JMMediaStackSDK
//
//  Example demonstrating dual WebRTC stack usage
//  Shows runtime switching between MediaSoup and LiveKit engines
//

import Foundation
import LiveKit

// MARK: - Dual WebRTC Stack Usage Example
/// Example class showing how to use the dual WebRTC stack
/// for runtime switching between MediaSoup and LiveKit engines
public class DualWebRTCExample: NSObject {
    
    private let mediaEngine = JMMediaEngine.shared
    private let webRTCManager = JMWebRTCManager.shared
    
    public override init() {
        super.init()
        webRTCManager.delegate = self
    }
    
    // MARK: - Engine Switching Examples
    public func demonstrateDualStack() async {
        print("🚀 Dual WebRTC Stack Demo")
        
        // Start with MediaSoup (default)
        print("📡 Current engine: \(getCurrentEngineDescription())")
        
        // Switch to LiveKit
        print("🔄 Switching to LiveKit...")
        await switchToLiveKit()
        print("✅ Switched to: \(getCurrentEngineDescription())")
        
        // Switch back to MediaSoup
        print("🔄 Switching back to MediaSoup...")
        await switchToMediaSoup()
        print("✅ Switched to: \(getCurrentEngineDescription())")
    }
    
    public func switchToLiveKit() async {
        await mediaEngine.switchWebRTCEngine(to: .liveKit)
    }
    
    public func switchToMediaSoup() async {
        await mediaEngine.switchWebRTCEngine(to: .mediaSoup)
    }
    
    public func getCurrentEngine() -> JMWebRTCEngineType {
        return mediaEngine.getCurrentWebRTCEngine()
    }
    
    private func getCurrentEngineDescription() -> String {
        switch getCurrentEngine() {
        case .mediaSoup:
            return "MediaSoup WebRTC (RTC* classes)"
        case .liveKit:
            return "LiveKit WebRTC (LKRTC* classes)"
        }
    }
    
    // MARK: - LiveKit Specific Operations
    public func connectToLiveKitRoom(url: String, token: String) async throws {
        // Ensure we're using LiveKit engine
        await switchToLiveKit()
        
        // Connect using WebRTC manager
        try await webRTCManager.connect(to: url, with: token)
    }
    
    public func getLiveKitRoom() -> Room? {
        return webRTCManager.getLiveKitRoom()
    }
    
    public func getLiveKitLocalParticipant() -> LocalParticipant? {
        return webRTCManager.getLiveKitLocalParticipant()
    }
    
    // MARK: - Media Controls (Engine Agnostic)
    public func enableCamera(_ enable: Bool) async throws {
        try await webRTCManager.enableCamera(enable)
    }
    
    public func enableMicrophone(_ enable: Bool) async throws {
        try await webRTCManager.enableMicrophone(enable)
    }
    
    public func enableScreenShare(_ enable: Bool) async throws {
        try await webRTCManager.enableScreenShare(enable)
    }
}

// MARK: - WebRTC Manager Delegate
extension DualWebRTCExample: JMWebRTCManagerDelegate {
    
    public func webRTCManager(_ manager: JMWebRTCManager, didSwitchToEngine engineType: JMWebRTCEngineType) {
        print("✅ WebRTC Manager: Successfully switched to \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit")")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, didConnectWithEngine engineType: JMWebRTCEngineType) {
        print("🔗 WebRTC Manager: Connected with \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit") engine")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, didDisconnectWithEngine engineType: JMWebRTCEngineType) {
        print("💔 WebRTC Manager: Disconnected from \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit") engine")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, didUpdateConnectionState state: ConnectionState, forEngine engineType: JMWebRTCEngineType) {
        print("📊 WebRTC Manager: Connection state \(state) for \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit")")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, participantDidConnect participant: RemoteParticipant, inEngine engineType: JMWebRTCEngineType) {
        print("👤 WebRTC Manager: Participant \(participant.identity ?? "unknown") joined in \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit")")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, participantDidDisconnect participant: RemoteParticipant, inEngine engineType: JMWebRTCEngineType) {
        print("👋 WebRTC Manager: Participant \(participant.identity ?? "unknown") left \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit")")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, participant: RemoteParticipant, didSubscribeTrack track: Track, publication: RemoteTrackPublication, inEngine engineType: JMWebRTCEngineType) {
        print("📺 WebRTC Manager: Subscribed to \(track.kind) track from \(participant.identity ?? "unknown") in \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit")")
    }
    
    public func webRTCManager(_ manager: JMWebRTCManager, participant: RemoteParticipant, didUnsubscribeTrack track: Track, publication: RemoteTrackPublication, inEngine engineType: JMWebRTCEngineType) {
        print("📺 WebRTC Manager: Unsubscribed from \(track.kind) track from \(participant.identity ?? "unknown") in \(engineType == .mediaSoup ? "MediaSoup" : "LiveKit")")
    }
} 