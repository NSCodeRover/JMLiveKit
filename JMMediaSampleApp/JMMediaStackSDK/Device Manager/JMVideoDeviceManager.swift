//
//  JMVideoDeviceManager.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 31/07/23.
//

import Foundation
import AVFoundation
import WebRTC

public enum JMVideoDeviceType: String{
    case FrontCamera = "Front Camera"
    case RearCamera = "Back Camera"
    
    //FutureScope
    case RearCamera_Telephoto = "Back Camera (Depth)"
    case RearCamera_WideAngle = "Back Camera (Wide)"
    case UnKnown = "Camera"
}
public struct JMVideoDevice{
    public var deviceName: String = ""
    public var deviceType: JMVideoDeviceType = .UnKnown
    public var deviceUid: String = ""
    public var device: AVVideoDevice?
    
    init(deviceName: String, deviceType: JMVideoDeviceType, deviceUid: String, device: AVVideoDevice? = nil) {
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.deviceUid = deviceUid
        self.device = device
    }
}
public typealias AVVideoDevice = AVCaptureDevice

class JMVideoDeviceManager: NSObject{
    public static let shared = JMVideoDeviceManager()
    internal var delegateToManager: delegateManager? = nil
    
    private var videoSession: AVCaptureSession = AVCaptureSession()
    private var supportedCategory: [AVCaptureDevice.DeviceType] = [
        .builtInTelephotoCamera,
        .builtInWideAngleCamera
    ]
    
    private var isDevicePreferenceIsSet: Bool = false
    private var currentDevice: AVVideoDevice?
    private var userSelectedDevice: AVVideoDevice?
    
