//
//  MeetingRoomViewController.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 07/02/23.
//

import UIKit
import WebRTC
import ReplayKit
import JMMediaStackSDK
import MMWormhole

public var appGroupIdentifier: String {
    get {
        let appId = Bundle.main.bundleIdentifier!
        return "group.\(appId)"
    }
}
let screenShareStateExtensionListener = MMWormhole(applicationGroupIdentifier:appGroupIdentifier, optionalDirectory: "wormhole")

class MeetingRoomViewController: UIViewController {
    @IBOutlet var localVideoView: UIView!
    @IBOutlet weak var remoteVideoBGView: UIView!
    @IBOutlet weak var meetingRoomCollectionView: UICollectionView!
    
    @IBOutlet weak var btn_Mic: UIButton!
    @IBOutlet weak var btn_Video: UIButton!
    @IBOutlet weak var btn_audioDevice: UIButton!
    @IBOutlet weak var btn_videoDevice: UIButton!
    
    @IBOutlet weak var lblDisplayName: UILabel!
    @IBOutlet weak var viewBigScreenshare: UIView!
    @IBOutlet weak var lblPlist: UILabel!
    
    @IBOutlet weak var constraintHeightLocalview: NSLayoutConstraint!
    
    var viewModel: MeetingRoomViewModel!
    var screenShareState:JMScreenShareState = .ScreenShareStateStopping
    
    @IBOutlet weak var constraintWidthLocalView: NSLayoutConstraint!
    
    let pickerbtn:RPSystemBroadcastPickerView = {
            let picker = RPSystemBroadcastPickerView.init(frame: CGRect.init(x: 0, y: 0, width: 155, height: 155))
            picker.preferredExtension = "\(appIdentifier).MediaStackScreenShare"
            return picker
        }()
    //var screenShareState:JMScreenShareState = .ScreenShareStateStopping
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureCollectionView()
        addViewModelListener()
        self.viewModel.handleEvent(event: .startMeeting)
        localVideoView.makeDraggable()
        self.getListenScreenShareEvent()
    }
    
    @IBAction func endCallAction(_ sender: Any) {
        showActionSheet()
    }
    
    @IBAction func audioAction(_ sender: Any) {
        self.viewModel.handleEvent(event: .audio)
    }
    
    @IBAction func videoAction(_ sender: Any) {
        self.viewModel.handleEvent(event: .video)
    }
    
    @IBAction func audioDeviceAction(_ sender: Any) {
        self.viewModel.handleEvent(event: .audioDevice)
    }
    
    @IBAction func videoDeviceAction(_ sender: Any) {
        self.viewModel.handleEvent(event: .videoDevice)
    }
}

// MARK: - Public Methods
extension MeetingRoomViewController {
    func getViewModel() -> MeetingRoomViewModel {
        return viewModel
    }
}

// MARK: - Private Methods
extension MeetingRoomViewController {
    
    private func configureCollectionView() {
        self.navigationController?.navigationBar.isHidden = true
        self.meetingRoomCollectionView.register(MeetingRoomAudioCell.nib, forCellWithReuseIdentifier: MeetingRoomAudioCell.identifier)
        self.meetingRoomCollectionView.register(MeetingRoomVideoCell.nib, forCellWithReuseIdentifier: MeetingRoomVideoCell.identifier)
        self.meetingRoomCollectionView.register(MeetingRoomShareVideoCell.nib, forCellWithReuseIdentifier: MeetingRoomShareVideoCell.identifier)
        self.meetingRoomCollectionView.dataSource = self
        self.meetingRoomCollectionView.delegate = self
    }
    
    private func addViewModelListener() {
        self.viewModel.reloadData = {
            DispatchQueue.main.async {
                self.meetingRoomCollectionView.reloadData()
            }
        }
        self.viewModel.getLocalRenderView = {
            return self.localVideoView
        }
        self.viewModel.getLocalScreenShareView = {
            return self.viewBigScreenshare
        }
        self.viewModel.popScreen = {
            DispatchQueue.main.async {
                self.navigationController?.navigationBar.isHidden = false
                self.navigationController?.popViewController(animated: true)
            }
        }
        
        self.viewModel.handleAudioState = { state in
            DispatchQueue.main.async {
                self.btn_Mic.backgroundColor = state ? .systemGreen : .red
            }
        }
        
        self.viewModel.handleVideoState = { state in
            DispatchQueue.main.async {
                self.btn_Video.backgroundColor = state ? .systemGreen : .red
                self.viewModel.getLocalRenderView = {
                    return self.localVideoView
                }
            }
        }
       
        self.viewModel.selectedDevice = { device in
            self.showToast("Device in use: \(self.getDeviceName(device)).")
        }
        
        self.viewModel.devices = { devices in
            let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            for device in devices{
                let action = UIAlertAction(title: self.getDeviceName(device), style: .default) { (action) in
                    self.viewModel.handleEvent(event: .setDevice(device: device))
                }
                optionMenu.addAction(action)
            }
            
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
            optionMenu.addAction(cancel)
                
            self.present(optionMenu, animated: true, completion: nil)
        }
        
        self.viewModel.videoDevices = { devices in
            let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            for device in devices{
                let action = UIAlertAction(title: device.deviceName, style: .default) { (action) in
                    self.viewModel.handleEvent(event: .setVideoDevice(device: device))
                }
                optionMenu.addAction(action)
            }
            
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
            optionMenu.addAction(cancel)
                
            self.present(optionMenu, animated: true, completion: nil)
        }
        
        self.viewModel.handleConnectionState = { state in
            DispatchQueue.main.async {
                self.lblPlist.text = state.rawValue
            }
            
            if state == .disconnected{
                let alertController = UIAlertController(title: "Disconnected!! Wanna retry?", message: "", preferredStyle: .alert)
                        
                let okAction = UIAlertAction(title: "Retry", style: .default) { _ in
                    self.viewModel.handleEvent(event: .retryJoin)
                }
                let cancelAction = UIAlertAction(title: "No", style: .cancel) { _ in
                    DispatchQueue.main.async {
                        self.navigationController?.navigationBar.isHidden = false
                        self.navigationController?.popViewController(animated: true)
                    }
                }
                
                alertController.addAction(cancelAction)
                alertController.addAction(okAction)
                
                self.present(alertController, animated: true, completion: nil)
            }
        }
        
        self.viewModel.onErrorShowToast = { mediaError in
            self.showToast("JMMediaError: \(mediaError.description)")
        }
        
        self.viewModel.onShowToast = {
            self.showToast("Are you trying to speak? Unmute yourself if you are speaking.")
        }
        
        lblDisplayName.text = viewModel.displayName
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout
extension MeetingRoomViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize.init(width: collectionView.frame.width/2, height: collectionView.frame.width/2)
    }
    
