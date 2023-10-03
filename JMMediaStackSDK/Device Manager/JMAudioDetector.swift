//
//  JMAudioDetector.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 03/10/23.
//

import Foundation
import AVFoundation.AVFAudio
import VoiceActivityDetector

class JMAudioDetector:NSObject {
    var timer1: Timer?
    var timer2: Timer?
    var event1Timestamp: Date?
    
    // Initialize Voice Activity Detector
    let voiceActivityDetector = VoiceActivityDetector(agressiveness: .veryAggressive)!
    var voiceActivity: VoiceActivityDetector.VoiceActivity? {
      didSet {
        guard oldValue != voiceActivity else { return }
        if let voiceActivity = voiceActivity {
          switch voiceActivity {
          case .activeVoice:
              scheduleSpeechTimeoutStart()
          case .inActiveVoice:
              scheduleSpeechTimeoutEnd()
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
    
    var toastCallback: (() -> Void)?
    var speakEndCounter = 0
    override init() {
        super.init()
        setupAudioRecording()
        activateMicrophone()
    }
    
    func dispose() {
        timer1?.invalidate()
        timer1 = nil
        timer2?.invalidate()
        timer2 = nil

        deactivateMicrophone()

        audioBuffers.removeAll()
        audioQueue = nil

        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    // MARK: - Voice Activity Detection
    @objc func startSpeechTimeout() {
        print("VAD- start")
        toastCallback?()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    @objc func endSpeechTimeout() {
        print("VAD- stop")
        speakEndCounter = speakEndCounter + 1
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    func scheduleSpeechTimeoutStart() {
        perform(#selector(startSpeechTimeout), with: nil, afterDelay: 2.5)
    }
    
    func scheduleSpeechTimeoutEnd() {
        perform(#selector(endSpeechTimeout), with: nil, afterDelay: 1.9)
        if speakEndCounter % 3 == 0 {
            toastCallback?()
            NSObject.cancelPreviousPerformRequests(withTarget: self)
        }
    }
    
    // MARK: - Audio Recording
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
    
    func activateMicrophone() {
        guard let audioQueue = audioQueue else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setActive(true)
            try audioSession.setPreferredSampleRate(audioStreamDescription.mSampleRate)
            
            enqueueBuffers()
            
            let err = AudioQueueStart(audioQueue, nil)
            if err == noErr {
                isMicrophoneActive = true
            } else {
                NSLog("AudioQueueStart failed with error (\(err))")
            }
        } catch {
            print(error.localizedDescription)
            dequeueBuffers()
        }
    }
    
    func deactivateMicrophone() {
        isMicrophoneActive = false
        guard let audioQueue = audioQueue else { return }
        
        let err = AudioQueueStop(audioQueue, true)
        if err != noErr {
            NSLog("AudioQueueStop failed with error (\(err))")
        }
        
        dequeueBuffers()
    }
    
    func enqueueBuffers() {
        guard let audioQueue = audioQueue else { return }
        
        let format = audioStreamDescription
        let bufferSize = UInt32(format.mSampleRate) * UInt32(format.mBytesPerFrame) / 1000 * UInt32(30)
        for _ in 0 ..< 3 {
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
    
    func dequeueBuffers() {
        guard let audioQueue = audioQueue else { return }
        while let buffer = audioBuffers.popLast() {
            AudioQueueFreeBuffer(audioQueue, buffer)
        }
    }
    
    func didReceivceSampleBuffer(buffer: AudioQueueBuffer) {
        let frames = buffer.mAudioData.assumingMemoryBound(to: Int16.self)
        var count = Int(buffer.mAudioDataByteSize) / MemoryLayout<Int16>.size
        let detectorFrameUnit = Int(audioStreamDescription.mSampleRate) * VoiceActivityDetector.Duration.msec10.rawValue / 1000
        count = count - (count % detectorFrameUnit)
        guard 0 < count else { return }
        
        let voiceActivity = voiceActivityDetector.detect(frames: frames, count: count)
        DispatchQueue.main.async {
            self.voiceActivity = voiceActivity
        }
    }
}

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
