//
//  AudioDeviceManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 31/07/23.
//

import AVFoundation
import UIKit

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

class JMAudioDeviceManager: NSObject {
    public static let shared = JMAudioDeviceManager()
    internal var delegateToManager: delegateManager? = nil
    
    var audioDetector:JMAudioDetector? = nil
    private let audioSession = AVAudioSession.sharedInstance()
    private var supportedCategory: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker,
        .allowBluetooth,
        .allowBluetoothA2DP,
        .allowAirPlay,
        
        // 'duckOthers' - app's audio should interrupt and lower the volume of other audio, but resume the other audio when your app's audio finishes.
        .duckOthers,
        
        // 'interruptSpokenAudioAndMixWithOthers' - app's audio should take priority over spoken audio from other apps and mix with non-spoken audio
        .interruptSpokenAudioAndMixWithOthers
    ]
    
    private var isDevicePreferenceIsSet: Bool = false
    private var currentDevice: AVAudioDevice?
    private var userSelectedDevice: AVAudioDevice?
    
    private override init() {
        super.init()
    }
    
    func setupSession(){
        setupNotifications()
        addAudioDetectorCallbackListener()
        
        /*
        if #available(iOS 14.5, *) {
            // 'overrideMutedMicrophoneInterruption' - app's audio to override the device's microphone mute setting during audio interruptions, ensuring the microphone is active when needed
            supportedCategory.insert(.overrideMutedMicrophoneInterruption)
        }
        */
        
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord,
                                         mode: AVAudioSession.Mode.default,
                                         options: supportedCategory)
            try audioSession.setActive(true)
            LOG.debug("AVAudioDevice- audio session category set.")
        }
        catch let error as NSError {
            LOG.error("AVAudioDevice- Failed to set the audio session category and mode: \(error.localizedDescription)")
        }
                
