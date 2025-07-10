//
//  JMLiveKitEngine.swift
//  JMMediaStackSDK
//
//  Dual WebRTC Stack Implementation
//  LiveKit WebRTC Engine (LKRTC* classes)
//

import Foundation
import LiveKit

// MARK: - LiveKit Engine for Dual WebRTC Stack
/// LiveKit-based WebRTC engine providing LKRTC* class access
/// This runs alongside MediaSoup WebRTC (RTC* classes) for dual stack capability
public class JMLiveKitEngine: NSObject {
    
    // MARK: - Singleton
    public static let shared = JMLiveKitEngine()
    
    // MARK: - Properties
    private var room: Room?
    private var localParticipant: LocalParticipant?
    
    // MARK: - Delegates
    public weak var delegate: JMLiveKitEngineDelegate?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Connection Management
    public func connect(to url: String, with token: String) async throws {
        room = Room()
        
        // Configure room options for optimal performance
        let connectOptions = ConnectOptions(
            autoSubscribe: true,
            publishOnlyMode: false
        )
        
        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                dimensions: .h720_169
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                useBroadcastExtension: true
            ),
            adaptiveStream: true,
            dynacast: true
        )
        
        room?.add(delegate: self)
        
        try await room?.connect(url, token, connectOptions: connectOptions, roomOptions: roomOptions)
        localParticipant = room?.localParticipant
        
        delegate?.liveKitEngine(self, didConnectToRoom: room!)
    }
    
    public func disconnect() async {
        await room?.disconnect()
        room = nil
        localParticipant = nil
        delegate?.liveKitEngineDidDisconnect(self)
    }
    
    // MARK: - Media Management
    public func enableCamera(_ enable: Bool) async throws {
        try await localParticipant?.setCamera(enabled: enable)
    }
    
    public func enableMicrophone(_ enable: Bool) async throws {
        try await localParticipant?.setMicrophone(enabled: enable)
    }
    
    public func enableScreenShare(_ enable: Bool) async throws {
        try await localParticipant?.setScreenShare(enabled: enable)
    }
    
    // MARK: - Current State
    public var isConnected: Bool {
        return room?.connectionState == .connected
    }
    
    public var currentRoom: Room? {
        return room
    }
    
    public var currentLocalParticipant: LocalParticipant? {
        return localParticipant
    }
}

// MARK: - LiveKit Room Delegate
extension JMLiveKitEngine: RoomDelegate {
    
    public func room(_ room: Room, didUpdate connectionState: ConnectionState, oldValue: ConnectionState) {
        delegate?.liveKitEngine(self, didUpdateConnectionState: connectionState)
    }
    
    public func room(_ room: Room, participant: RemoteParticipant, didSubscribe publication: RemoteTrackPublication, track: Track) {
        delegate?.liveKitEngine(self, participant: participant, didSubscribeTrack: track, publication: publication)
    }
    
    public func room(_ room: Room, participant: RemoteParticipant, didUnsubscribe publication: RemoteTrackPublication, track: Track) {
        delegate?.liveKitEngine(self, participant: participant, didUnsubscribeTrack: track, publication: publication)
    }
    
    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        delegate?.liveKitEngine(self, participantDidConnect: participant)
    }
    
    public func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        delegate?.liveKitEngine(self, participantDidDisconnect: participant)
    }
}

// MARK: - LiveKit Engine Delegate Protocol
public protocol JMLiveKitEngineDelegate: AnyObject {
    func liveKitEngine(_ engine: JMLiveKitEngine, didConnectToRoom room: Room)
    func liveKitEngineDidDisconnect(_ engine: JMLiveKitEngine)
    func liveKitEngine(_ engine: JMLiveKitEngine, didUpdateConnectionState state: ConnectionState)
    func liveKitEngine(_ engine: JMLiveKitEngine, participantDidConnect participant: RemoteParticipant)
    func liveKitEngine(_ engine: JMLiveKitEngine, participantDidDisconnect participant: RemoteParticipant)
    func liveKitEngine(_ engine: JMLiveKitEngine, participant: RemoteParticipant, didSubscribeTrack track: Track, publication: RemoteTrackPublication)
    func liveKitEngine(_ engine: JMLiveKitEngine, participant: RemoteParticipant, didUnsubscribeTrack track: Track, publication: RemoteTrackPublication)
} 