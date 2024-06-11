//
//  AudioDeviceManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 31/07/23.
//

import AVFoundation
import UIKit
import WebRTC

public enum JMAudioDeviceType: String{
    case Speaker
    case Bluetooth
    case Earpiece
    case UnKnown
}
public struct JMAudioDevice{
    public var deviceName: String = ""
    public var deviceType: JMAudioDeviceType = .UnKnown
    public var deviceUid: String = ""
    public var device: AVAudioDevice?
    
    init(deviceName: String, deviceType: JMAudioDeviceType, deviceUid: String, device: AVAudioDevice? = nil) {
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.deviceUid = deviceUid
        self.device = device
    }
}
public typealias AVAudioDevice = AVAudioSessionPortDescription

import AVFoundation
import UIKit
import MediaPlayer
import WebRTC

protocol JMAudioDeviceManagerDelegate: AnyObject {
    func audioSessionDidBeginInterruption()
    func audioSessionDidEndInterruption(shouldResumeSession: Bool)
    func audioSessionDidChangeRoute(reason: AVAudioSession.RouteChangeReason)
    func audioSessionMediaServerTerminated()
    func audioSessionMediaServerReset()
    func audioSessionDidChangeOutputVolume(outputVolume: Float)
    func audioSessionDidSetActive(active: Bool)
    func audioSessionFailedToSetActive(active: Bool, error: Error)
}

class JMAudioDeviceManager: NSObject, RTCAudioSessionDelegate {
    public static let shared = JMAudioDeviceManager()
    internal var delegateToManager: delegateManager? = nil
    weak var delegate: JMAudioDeviceManagerDelegate?
    
    var audioDetector: JMAudioDetector? = nil
    private let audioSession = AVAudioSession.sharedInstance()
    let audioSessionQueue = DispatchQueue(label: "com.example.AudioSessionQueue")
    
    private var supportedCategory: AVAudioSession.CategoryOptions = [
       // .defaultToSpeaker,
        .allowBluetooth,
      //  .allowBluetoothA2DP,
        .allowAirPlay,
        //.duckOthers
        //.mixWithOthers
    ]
    
    private var isDevicePreferenceIsSet: Bool = false
    private var currentDevice: AVAudioDevice?
    private var userSelectedDevice: AVAudioDevice?
    private var isDeviceSpeakerSet: Bool = false
    public var isWatchPartyEnabled: Bool = false
    
    private override init() {
        super.init()
        RTCAudioSession.sharedInstance().add(self)
    }
    
//    fileprivate func setAudioSession() {
//        audioSessionQueue.async {
//            do {
//                try self.audioSession.setCategory(.playAndRecord, mode: .default, options: self.supportedCategory)
//                try self.audioSession.setActive(true)
//                //try audioSession.setPreferredInput(.none)
//                LOG.debug("AVAudioDevice- audio session category set.")
//            } catch {
//                LOG.error("AVAudioDevice- Failed to set the audio session category and mode: \(error.localizedDescription)")
//            }
//        }
//    }
    