//        try session.setPreferredSampleRate(44_100)
//        try session.setPreferredIOBufferDuration(0.005)
    }
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(self,selector: #selector(handleSecondaryAudio),name: AVAudioSession.silenceSecondaryAudioHintNotification,object: audioSession)
        NotificationCenter.default.addObserver(self,selector: #selector(handleInterruption),name: AVAudioSession.interruptionNotification,object: audioSession)
        NotificationCenter.default.addObserver(self,selector: #selector(handleRouteChange),name: AVAudioSession.routeChangeNotification,object: audioSession)
    }
    
    func dispose(){
       try? audioSession.setActive(false)
        delegateToManager = nil
        isDevicePreferenceIsSet = false
        userSelectedDevice = nil
        removeAudioDetectorCallbackListener()
        
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    internal func getSystemVolume() -> Double{
        return Double(audioSession.outputVolume) * 10
    }
}

//MARK: Public to Client
extension JMAudioDeviceManager{
    internal func getAllDevices() -> [AVAudioDevice] {
        guard let availableInputs = audioSession.availableInputs else { return [] }
        LOG.debug("AVAudioDevice- devices: \(availableInputs)")
        return availableInputs
    }
    
    internal func getAllJMDevices() -> [JMAudioDevice] {
        var availableDevice = getAllDevices().map { $0.format() }
        
        if UIDevice.current.userInterfaceIdiom == .phone { //Only iPhone has earpiece
            availableDevice.append(JMAudioDevice(deviceName: "Earpiece", deviceType: .Earpiece, deviceUid: "Earpiece"))
        }
        
        LOG.debug("AVAudioDevice- devices: \(availableDevice)")
        return availableDevice
    }
    
    internal func getCurrentDevice() -> (AVAudioDevice?,JMMediaError?){
        let currentRoute = audioSession.currentRoute
        
        guard let inputDevice = currentRoute.inputs.first,
              let outputDevice = currentRoute.outputs.first else {
            LOG.error("AVAudioDevice- No device selected")
            return (nil,JMMediaError(type: .audioDeviceNotAvailable, description: "No device found"))
        }

        if inputDevice.portType == outputDevice.portType {
            LOG.debug("AVAudioDevice- Device in use:\(inputDevice.portName)")
        }
        else{
            LOG.warning("AVAudioDevice- Input device:\(inputDevice.portName)| Output device:\(outputDevice.portName)")
        }
        
        currentDevice = outputDevice
        return (outputDevice,nil)
    }
    
    internal func setJMAudioDevice(_ jmDevice: JMAudioDevice){
        
        if jmDevice.deviceType == .Speaker{
            setAudioPort(toSpeaker: true)
        }
        else if jmDevice.deviceType == .Earpiece{
            setAudioPort(toSpeaker: false)
        }
        else if let avDevice = jmDevice.device{
            setAudioDevice(avDevice)
        }
        else{
            LOG.error("AVAudioDevice- failed to get device for object: \(jmDevice.deviceName)|\(jmDevice.deviceUid)|\(jmDevice.deviceType)")
        }
    }
    
    private func setAudioDevice(_ device: AVAudioDevice){
        do {
            try audioSession.setPreferredInput(device)
            try audioSession.setActive(true)
            LOG.debug("AVAudioDevice- set device to \(device.portName)")
        }
        catch {
            LOG.error("AVAudioDevice- Failed to setPreferredInput : \(error.localizedDescription)")
            delegateToManager?.sendClientError(error: JMMediaError.init(type: .audioSetDeviceFailed, description: error.localizedDescription))
        }
    }
    
    private func fetchCurrentDeviceAndUpdate(){
        let deviceStatus = getCurrentDevice()
        if let device = deviceStatus.0, device.uid != userSelectedDevice?.uid{
            LOG.debug("AVAudioDevice- UI updated")
            userSelectedDevice = device
            delegateToManager?.sendClientAudioDeviceInUse(device)
        }
        else if let error = deviceStatus.1{
            delegateToManager?.sendClientError(error: error)
        }
    }
}

//MARK: Helpers
extension JMAudioDeviceManager{
    private func getAllDeviceAndSetPreference() {
        let availableInputs = getAllDevices()
        
        if availableInputs.isEmpty{
            LOG.error("AVAudioDevice- No inputs found")
            return
        }
        
        if let bluetoothDevice = availableInputs.first(where: { $0.portType.rawValue.lowercased().contains("bluetooth") || $0.portType.rawValue.lowercased().contains("head") }) {
            // Find the first Bluetooth device (headsetMic or headphones)
            setAudioDevice(bluetoothDevice)
        }
        else{
            // If Bluetooth device is not available, use the built-in speaker
            setAudioPort(toSpeaker: true)
        }
        
        isDevicePreferenceIsSet = true
    }
    
    private func setAudioPort(toSpeaker speaker: Bool){
        do {
            try audioSession.overrideOutputAudioPort(speaker ? .speaker : .none)
            try audioSession.setActive(true)
            LOG.debug("AVAudioDevice- set device to Speaker (override)")
        }
        catch {
            LOG.error("AVAudioDevice- Failed to force set to speaker : \(error.localizedDescription)")
        }
    }
    
    //NOT IN USE
    private func audioOutputDeviceCorrection() -> Bool{
        let currentRoute = audioSession.currentRoute.outputs.first
        if currentRoute?.portType == .builtInReceiver{
            if currentDevice?.portType != .builtInReceiver{
                setAudioPort(toSpeaker: true)
                return true
            }
        }
        return false
    }
}

//MARK: Callback from AVSession
extension JMAudioDeviceManager{
    @objc func handleRouteChange(_ notification: Notification) {
        //LOG.debug("AVAudioDevice- callback \(notification.userInfo)")
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
            LOG.debug("AVAudioDevice- callback no object.")
            return
         }
        
        LOG.debug("AVAudioDevice- Reason:\(reasonValue)")
        if reason == .categoryChange{
            
            if isDevicePreferenceIsSet{
                return
            }
            
            //Note - Consider this as - onAudioSessionConnected - now we can perform our task.
            //This logic is only needed once after setting the Category, as we need to change the output route to speaker if no device is found.
            
           // guard let route = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
            //if !route.inputs.isEmpty{
                LOG.debug("AVAudioDevice- Setting Device preference.")
                getAllDeviceAndSetPreference()
                fetchCurrentDeviceAndUpdate()
                audioDetector?.setupSession()
           // }
        }
        else if reason == .newDeviceAvailable{
            LOG.debug("AVAudioDevice- callback device change")
            fetchCurrentDeviceAndUpdate()
        }
        else if reason == .oldDeviceUnavailable || reason == .override{
            
            //NO need to correct now, as we are supported earpiece as well. will remove commnet post few releases.
//            if audioOutputDeviceCorrection(){
//                LOG.debug("AVAudioDevice- Audio corrected to speaker.")
//            }
            
            fetchCurrentDeviceAndUpdate()
        }
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
        }
        else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                LOG.debug("AVAudioDevice- callback no AVAudioSessionInterruptionOptionKey.")
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Interruption Ended - playback should resume
                LOG.debug("AVAudioDevice- callback Interruption Ended - Audio is transmission resumed.")
            }
        }
     }
}

extension AVAudioDevice{
    
    func format() -> JMAudioDevice{
        return JMAudioDevice(deviceName: self.portName, deviceType: getJMDeviceType(self.portType), deviceUid: self.uid, device: self)
    }
    
    private func getJMDeviceType(_ portType:  AVAudioSession.Port) -> JMAudioDeviceType {
        
        switch portType {
            
        case .builtInMic, .builtInSpeaker:
            return .Speaker
            
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            return .Bluetooth
            
        case .headsetMic, .headphones:
            return .Bluetooth
            
        case .builtInReceiver:
            return .Earpiece
            
//        case .carAudio, .airPlay, .HDMI:
            
        default:
            return .UnKnown
        }
    }
}

//MARK: VAD
extension JMAudioDeviceManager{
    func addAudioDetectorCallbackListener(){
        audioDetector = JMAudioDetector()
        self.audioDetector?.toastCallback = { [weak self] in
            self?.delegateToManager?.sendClientSpeakOnMute()
        }
    }
    
    func removeAudioDetectorCallbackListener(){
        self.audioDetector?.toastCallback = nil
        self.audioDetector?.dispose()
        audioDetector = nil
    }
}
