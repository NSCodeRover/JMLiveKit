import Foundation
import UIKit

// MARK: - Dual WebRTC Stack Imports
// Standard WebRTC (Version 114.x) - RTC* prefix accessed through Mediasoup framework
// This is the correct way to access WebRTC in the dual stack setup

#if canImport(Mediasoup)
import Mediasoup
// Mediasoup framework contains embedded WebRTC with RTC* prefix
// This provides: RTCPeerConnection, RTCPeerConnectionFactory, etc.
#endif

// Also available: LiveKit WebRTC (Version 125.x) - LKRTC* prefix via LiveKit framework
// The dual WebRTC setup allows both to coexist without conflicts through proper symbol prefixing

/**
 * JMMediasoupEngine
 * 
 * Uses STANDARD WebRTC with RTC* prefix (version 114.x)
 * - RTCPeerConnection
 * - RTCPeerConnectionFactory
 * - RTCVideoTrack, RTCAudioTrack
 * - RTCDataChannel
 * - RTCIceServer, RTCConfiguration
 * 
 * This implementation demonstrates complete isolation from LiveKit's LKRTC* classes
 * The dual WebRTC stack architecture supports both frameworks through symbol isolation
 */
@MainActor
public class JMMediasoupEngine {
    
    // MARK: - Engine Properties (Matching Unified Interface)
    public let engineType = "mediasoup"
    public private(set) var isInitialized = false
    
    // MARK: - Standard WebRTC Components (RTC* classes - v114.x)
    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var localPeerConnection: RTCPeerConnection?
    private var remotePeerConnections: [String: RTCPeerConnection] = [:]
    
    // Local media tracks (Standard WebRTC)
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoTrack: RTCVideoTrack?
    private var localScreenTrack: RTCVideoTrack?
    
    // Media sources (Standard WebRTC)
    private var audioSource: RTCAudioSource?
    private var videoSource: RTCVideoSource?
    private var videoCapturer: RTCCameraVideoCapturer?
    
    // Data channels (Standard WebRTC)
    private var dataChannel: RTCDataChannel?
    private var remoteDataChannels: [String: RTCDataChannel] = [:]
    
    // Room state
    private var currentRoomId: String?
    private var roomConfig: [String: Any]?
    private var connectedPeers: Set<String> = []
    
    // Thread safety
    private let webRTCQueue = DispatchQueue(label: "com.jm.mediasoup.webrtc", qos: .userInitiated)
    
    public init() {
        print("🏗️ JMMediasoupEngine: Initializing with standard WebRTC (RTC* v114.x)")
    }
    
    deinit {
        Task {
            await cleanup()
        }
    }
    
    // MARK: - Engine Management
    