    func setupSession() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.isDeviceSpeakerSet = true
        }
            self.setupWebRTCSession(true)
            self.setupNotifications()
            self.addAudioDetectorCallbackListener()
            self.configureRTCAudioSession()
            self.delegate?.audioSessionDidSetActive(active: true)
    }
    
    func configureRTCAudioSession() {
        let audioSession = RTCAudioSession.sharedInstance()
        
        // Create an RTCAudioSessionConfiguration instance
        let configuration = RTCAudioSessionConfiguration()
       
        // Set the desired category, mode, and options
        configuration.category = AVAudioSession.Category.playAndRecord.rawValue
        configuration.mode =  self.isWatchPartyEnabled ? AVAudioSession.Mode.default.rawValue : AVAudioSession.Mode.voiceChat.rawValue
        configuration.categoryOptions = [.allowBluetooth,.mixWithOthers]//[ .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .duckOthers,.defaultToSpeaker]
        
        RTCAudioSessionConfiguration.setWebRTC(configuration)
        //audioSessionQueue.async {
            audioSession.lockForConfiguration()
            do {
                try audioSession.setConfiguration(configuration, active: true)
                LOG.debug("AVAudioDevice- RTCAudioSession configuration set successfully.")
            } catch {
                LOG.debug("AVAudioDevice- Failed to set RTCAudioSession configuration: \(error.localizedDescription)")
            }
            RTCAudioSessionConfiguration.setWebRTC(configuration)
            audioSession.unlockForConfiguration()
        
      //  }
    }

    
    func setupNotifications() {
        audioSessionQueue.async {
            NotificationCenter.default.addObserver(self, selector: #selector(self.handleSecondaryAudio), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: self.audioSession)
            NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption), name: AVAudioSession.interruptionNotification, object: self.audioSession)
            NotificationCenter.default.addObserver(self, selector: #selector(self.handleRouteChange), name: AVAudioSession.routeChangeNotification, object: self.audioSession)
        }
    }
    
    func dispose() {
        audioSessionQueue.async {
            LOG.debug("AVAudioDevice- disposed.")
            self.setupWebRTCSession(false)
            if !self.isWatchPartyEnabled {
                try? self.audioSession.setActive(false)
            }
            self.delegateToManager = nil
            self.isDevicePreferenceIsSet = false
            self.userSelectedDevice = nil
            self.removeAudioDetectorCallbackListener()
            self.isDeviceSpeakerSet = false
            
            NotificationCenter.default.removeObserver(self, name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        }
    }
    
    internal func getSystemVolume() -> Double {
        return Double(audioSession.outputVolume) * 10
    }
}

// MARK: - Public to Client
extension JMAudioDeviceManager {
    internal func getAllDevices() -> [AVAudioDevice] {
        guard let availableInputs = audioSession.availableInputs else { return [] }
        return availableInputs
    }
    
    internal func getAllJMDevices() -> [JMAudioDevice] {
        var availableDevice = getAllDevices().map { $0.format() }
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            availableDevice.append(JMAudioDevice(deviceName: "Earpiece", deviceType: .Earpiece, deviceUid: "Earpiece"))
        }
        
        LOG.debug("AVAudioDevice- devices: \(availableDevice)")
        return availableDevice
    }
    
    internal func getCurrentDevice() -> (AVAudioDevice?, JMMediaError?) {
        let currentRoute = audioSession.currentRoute
        
        guard let inputDevice = currentRoute.inputs.first,
              let outputDevice = currentRoute.outputs.first else {
            LOG.error("AVAudioDevice- No device selected")
            return (nil, JMMediaError(type: .audioDeviceNotAvailable, description: "No device found"))
        }
        
        currentDevice = outputDevice
        return (outputDevice, nil)
    }
    
    internal func setJMAudioDevice(_ jmDevice: JMAudioDevice) {
        audioSessionQueue.async {
            if jmDevice.deviceType == .Speaker {
                self.setAudioPort(toSpeaker: true)
            } else if jmDevice.deviceType == .Earpiece {
                self.setAudioPort(toSpeaker: false)
            } else if let avDevice = jmDevice.device {
                self.setAudioDevice(avDevice)
            } else {
                LOG.error("AVAudioDevice- failed to get device for object: \(jmDevice.deviceName)|\(jmDevice.deviceUid)|\(jmDevice.deviceType)")
            }
        }
    }
    
    private func setAudioDevice(_ device: AVAudioDevice) {
        do {
            try audioSession.setPreferredInput(device)
            try audioSession.setActive(true)
            LOG.debug("AVAudioDevice- set device to \(device.portName)")
        } catch {
            LOG.error("AVAudioDevice- Failed to setPreferredInput: \(error.localizedDescription)")
            delegateToManager?.sendClientError(error: JMMediaError(type: .audioSetDeviceFailed, description: error.localizedDescription))
        }
    }
    
    private func fetchCurrentDeviceAndUpdate() {
        let deviceStatus = getCurrentDevice()
        if let device = deviceStatus.0, device.uid != userSelectedDevice?.uid {
            LOG.debug("AVAudioDevice- userSelectedDevice-\(device)")
            userSelectedDevice = device
            delegateToManager?.sendClientAudioDeviceInUse(device)
        } else if let error = deviceStatus.1 {
            delegateToManager?.sendClientError(error: error)
        }
    }
}

