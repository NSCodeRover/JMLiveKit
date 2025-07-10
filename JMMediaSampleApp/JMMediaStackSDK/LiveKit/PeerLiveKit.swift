//  PeerLiveKit.swift
//  JMMediaStackSDK
//  Mirrors Mediasoup `Peer` model for LiveKit backend

import Foundation
import UIKit
#if canImport(LiveKit)
import LiveKit

/// Remote participant model used when SDK backend is LiveKit.
struct Peer: Codable {
    // MARK: - Identity
    var peerId: String
    var displayName: String

    // MARK: - Media flags
    var hasAudio = false
    var hasVideo = false
    var hasScreenShare = false

    // MARK: - LiveKit references
    var participant: RemoteParticipant?
    var videoTrack: RemoteVideoTrack?
    var audioTrack: RemoteAudioTrack?
    var shareVideoTrack: RemoteVideoTrack?
    var shareAudioTrack: RemoteAudioTrack?
    // MARK: - UI containers supplied by app layer
    var remoteVideoView: UIView?
    var remoteScreenShareView: UIView?

    // MARK: - Codable
    enum CodingKeys: String, CodingKey { case peerId, displayName }
    init(id: String, name: String, participant: RemoteParticipant? = nil) {
        peerId = id; displayName = name; self.participant = participant
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        peerId = try c.decodeIfPresent(String.self, forKey: .peerId) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    }
    func encode(to encoder: Encoder) throws {}

    // MARK: - Render helpers
    mutating func renderCamera(in container: UIView) {
        guard let videoTrack else { return }
        if !Thread.isMainThread { DispatchQueue.main.async { [self] in var s = self; s.renderCamera(in: container) }; return }

        container.subviews.forEach { $0.removeFromSuperview() }
        let videoView = VideoView()
        videoView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(videoView)
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: container.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        videoView.track = videoTrack
        remoteVideoView = container; hasVideo = true
    }

    mutating func renderScreenShare(track: RemoteVideoTrack, in container: UIView) {
        if !Thread.isMainThread { DispatchQueue.main.async { [self] in var s = self; s.renderScreenShare(track: track, in: container) }; return }

        print("🖥️ LiveKit: Rendering screen-share for peer \(peerId) — container: \(container)")
        if !container.subviews.isEmpty {
            print("🧹 LiveKit: Clearing \(container.subviews.count) previous subviews before attaching new screen track")
        }
        container.subviews.forEach { $0.removeFromSuperview() }

        let videoView = VideoView()
        videoView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(videoView)
        print("➕ LiveKit: VideoView added to container; setting constraints…")
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: container.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        print("🔗 LiveKit: Binding screen-share track to VideoView for peer \(peerId)")
        videoView.track = track
        videoView.setNeedsLayout()
        remoteScreenShareView = container; hasScreenShare = true
        print("✅ LiveKit: Screen-share rendered & state updated for peer \(peerId)")
    }

    mutating func detachAllVideo() {
        remoteVideoView?.subviews.forEach { $0.removeFromSuperview() }
        remoteScreenShareView?.subviews.forEach { $0.removeFromSuperview() }
        hasVideo = false; hasScreenShare = false
    }
}
#endif 
