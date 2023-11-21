//
//  JMAudioDetector.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 03/10/23.
//

import Foundation
import AVFoundation.AVFAudio
import VoiceActivityDetector

class JMAudioDetector: NSObject {
    
    // Initialize Voice Activity Detector
    let voiceActivityDetector = VoiceActivityDetector(agressiveness: .veryAggressive)!
    
    // Property to store the current voice activity state
    var voiceActivity: VoiceActivityDetector.VoiceActivity? {
        didSet {
            // Check for changes in voice activity state
            guard oldValue != voiceActivity else { return }
            if let voiceActivity = voiceActivity {
                switch voiceActivity {
                case .activeVoice:
                    scheduleSpeechTimeoutStart() // Schedule the start of speech timeout
                case .inActiveVoice:
                    scheduleSpeechTimeoutEnd() // Schedule the end of speech timeout
                }
            }
        }
    }
    
    // Initialize audio recording properties
    var isMicrophoneActive = false
    var audioBuffers = [AudioQueueBufferRef]()
    var audioQueue: AudioQueueRef?
    var audioStreamDescription = AudioStreamBasicDescription(
        mSampleRate: 8000,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger,
        mBytesPerPacket: 2,
        mFramesPerPacket: 1,
        mBytesPerFrame: 2,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 16,
        mReserved: 0
    )
    
    // Callback for a toast message
    var toastCallback: (() -> Void)?
    var speakEndCounter = 0
    
    // Initialize the class
    override init() {
        super.init()
        setupAudioRecording() // Set up audio recording
        activateMicrophone() // Activate the microphone
    }
    
    // Function to dispose of resources
    func dispose() {
        deactivateMicrophone() // Deactivate the microphone
        audioBuffers.removeAll()
        audioQueue = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    // MARK: - Voice Activity Detection
    
    // Function to start speech timeout
    @objc func startSpeechTimeout() {
        toastCallback?()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    // Function to end speech timeout
    @objc func endSpeechTimeout() {
        if speakEndCounter != 0 && speakEndCounter % 3 == 0 {
            toastCallback?()
            speakEndCounter = 0
        }
        speakEndCounter = speakEndCounter + 1
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    // Function to schedule the start of speech timeout
    func scheduleSpeechTimeoutStart() {
        perform(#selector(startSpeechTimeout), with: nil, afterDelay: 2.5)
    }
    
    // Function to schedule the end of speech timeout
    func scheduleSpeechTimeoutEnd() {
        perform(#selector(endSpeechTimeout), with: nil, afterDelay: 1.9)
    }
    
    // MARK: - Audio Recording
    
    // Function to set up audio recording
    func setupAudioRecording() {
        let callback: AudioQueueInputCallback = { (
            inUserData: UnsafeMutableRawPointer?,
            inAQ: AudioQueueRef,
            inBuffer: AudioQueueBufferRef,_,_,_
        ) in
            guard let inUserData = inUserData else { return }
            let myself = Unmanaged<JMAudioDetector>.fromOpaque(inUserData).takeUnretainedValue()
            guard myself.isMicrophoneActive else { return }
            myself.didReceivceSampleBuffer(buffer: inBuffer.pointee)
            
            let err = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
            if (err != noErr) {
                NSLog("AudioQueueEnqueueBuffer failed with error (\(err))")
                AudioQueueFreeBuffer(inAQ, inBuffer)
            }
        }
        
        let err = AudioQueueNewInput(&audioStreamDescription,
                                     callback,
                                     Unmanaged.passUnretained(self).toOpaque(),
                                     nil, nil, 0, &audioQueue)
        if err != noErr {
            fatalError("Unable to create new output audio queue (\(err))")
        }
    }
    
    // Function to activate the microphone
    func activateMicrophone() {
        guard let audioQueue = audioQueue else { return }
            enqueueBuffers()
            let err = AudioQueueStart(audioQueue, nil)
            if err == noErr {
                isMicrophoneActive = true
            } else {
                NSLog("AudioQueueStart failed with error (\(err))")
            }
    }
    
    // Function to deactivate the microphone
    func deactivateMicrophone() {
        isMicrophoneActive = false
        guard let audioQueue = audioQueue else { return }
        
        let err = AudioQueueStop(audioQueue, true)
        if err != noErr {
            NSLog("AudioQueueStop failed with error (\(err))")
        }
        
        dequeueBuffers()
    }
    
    // Function to enqueue audio buffers
    func enqueueBuffers() {
        guard let audioQueue = audioQueue else { return }
        
        let format = audioStreamDescription
        let bufferSize = UInt32(format.mSampleRate) * UInt32(format.mBytesPerFrame) / 1000 * UInt32(30)// It calculates the buffer size in bytes based on the sample rate, bytes per frame, and a duration of 30 milliseconds. This buffer size determines how much audio data can be stored in each buffer
        for _ in 0 ..< 3 {
            //This loop runs three times, indicating that it will create and enqueue three audio buffers. These buffers will be used for storing audio data during recording.
            var buffer: AudioQueueBufferRef?
            var err = AudioQueueAllocateBuffer(audioQueue, bufferSize, &buffer)
            if (err != noErr) {
                NSLog("Failed to allocate buffer for audio recording (\(err))")
                continue
            }
            
            err = AudioQueueEnqueueBuffer(audioQueue, buffer!, 0, nil)
            if (err != noErr) {
                NSLog("Failed to enqueue buffer for audio recording (\(err))")
            }
            audioBuffers.append(buffer!)
        }
    }
    
    // Function to dequeue audio buffers and process sample data
    func dequeueBuffers() {
        guard let audioQueue = audioQueue else { return }
        while let buffer = audioBuffers.popLast() {
            AudioQueueFreeBuffer(audioQueue, buffer)
        }
    }
    
    // Function to process sample buffer data and detect voice activity
    func didReceivceSampleBuffer(buffer: AudioQueueBuffer) {
        let frames = buffer.mAudioData.assumingMemoryBound(to: Int16.self)
        var count = Int(buffer.mAudioDataByteSize) / MemoryLayout<Int16>.size
        let detectorFrameUnit = Int(audioStreamDescription.mSampleRate) * VoiceActivityDetector.Duration.msec10.rawValue / 1000 // It calculates the frame unit size required by the Voice Activity Detector (VAD). This is based on the sample rate of the audio stream and a predefined duration (msec10 is typically 10 milliseconds).
        
        count = count - (count % detectorFrameUnit)//It ensures that the count of frames is a multiple of the detectorFrameUnit. This step helps in aligning the audio data with the VAD's frame size, ensuring consistent analysis.
        guard 0 < count else { return }
        
        let voiceActivity = voiceActivityDetector.detect(frames: frames, count: count)
        DispatchQueue.main.async {
            self.voiceActivity = voiceActivity
        }
    }
}

// Extension to provide descriptions for VoiceActivityDetector's DetectionAggressiveness enum cases
extension VoiceActivityDetector.DetectionAggressiveness {
    var description: String {
        switch self {
        case .quality:
            return "quality"
        case .lowBitRate:
            return "lowBitRate"
        case .aggressive:
            return "aggressive"
        case .veryAggressive:
            return "veryAggressive"
        }
    }
}