// MARK: - Helpers
extension JMAudioDeviceManager {
    private func getAllDeviceAndSetPreference() {
        let availableInputs = getAllDevices()
        
        if availableInputs.isEmpty {
            LOG.error("AVAudioDevice- No inputs found")
            return
        }
        
        if let bluetoothDevice = availableInputs.first(where: { $0.portType.rawValue.lowercased().contains("bluetooth") || $0.portType.rawValue.lowercased().contains("head") }) {
            setAudioDevice(bluetoothDevice)
        } else {
            setAudioPort(toSpeaker: true)
        }
        
        isDevicePreferenceIsSet = true
    }
    
    private func setAudioPort(toSpeaker speaker: Bool) {
        do {
            try audioSession.overrideOutputAudioPort(speaker ? .speaker : .none)
            LOG.debug("AVAudioDevice- set device to Speaker (override)")
        } catch {
            LOG.error("AVAudioDevice- Failed to force set to speaker: \(error.localizedDescription)")
        }
    }
    
    private func audioOutputDeviceCorrection() -> Bool {
        let currentRoute = audioSession.currentRoute.outputs.first
        if currentRoute?.portType == .builtInReceiver {
            if currentDevice?.portType != .builtInReceiver {
                setAudioPort(toSpeaker: true)
                return true
            }
        }
        return false
    }
}

// MARK: - Correction
extension JMAudioDeviceManager {
    private func getCurrentRouteDevice() -> AVAudioDevice? {
        return audioSession.currentRoute.outputs.first
    }
    
    private func devicePreferenceAlgorithm() {
        let currentDevice = getCurrentRouteDevice()
        if let currentDevice = currentDevice {
            if currentDevice.portType == .builtInReceiver {
                LOG.debug("AVAudioDevice- correcting receiver.")
                let availableInputs = getAllDevices()
                LOG.debug("AVAudioDevice- Available Devices - \(availableInputs.map { $0.portName })")
                if let bluetoothDevice = availableInputs.first(where: { $0.portType.rawValue.lowercased().contains("bluetooth") || $0.portType.rawValue.lowercased().contains("head") }) {
                    setAudioDevice(bluetoothDevice)
                } else {
                    setAudioPort(toSpeaker: true)
                }
            }
        }
    }
    
    func setupWebRTCSession(_ isActive: Bool) {
        RTCAudioSession.sharedInstance().useManualAudio = isActive
        isActive ? RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession) : RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = isActive
    }
}