    internal func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.viewModel.getPeers().count
    }
    
    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MeetingRoomVideoCell.identifier, for: indexPath) as? MeetingRoomVideoCell {
            let peer = self.viewModel.getPeers()[indexPath.row]
            cell.setPeer(peer: peer)
            viewModel.setRemoteView(peer.userId, view: cell.remoteVideoBGView)
            return cell
        }
        return UICollectionViewCell()
    }
}

extension MeetingRoomViewController{
    func getDeviceName(_ device: JMAudioDevice) -> String{
        if device.deviceType == .Bluetooth{
            return device.deviceName
        }
        else{
            return device.deviceType.rawValue
        }
    }
    
    @objc func transparentButtonTapped() {
        for subview in pickerbtn.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
            }
        }
    }
    
    func getListenScreenShareEvent(){
       screenShareStateExtensionListener.listenForMessage(withIdentifier: JMScreenShareManager.ScreenShareState, listener: { (messageObject) -> Void in
            if let State = messageObject as? String{
                self.screenShareState = JMScreenShareState(rawValue: State) ?? .ScreenShareStateStopping
                if self.screenShareState == .ScreenShareStateStopping {
                    self.viewModel.handleEvent(event: .setStopScreenShare(error: "user-action"))
                }
                //kept for future reference
                //self.viewModel.setScreenShareState(state:self.screenShareState)
            }
        })
    }
    
    func showActionSheet() {
        let actionSheet = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)
        
        var screenshare = false
        switch screenShareState {
        case .ScreenShareStateStarting:
            // Handle starting screen sharing
            screenshare = true
        default:
            screenshare = false
        }
        
        let startScreenShare = UIAlertAction(title:screenshare ? "Stop ScreenShare" : "Start ScreenShare" , style: .default) { _ in
            // Handle starting screen sharing
            if screenshare{
                self.viewModel.handleEvent(event: .setStopScreenShare(error: "user-action"))
            }else{
                self.viewModel.handleEvent(event: .setStartScreenShare)
                self.transparentButtonTapped()
            }
        }
        
        let audioDevice = UIAlertAction(title: "Audio Devices (Mic)", style: .default) { _ in
            self.viewModel.handleEvent(event: .audioDevice)
        }
        
        let audioOnlyMode = UIAlertAction(title: viewModel.isAudioOnly ? "Disable Audio Only" : "Enable Audio Only", style: .default) { _ in
            self.viewModel.handleEvent(event: .audioOnly(!self.viewModel.isAudioOnly))
        }
        
        let videoDevice = UIAlertAction(title: "Video Devices (Camera)", style: .default) { _ in
            self.viewModel.handleEvent(event: .videoDevice)
        }
        
        let virtualBG = UIAlertAction(title: self.viewModel.isVirtualBackgroundEnabled ? "Disable Virtual Background" : "Enable Virtual Background", style: .default) { _ in
            self.viewModel.isVirtualBackgroundEnabled = !self.viewModel.isVirtualBackgroundEnabled
            self.viewModel.handleEvent(event: .virtualBackground(self.viewModel.isVirtualBackgroundEnabled))
        }
        
        let endCall = UIAlertAction(title: "End Call", style: .destructive) { _ in
            self.viewModel.handleEvent(event: .endCall)
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // Handle Cancel
            print("Action canceled")
        }
    
        actionSheet.addAction(startScreenShare)
        actionSheet.addAction(audioOnlyMode)
        actionSheet.addAction(audioDevice)
        actionSheet.addAction(videoDevice)
        actionSheet.addAction(virtualBG)
        actionSheet.addAction(endCall)
        actionSheet.addAction(cancel)
        
        // For iPad, to avoid crashes when presenting action sheets
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(actionSheet, animated: true, completion: nil)
    }
}