    public func initialize() async throws {
        guard !isInitialized else {
            print("⚠️ JMMediasoupEngine: Already initialized")
            return
        }
        
        print("🚀 JMMediasoupEngine: Initializing standard WebRTC stack (RTC* v114.x)")
        
        return try await withCheckedThrowingContinuation { continuation in
            webRTCQueue.async { [weak self] in
                do {
                    try self?.setupWebRTCFactory()
                    
                    Task { @MainActor in
                        self?.isInitialized = true
                        print("✅ JMMediasoupEngine: Standard WebRTC initialization complete")
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        print("❌ JMMediasoupEngine: Initialization failed - \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func setupWebRTCFactory() throws {
        // Initialize standard WebRTC factory (RTC* classes)
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        
        guard peerConnectionFactory != nil else {
            throw NSError(domain: "JMWebRTCError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid configuration"])
        }
        
        print("🏭 JMMediasoupEngine: Standard WebRTC factory created (RTC* v114.x)")
    }
    
    public func cleanup() async {
        print("🧹 JMMediasoupEngine: Cleaning up standard WebRTC resources")
        
        await withCheckedContinuation { continuation in
            webRTCQueue.async { [weak self] in
                self?.cleanupWebRTCResources()
                
                Task { @MainActor in
                    self?.isInitialized = false
                    self?.currentRoomId = nil
                    self?.roomConfig = nil
                    self?.connectedPeers.removeAll()
                    continuation.resume()
                }
            }
        }
    }
    
    private func cleanupWebRTCResources() {
        // Close data channels (Standard WebRTC)
        dataChannel?.close()
        dataChannel = nil
        
        remoteDataChannels.values.forEach { $0.close() }
        remoteDataChannels.removeAll()
        
        // Stop local tracks (Standard WebRTC)
        localAudioTrack = nil
        localVideoTrack = nil
        localScreenTrack = nil
        
        // Close peer connections (Standard WebRTC)
        localPeerConnection?.close()
        localPeerConnection = nil
        
        remotePeerConnections.values.forEach { $0.close() }
        remotePeerConnections.removeAll()
        
        // Cleanup sources and capturer (Standard WebRTC)
        audioSource = nil
        videoSource = nil
        videoCapturer = nil
        
        peerConnectionFactory = nil
        
        print("🗑️ JMMediasoupEngine: Standard WebRTC cleanup complete")
    }
    
    // MARK: - Connection Management
    
    public func joinRoom(roomId: String, config: [String: Any]) async throws {
        guard isInitialized else {
            throw NSError(domain: "JMWebRTCError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }
        
        print("🚪 JMMediasoupEngine: Joining room '\(roomId)' with standard WebRTC")
        
        currentRoomId = roomId
        roomConfig = config
        
        return try await withCheckedThrowingContinuation { continuation in
            webRTCQueue.async { [weak self] in
                do {
                    try self?.setupPeerConnection()
                    try self?.setupLocalMedia(config: config)
                    
                    // Simulate connection establishment
                    Task { @MainActor in
                        print("✅ JMMediasoupEngine: Successfully joined room with standard WebRTC")
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        print("❌ JMMediasoupEngine: Failed to join room - \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func setupPeerConnection() throws {
        guard let factory = peerConnectionFactory else {
            throw NSError(domain: "JMWebRTCError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid configuration"])
        }
        
        // Create RTCConfiguration for standard WebRTC
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        config.iceCandidatePoolSize = 10
        
        // Create local peer connection (Standard WebRTC RTCPeerConnection)
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        localPeerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: nil)
        
        guard localPeerConnection != nil else {
            throw NSError(domain: "JMWebRTCError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        }
        
        print("🔗 JMMediasoupEngine: Standard WebRTC peer connection created")
    }
    
    private func setupLocalMedia(config: [String: Any]) throws {
        guard let factory = peerConnectionFactory else {
            throw NSError(domain: "JMWebRTCError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid configuration"])
        }
        
        // Setup audio track (Standard WebRTC RTCAudioTrack)
        if config["audioEnabled"] as? Bool == true {
            let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            audioSource = factory.audioSource(with: audioConstraints)
            localAudioTrack = factory.audioTrack(with: audioSource!, trackId: "audio_\(UUID().uuidString)")
            
            if let audioTrack = localAudioTrack {
                localPeerConnection?.add(audioTrack, streamIds: ["local_stream"])
                print("🎤 JMMediasoupEngine: Standard WebRTC audio track added")
            }
        }
        
        // Setup video track (Standard WebRTC RTCVideoTrack)
        if config["videoEnabled"] as? Bool == true {
            videoSource = factory.videoSource()
            localVideoTrack = factory.videoTrack(with: videoSource!, trackId: "video_\(UUID().uuidString)")
            
            // Setup camera capturer (Standard WebRTC RTCCameraVideoCapturer)
            videoCapturer = RTCCameraVideoCapturer(delegate: videoSource!)
            
            if let videoTrack = localVideoTrack {
                localPeerConnection?.add(videoTrack, streamIds: ["local_stream"])
                print("📹 JMMediasoupEngine: Standard WebRTC video track added")
            }
        }
        
        // Setup data channel (Standard WebRTC RTCDataChannel)
        if config["enableDataChannel"] as? Bool == true {
            let dataChannelConfig = RTCDataChannelConfiguration()
            dataChannelConfig.channelId = 0
            dataChannelConfig.isOrdered = true
            
            dataChannel = localPeerConnection?.dataChannel(forLabel: "data", configuration: dataChannelConfig)
            print("📡 JMMediasoupEngine: Standard WebRTC data channel created")
        }
    }
    
    public func leaveRoom() async throws {
        guard currentRoomId != nil else {
            print("⚠️ JMMediasoupEngine: Not in a room")
            return
        }
        
        print("🚪 JMMediasoupEngine: Leaving room with standard WebRTC")
        await cleanup()
        print("✅ JMMediasoupEngine: Successfully left room")
    }
    
    // MARK: - Media Management
    
    public func publishLocalAudio(enabled: Bool) async throws {
        guard let audioTrack = localAudioTrack else {
            throw NSError(domain: "JMWebRTCError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Publish failed"])
        }
        
        audioTrack.isEnabled = enabled
        print("🎤 JMMediasoupEngine: Audio \(enabled ? "enabled" : "disabled") (Standard WebRTC)")
    }
    
    public func publishLocalVideo(enabled: Bool) async throws {
        guard let videoTrack = localVideoTrack else {
            throw NSError(domain: "JMWebRTCError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Publish failed"])
        }
        
        if enabled && videoCapturer != nil {
            // Start camera capture (Standard WebRTC)
            startCameraCapture()
        }
        
        videoTrack.isEnabled = enabled
        print("📹 JMMediasoupEngine: Video \(enabled ? "enabled" : "disabled") (Standard WebRTC)")
    }
    
    private func startCameraCapture() {
        guard let capturer = videoCapturer else { return }
        
        webRTCQueue.async {
            // Get available camera devices (Standard WebRTC)
            let devices = RTCCameraVideoCapturer.captureDevices()
            guard let frontCamera = devices.first(where: { $0.position == .front }) else {
                print("❌ JMMediasoupEngine: No front camera found")
                return
            }
            
            // Find suitable format (Standard WebRTC)
            let formats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
            guard let format = formats.first else {
                print("❌ JMMediasoupEngine: No supported camera formats")
                return
            }
            
            // Start capture (Standard WebRTC)
            capturer.startCapture(with: frontCamera, format: format, fps: 30)
            print("📸 JMMediasoupEngine: Camera capture started (Standard WebRTC)")
        }
    }
    
    public func publishScreenShare() async throws {
        // Screen sharing implementation for standard WebRTC
        guard let factory = peerConnectionFactory else {
            throw NSError(domain: "JMWebRTCError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Publish failed"])
        }
        
        // Note: Screen sharing on iOS requires broadcast extension
        print("📺 JMMediasoupEngine: Screen share requested (Standard WebRTC) - requires broadcast extension")
        
        // Create screen share track (Standard WebRTC)
        let screenSource = factory.videoSource()
        localScreenTrack = factory.videoTrack(with: screenSource, trackId: "screen_\(UUID().uuidString)")
        
        if let screenTrack = localScreenTrack {
            localPeerConnection?.add(screenTrack, streamIds: ["screen_stream"])
            print("📺 JMMediasoupEngine: Screen share track added (Standard WebRTC)")
        }
    }
    
    public func stopScreenShare() async throws {
        guard let screenTrack = localScreenTrack else {
            print("⚠️ JMMediasoupEngine: No screen share to stop")
            return
        }
        
        localPeerConnection?.remove(screenTrack)
        localScreenTrack = nil
        print("📺 JMMediasoupEngine: Screen share stopped (Standard WebRTC)")
    }
    
    // MARK: - Subscription Management
    
    public func subscribeToRemoteAudio(peerId: String) async throws {
        guard connectedPeers.contains(peerId) else {
            throw NSError(domain: "JMWebRTCError", code: 9, userInfo: [NSLocalizedDescriptionKey: "Subscribe failed"])
        }
        
        print("🎧 JMMediasoupEngine: Subscribing to remote audio from peer \(peerId) (Standard WebRTC)")
        
        // Implementation would involve signaling to request audio from peer
        // This is a placeholder for the actual MediaSoup signaling protocol
    }
    
    public func subscribeToRemoteVideo(peerId: String) async throws {
        guard connectedPeers.contains(peerId) else {
            throw NSError(domain: "JMWebRTCError", code: 10, userInfo: [NSLocalizedDescriptionKey: "Subscribe failed"])
        }
        
        print("📺 JMMediasoupEngine: Subscribing to remote video from peer \(peerId) (Standard WebRTC)")
        
        // Implementation would involve signaling to request video from peer
        // This is a placeholder for the actual MediaSoup signaling protocol
    }
    
    public func unsubscribeFromPeer(peerId: String) async throws {
        guard connectedPeers.contains(peerId) else {
            print("⚠️ JMMediasoupEngine: Peer \(peerId) not connected")
            return
        }
        
        print("🔌 JMMediasoupEngine: Unsubscribing from peer \(peerId) (Standard WebRTC)")
        
        // Remove peer connection (Standard WebRTC)
        if let peerConnection = remotePeerConnections[peerId] {
            peerConnection.close()
            remotePeerConnections.removeValue(forKey: peerId)
        }
        
        // Remove data channel
        if let dataChannel = remoteDataChannels[peerId] {
            dataChannel.close()
            remoteDataChannels.removeValue(forKey: peerId)
        }
        
        connectedPeers.remove(peerId)
    }
    
    // MARK: - Data Channel Support
    
    public func sendDataMessage(_ data: Data, to peerId: String?) async throws {
        let targetChannel: RTCDataChannel?
        
        if let peerId = peerId {
            // Send to specific peer (Standard WebRTC)
            targetChannel = remoteDataChannels[peerId]
            guard targetChannel != nil else {
                throw NSError(domain: "JMWebRTCError", code: 11, userInfo: [NSLocalizedDescriptionKey: "Data channel error"])
            }
        } else {
            // Broadcast to all (Standard WebRTC)
            targetChannel = dataChannel
            guard targetChannel != nil else {
                throw NSError(domain: "JMWebRTCError", code: 12, userInfo: [NSLocalizedDescriptionKey: "Data channel error"])
            }
        }
        
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        targetChannel?.sendData(buffer)
        
        let target = peerId ?? "all peers"
        print("📡 JMMediasoupEngine: Data message sent to \(target) (Standard WebRTC)")
    }
}

// MARK: - Engine Information Extension
extension JMMediasoupEngine {
    
    public var webRTCInfo: String {
        return """
        Engine: Mediasoup
        WebRTC Version: 114.x (Standard)
        Symbols: RTC* prefix
        PeerConnection: \(localPeerConnection != nil ? "Active" : "Inactive")
        Room: \(currentRoomId ?? "None")
        Peers: \(connectedPeers.count)
        """
    }
    
    public var supportedCodecs: [String] {
        // Standard WebRTC supported codecs
        return ["VP8", "VP9", "H264", "Opus", "G711"]
    }
} 