// MARK: - Callback from AVSession
extension JMAudioDeviceManager {
    @objc func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            LOG.debug("AVAudioDevice- handleRouteChange callback no object.")
            return
        }
        self.delegate?.audioSessionDidChangeRoute(reason: reason)
        LOG.debug("AVAudioDevice- Category:\( self.audioSession.category.rawValue) | Mode:\( self.audioSession.mode.rawValue)")
        LOG.debug("AVAudioDevice- categoryOptions:\(  self.audioSession.categoryOptions.description) | Mode:\( self.audioSession.mode.rawValue)")
        
        if  self.audioSession.mode == .voiceChat && self.isWatchPartyEnabled {
            LOG.debug("AVAudioDevice- Mode going to change:\( self.audioSession.mode.rawValue)")
            self.configureRTCAudioSession()
            self.devicePreferenceAlgorithm()
        }
        // }
        if !self.isDeviceSpeakerSet {
            LOG.debug("AVAudioDevice- initial setup")
            self.devicePreferenceAlgorithm()
            self.audioDetector?.setupSession()
        }
        switch reason {
        case .newDeviceAvailable:
            self.devicePreferenceAlgorithm()
            LOG.debug("AVAudioDevice- New device available")
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                LOG.debug("AVAudioDevice- Previous route: \(previousRoute)")
            }
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            for output in currentRoute.outputs {
                LOG.debug("AVAudioDevice- Current output: \(output.portName), port type: \(output.portType.rawValue)")
            }
            
        case .oldDeviceUnavailable:
            LOG.debug("AVAudioDevice- Old device unavailable")
            self.devicePreferenceAlgorithm()
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                LOG.debug("AVAudioDevice- Previous route: \(previousRoute)")
            }
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            for output in currentRoute.outputs {
                LOG.debug("AVAudioDevice- Current output: \(output.portName), port type: \(output.portType.rawValue)")
            }
            
        case .override:
            LOG.debug("AVAudioDevice- Override")
            if self.audioSession.currentRoute.outputs.first?.portType  == .builtInSpeaker{
                self.setAudioPort(toSpeaker: true)
                LOG.debug("AVAudioDevice- reason == .override Speaker")
            }
        @unknown default: break;
        }
        self.fetchCurrentDeviceAndUpdate()
    }
        
    @objc func handleSecondaryAudio(notification: Notification) {
        LOG.debug("AVAudioDevice- callback \(String(describing: notification.userInfo))")
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            LOG.debug("AVAudioDevice- callback no object.")
            return
        }
     
        if type == .begin {
            LOG.debug("AVAudioDevice- callback Other app audio started playing - mute secondary audio")
            // Other app audio started playing - mute secondary audio
        } else {
            LOG.debug("AVAudioDevice- callback Other app audio stopped playing - restart secondary audio")
            // Other app audio stopped playing - restart secondary audio
        }
    }
    
    @objc func handleInterruption(_ notification: Notification) {
        LOG.debug("AVAudioDevice- callback \(String(describing: notification.userInfo))")
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            LOG.debug("AVAudioDevice- callback no object.")
            return
        }
        
        if type == .began {
            // Interruption began, take appropriate actions (save state, update user interface)
            LOG.debug("AVAudioDevice- callback Interruption began, Audio is transmission stopped.")
            delegate?.audioSessionDidBeginInterruption()
        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                LOG.debug("AVAudioDevice- callback no AVAudioSessionInterruptionOptionKey.")
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Interruption Ended - playback should resume
                LOG.debug("AVAudioDevice- callback Interruption Ended - Audio is transmission resumed.")
                delegate?.audioSessionDidEndInterruption(shouldResumeSession: true)
            } else {
                delegate?.audioSessionDidEndInterruption(shouldResumeSession: false)
            }
        }
    }
}

extension AVAudioDevice {
    func format() -> JMAudioDevice {
        return JMAudioDevice(deviceName: self.portName, deviceType: getJMDeviceType(self.portType), deviceUid: self.uid, device: self)
    }
    
    private func getJMDeviceType(_ portType: AVAudioSession.Port) -> JMAudioDeviceType {
        switch portType {
        case .builtInMic, .builtInSpeaker:
            return .Speaker
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            return .Bluetooth
        case .headsetMic, .headphones:
            return .Bluetooth
        case .builtInReceiver:
            return .Earpiece
        default:
            return .UnKnown
        }
    }
}

// MARK: - VAD
extension JMAudioDeviceManager {
    func addAudioDetectorCallbackListener() {
        if audioDetector != nil {
            audioDetector = JMAudioDetector()
            self.audioDetector?.toastCallback = { [weak self] in
                self?.delegateToManager?.sendClientSpeakOnMute()
            }
        }
    }
    
    func removeAudioDetectorCallbackListener() {
        self.audioDetector?.toastCallback = nil
        audioDetector?.dispose()
        audioDetector = nil
    }
    func audioSession(_ audioSession: RTCAudioSession, didDetectPlayoutGlitch totalNumberOfGlitches: Int64) {
        print("didDetectPlayoutGlitch \(totalNumberOfGlitches)")
    }
}

extension AVAudioSession.CategoryOptions: CustomStringConvertible {
    public var description: String {
        var options = [String]()
        if contains(.mixWithOthers) { options.append("mixWithOthers") }
        if contains(.duckOthers) { options.append("duckOthers") }
        if contains(.interruptSpokenAudioAndMixWithOthers) { options.append("interruptSpokenAudioAndMixWithOthers") }
        if contains(.allowBluetooth) { options.append("allowBluetooth") }
        if contains(.allowBluetoothA2DP) { options.append("allowBluetoothA2DP") }
        if contains(.allowAirPlay) { options.append("allowAirPlay") }
        if contains(.defaultToSpeaker) { options.append("defaultToSpeaker") }
        if #available(iOS 14.5, *), contains(.overrideMutedMicrophoneInterruption) { options.append("overrideMutedMicrophoneInterruption") }
        
        return options.joined(separator: ", ")
    }
}
