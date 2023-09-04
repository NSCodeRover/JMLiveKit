//
//  JMManager-PriorityAlgorithm.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 01/09/23.
//

import Foundation

enum JMMediaQuality: Int{
    case low = 0
    case medium
    case high
}

enum JMMediaQualityPriority: Int{
    case low = 1
    case medium
    case high
}

//MARK: Layer Algorithm
extension JMManagerViewModel{
    //New approach - consumer expose api to update remote preferredMediaType and a socket will be sent.
    //Layer producer - update the encoding parameter based on hdUser and 15 users check
}

//MARK: Priority Algorithm
extension JMManagerViewModel{
    
    func setPreferredPriority(remoteId: String, consumerId: String, mediaType: JMMediaType){
        if mediaType == .shareScreen{
            LOG.debug("Priority- Screenshare- set to HIGH. cid- \(consumerId)")
            socketEmitSetPreferredPriority(for: [consumerId], priority: JMMediaQualityPriority.high.rawValue)
            self.updatePreferredPriority()
        }
        else{
            LOG.debug("Priority- set to \(userState.remoteScreenShareEnabled ? "LOW" : "MEDIUM"). cid- \(consumerId)")
            socketEmitSetPreferredPriority(for: [consumerId], priority: userState.remoteScreenShareEnabled ? JMMediaQualityPriority.low.rawValue : JMMediaQualityPriority.medium.rawValue)
        }
    }
    
    func updatePreferredPriority(){
        
        if userState.remoteScreenShareEnabled{
            
            var allVideoConsumerFiltered = Array(totalVideoConsumer.values)
            
            //ALL consumer LOW priority, except the presenter video
            if let presenterVideoConsumerId = totalVideoConsumer[userState.remoteScreenShareRemoteId]{
                LOG.debug("Priority- Screenshare- filtered cid- \(presenterVideoConsumerId)")
                allVideoConsumerFiltered.filter { $0 == presenterVideoConsumerId }
            }
            
            LOG.debug("Priority- Screenshare- All video consumers to LOW.")
            socketEmitSetPreferredPriority(for: allVideoConsumerFiltered, priority: JMMediaQualityPriority.low.rawValue)
        }
        else{
            socketEmitSetPreferredPriority(for: Array(totalVideoConsumer.values), priority: JMMediaQualityPriority.medium.rawValue)
        }
    }
}

extension JMManagerViewModel{
    
    func socketEmitSetPreferredPriority(for consumerIds: [String], priority: Int) {
        let consumerObjects = consumerIds.map{ JioSocketProperty.createPreferredPriorityObject(for: $0, priority: priority) }
        self.jioSocket.emit(action: .setConsumersPreferedLayersNPriorities, parameters: JioSocketProperty.getPreferredPriorityProperty(consumerObjects: consumerObjects))
    }
    
    func socketEmitSetPreferredLayer(for consumerId: String, spatialLayer: Int, temporalLayer: Int) {
        self.jioSocket.emit(action: .setConsumerPreferredLayers, parameters: JioSocketProperty.getPreferredLayerProperty(consumerId: consumerId, spatialLayer: spatialLayer, temporalLayer: temporalLayer))
    }
}

/*
Note - Another approach - If we take control over the feed management then can use below logic

func checkAndUpdatePreference(){
    let preferredQuality = getLayerPreference()
    
    if preferredQuality == currentMediaQualityPreference{
        return
    }
    
    currentMediaQualityPreference = preferredQuality
    
    //Update all the consumer
    totalVideoConsumer.forEach({ socketEmitSetPreferredLayer(for: $0.value, spatialLayer: preferredQuality.rawValue, temporalLayer: 2) })
}

func getLayerPreference() -> JMMediaQuality{
    
    let videoCount = totalVideoConsumer.keys.count
    var mediaQuality: JMMediaQuality = .medium
    
    if mediaOptions.isHDEnabled{
        if videoCount <= 15{
            mediaQuality = .high
        }
    }
    else{
        if videoCount <= 2{
            mediaQuality = .high
        }
        else if videoCount <= 4{
            mediaQuality = .medium
        }
        else{
            mediaQuality = .low
        }
    }
    
    return mediaQuality
}
*/