    private override init() {
        super.init()
        
        if #available(iOS 13.0, *) {
            supportedCategory.append(.builtInUltraWideCamera)
        }
    }
        
    func setupSession(){
        setupNotifications()
        
        let devices = getAllDevices()
        if devices.isEmpty{
            LOG.error("AVVideoDevice- No device found")
        }
        
        if let frontCamera = devices.first(where: { $0.position == .front }){
            currentDevice = frontCamera
        }
        else{
            currentDevice = devices.first
        }
    }
    
    private func setupNotifications() {
        
        //Interruption
        NotificationCenter.default.addObserver(self, selector: #selector(handleCaptureSessionInterruption(_:)), name: .AVCaptureSessionWasInterrupted, object: videoSession)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCaptureSessionInterruptionEnded(_:)), name: .AVCaptureSessionInterruptionEnded, object: videoSession)
        
        //Error
        NotificationCenter.default.addObserver(self, selector: #selector(handleCaptureSessionRuntimeError(_:)), name: .AVCaptureSessionRuntimeError, object: videoSession)
        
        //Background Foreground
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWentIntoBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func dispose(){
        delegateToManager = nil
        isDevicePreferenceIsSet = false
        userSelectedDevice = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

extension JMVideoDeviceManager{
    
    internal func getCameraDevice()->AVVideoDevice?{
        if let userSelected = userSelectedDevice{
            return userSelected
        }
        else{
            return currentDevice
        }
    }
    
    
    internal func fetchPreferredResolutionFormat(_ cameraDevice: AVCaptureDevice) -> AVCaptureDevice.Format?{
        let allFormats = RTCCameraVideoCapturer.supportedFormats(for: cameraDevice)
        let desiredWidth = JioMediaStackDefaultCameraCaptureResolution.width
        let desiredHeight = JioMediaStackDefaultCameraCaptureResolution.height
            
        if #available(iOS 13.0, *){
            if let preferredFormat = allFormats.first(where: { $0.formatDescription.dimensions.width == desiredWidth && $0.formatDescription.dimensions.height == desiredHeight }) {
                //We will find the exact desired resolution
                LOG.debug("Video- found the exact match - \(preferredFormat.formatDescription.dimensions)")
                return preferredFormat
            }
            else{
                //If exact resolution is not available, find the closest resolution
                let closestFormat = allFormats.min(by: {
                    abs($0.formatDescription.dimensions.width - desiredWidth) < abs($1.formatDescription.dimensions.width - desiredWidth) ||
                    abs($0.formatDescription.dimensions.height - desiredHeight) < abs($1.formatDescription.dimensions.height - desiredHeight)
                })
                LOG.debug("Video- didn't found the exact match. The closest format - \(closestFormat?.formatDescription.dimensions)")
                return closestFormat
            }
        }
        else{
            //iOS below 13.0
            for format in cameraDevice.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if format.highResolutionStillImageDimensions.width == desiredWidth &&
                        format.highResolutionStillImageDimensions.height == desiredHeight &&
                        Int32(range.maxFrameRate) >= JioMediaStackDefaultCameraCaptureResolution.fps {
                        return format
                    }
                }
            }
        }
        
        return nil
    }
}

//MARK: PUBLIC access to client
extension JMVideoDeviceManager{
    
    internal func getAllDevices() -> [AVVideoDevice]{
        let availableInputs = AVCaptureDevice.DiscoverySession.init(deviceTypes: supportedCategory, mediaType: .video, position: .unspecified).devices
        LOG.debug("AVVideoDevice- devices: \(availableInputs)")
        return filterOnlyFrontAndRear(availableInputs)
    }
    
    internal func setVideoDevice(_ device: AVVideoDevice){
        videoSession.beginConfiguration()
        do {
            try AVCaptureDeviceInput(device: device)
            userSelectedDevice = device
            delegateToManager?.sendClientVideoDeviceInUse(device)
        }
        catch {
            LOG.error("AVVideoDevice- Failed to AVCaptureDeviceInput : \(error.localizedDescription)")
            delegateToManager?.sendClientError(error: JMMediaError.init(type: .videoSetDeviceFailed, description: "No device found."))
        }
        videoSession.commitConfiguration()
    }
    
    private func filterOnlyFrontAndRear(_ devices: [AVVideoDevice]) -> [AVVideoDevice]{
        return devices //.filter { $0.deviceType == .builtInWideAngleCamera }
    }
}

extension AVVideoDevice{
    
    func format() -> JMVideoDevice{
        return JMVideoDevice(deviceName: self.localizedName, deviceType: getJMDeviceType(self.deviceType,position: self.position), deviceUid: self.uniqueID, device: self)
    }
    
    private func getJMDeviceType(_ deviceType:  AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) -> JMVideoDeviceType {
        
        if position == .front{
            return .FrontCamera
        }
        else{
            switch deviceType {
                case .builtInWideAngleCamera:
                    return.RearCamera
                
//                case .builtInUltraWideCamera:
//                    return.RearCamera_WideAngle
                
                case .builtInTelephotoCamera:
                    return .RearCamera_Telephoto
                
                default:
                    return .UnKnown
            }
        }
    }
}

//MARK: Callback from AVDeviceCapture
extension JMVideoDeviceManager{
    @objc func handleCaptureSessionInterruption(_ notification: Notification) {
        var reasonString: String? = nil
        if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber {
            switch reason.intValue {
            case AVCaptureSession.InterruptionReason.videoDeviceNotAvailableInBackground.rawValue:
                reasonString = "VideoDeviceNotAvailableInBackground"
            case AVCaptureSession.InterruptionReason.audioDeviceInUseByAnotherClient.rawValue:
                reasonString = "AudioDeviceInUseByAnotherClient"
            case AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient.rawValue:
                reasonString = "VideoDeviceInUseByAnotherClient"
            case AVCaptureSession.InterruptionReason.videoDeviceNotAvailableWithMultipleForegroundApps.rawValue:
                reasonString = "VideoDeviceNotAvailableWithMultipleForegroundApps"
            default:
                break
            }
        }
        
        LOG.info("AVVideoDevice- Capture session interrupted: \(reasonString ?? "")")
    }

    @objc func handleCaptureSessionInterruptionEnded(_ notification: Notification) {
        LOG.info("AVVideoDevice- Capture session interruption ended.")
    }

    @objc func handleCaptureSessionRuntimeError(_ notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError {
            LOG.error("AVVideoDevice- error: \(error.description)")
        }
    }
    
    @objc func handleApplicationWentIntoBackground(_ notification: Notification) {
        LOG.info("AVVideoDevice- Background mode.")
        delegateToManager?.handleBackgroundVideoEvent()
    }
    
    @objc func handleApplicationDidBecomeActive(_ notification: Notification) {
        LOG.info("AVVideoDevice- Foreground mode.")
        delegateToManager?.handleForegroundVideoEvent()
    }
}

//NOTE: for complete implementation of 'RTCCameraVideoCapturer', refer - https://webrtc.googlesource.com/src/+/f7071861852be84e142e6fe6d22f08f8421cd2b3/sdk/objc/Framework/Classes/PeerConnection/RTCCameraVideoCapturer.m
