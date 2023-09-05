//
//  State.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 04/09/23.
//

import Foundation

class LocalState{
    
    //MARK: Self
    var selfUserName: String = ""
    var selfPeerId: String = ""
    
    //MARK: Self States
    var selfMicEnabled: Bool = false
    var selfCameraEnabled: Bool = false
    
    //TODO: ADD self views, producer here.
    
    //MARK: Self ScreenShare
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
    
    //MARK: Remote ScreenShare
    private(set) var remoteScreenShareEnabled: Bool = false
    private(set) var remoteScreenShareRemoteId: String = ""
    private(set) var remoteScreenShareConsumerId: String = ""
    
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
