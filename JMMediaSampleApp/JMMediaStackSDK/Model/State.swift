//
//  State.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 04/09/23.
//

import Foundation

class LocalState{
    
    //Self
    var selfUserName: String = ""
    var selfPeerId: String = ""
    
    //Self States
    var selfMicEnabled: Bool = false
    var selfCameraEnabled: Bool = false
    var selfCameraForceOff: Bool = false
    var isVirtualBackgroundEnabled: Bool = false
    
    //TODO: Producer
//    var producerVideo: Producer?
//    var producerAudio: Producer?
//    var producerScreenShare: Producer?
        
    //Self ScreenShare
    private(set) var selfScreenShareEnabled: Bool = false
    private(set) var selfScreenShareProducerId: String = ""
    
    func enableSelfScreenShare(producerId: String){
        self.selfScreenShareEnabled = true
        self.selfScreenShareProducerId = producerId
    }
    func disableSelfScreenShare(){
        self.selfScreenShareEnabled = false
        self.selfScreenShareProducerId = ""
    }
    
    //Remote ScreenShare
    private(set) var remoteScreenShareEnabled: Bool = false
    private(set) var remoteScreenShareRemoteId: String = ""
    private(set) var remoteScreenShareConsumerId: String = "" //Not in use
    
    func enableRemoteScreenShare(for remoteId: String, consumerId: String){
        self.remoteScreenShareEnabled = true
        self.remoteScreenShareRemoteId = remoteId
        self.remoteScreenShareConsumerId = consumerId
    }
    
    func disableRemoteScreenShare(){
        self.remoteScreenShareEnabled = false
        self.remoteScreenShareRemoteId = ""
        self.remoteScreenShareConsumerId = ""
    }
}
