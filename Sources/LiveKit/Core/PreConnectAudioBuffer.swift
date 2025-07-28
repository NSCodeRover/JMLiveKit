/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/// A class that captures audio before connecting to a room and sends it to agents.
/// This is useful for scenarios where you want to capture audio during the connection process.
@objc
public class PreConnectAudioBuffer: NSObject, Loggable {
    // MARK: - Public

    /// The current state of the audio buffer.
    @objc
    public var recorder: LocalAudioTrackRecorder? { state.recorder }

    /// The room instance that this buffer is associated with.
    @objc
    public weak var room: Room?

    // MARK: - Private

    private let state = StateSync(State())

    private struct State {
        var recorder: LocalAudioTrackRecorder?
        var audioStream: LocalAudioTrackRecorder.Stream?
        var timeoutTask: Task<Void, Never>?
        var sent = false
    }

    private enum Constants {
        static let timeout: TimeInterval = 30
        static let sampleRate = 16000
        static let maxSize = 1024 * 1024 // 1MB
    }

    private let dataTopic = "pre-connect-audio"

    // MARK: - Public

    /// Start capturing audio.
    /// - Parameters:
    ///   - timeout: The timeout in seconds after which recording will stop automatically.
    ///   - recorder: Optional custom recorder instance. If not provided, a new one will be created.
    @objc
    public func startRecording(timeout: TimeInterval = Constants.timeout, recorder: LocalAudioTrackRecorder? = nil) async throws {
        room?.add(delegate: self)

        let roomOptions = room?._state.roomOptions
        let newRecorder = recorder ?? LocalAudioTrackRecorder(
            track: LocalAudioTrack.createTrack(options: roomOptions?.defaultAudioCaptureOptions,
                                               reportStatistics: roomOptions?.reportRemoteTrackStatistics ?? false),
            format: .pcmFormatInt16,
            sampleRate: Constants.sampleRate,
            maxSize: Constants.maxSize
        )

        let stream = try await newRecorder.start()
        log("Started capturing audio", .info)

        state.timeoutTask?.cancel()
        state.mutate { state in
            state.recorder = newRecorder
            state.audioStream = stream
            state.timeoutTask = Task { [weak self] in
                try await Task.sleep(nanoseconds: UInt64(timeout) * NSEC_PER_SEC)
                try Task.checkCancellation()
                self?.stopRecording(flush: true)
            }
            state.sent = false
        }
    }

    /// Stop capturing audio.
    /// - Parameters:
    ///   - flush: If `true`, the audio stream will be flushed immediately without sending.
    @objc
    public func stopRecording(flush: Bool = false) {
        guard let recorder, recorder.isRecording else { return }

        recorder.stop()
        log("Stopped capturing audio", .info)

        if flush, let stream = state.audioStream {
            log("Flushing audio stream", .info)
            Task {
                for await _ in stream {}
            }
            room?.remove(delegate: self)
        }
    }

    /// Send the audio data to the room.
    /// - Parameters:
    ///   - room: The room instance to send the audio data.
    ///   - agents: The agents to send the audio data to.
    ///   - topic: The topic to send the audio data.
    @objc
    public func sendAudioData(to room: Room, agents: [Participant.Identity], on topic: String = dataTopic) async throws {
        guard !agents.isEmpty else { return }

        guard !state.sent else { return }
        state.mutate { $0.sent = true }

        guard let recorder else {
            throw LiveKitError(.invalidState, message: "Recorder is nil")
        }

        guard let audioStream = state.audioStream else {
            throw LiveKitError(.invalidState, message: "Audio stream is nil")
        }

        let streamOptions = StreamByteOptions(
            topic: topic,
            attributes: [
                "sampleRate": "\(recorder.sampleRate)",
                "channels": "\(recorder.channels)",
                "trackId": recorder.track.sid?.stringValue ?? "",
            ],
            destinationIdentities: agents
        )
        let writer = try await room.localParticipant.streamBytes(options: streamOptions)

        var sentSize = 0
        for await chunk in audioStream {
            do {
                try await writer.write(chunk)
            } catch {
                try await writer.close(reason: error.localizedDescription)
                throw error
            }
            sentSize += chunk.count
        }
        try await writer.close()

        log("Sent \(recorder.duration(sentSize))s = \(sentSize / 1024)KB of audio data to \(agents.count) agent(s) \(agents)", .info)
    }
}

extension PreConnectAudioBuffer: RoomDelegate {
    public func room(_: Room, participant _: LocalParticipant, remoteDidSubscribeTrack _: LocalTrackPublication) {
        log("Subscribed by remote participant, stopping audio", .info)
        stopRecording()
    }
}
