//
//  JMManager-PriorityAlgorithm.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 01/09/23.
//

import Foundation

enum JMMediaQualityPriority: Int{
    case low = 1
    case medium
    case high
}

//MARK: Layer Algorithm
extension JMManagerViewModel{
    
    //Only Client will call.
    func setPreferredFeedQuality(remoteId: String, preferredQuality: JMMediaQuality){
        if var updatedPeer = self.peersMap[remoteId] {
            
            let evaluatePreferredFeed = evaluatePreferredAndRecommend(preferredQuality)
            if updatedPeer.preferredFeed == evaluatePreferredFeed{
                return
            }
            
            if let videoConsumerId = updatedPeer.consumerVideo?.id{
                socketEmitSetPreferredLayer(for: videoConsumerId, spatialLayer: evaluatePreferredFeed.rawValue, temporalLayer: 2)
            }
            
            LOG.debug("Quality- \(updatedPeer.displayName) changed to \(evaluatePreferredFeed). \(preferredQuality != evaluatePreferredFeed ? "(Override)" : "")")
            
            updatedPeer.preferredFeed = preferredQuality
            self.peersMap[remoteId] = updatedPeer
        }
    }
    
    fileprivate func evaluatePreferredAndRecommend(_ preferredQuality: JMMediaQuality) -> JMMediaQuality{
        
        if userState.remoteScreenShareEnabled{
            return .low
        }
        
        var evaluatePreferredFeed = preferredQuality
        if mediaOptions.isHDEnabled{
            if preferredQuality == .high{
                evaluatePreferredFeed = Array(totalVideoConsumer.values).count >= 15 ? JMMediaQuality.medium : JMMediaQuality.high
            }
        }
        else{
            //NON HD users
            evaluatePreferredFeed = preferredQuality == .high ? JMMediaQuality.medium : preferredQuality
        }
        
        return evaluatePreferredFeed
    }
    
    //Primarly for HD users, This algo will be execute on every socket event NEW and END Consumer.
    func updatePreferredQuality(){
        
        if !userState.remoteScreenShareEnabled && !mediaOptions.isHDEnabled {
            //Ignoring NON HD users because Medium is the default.
            return
        }

        let recommendedQuality = evaluatePreferredAndRecommend(currentMediaQualityPreference)
        if currentMediaQualityPreference == recommendedQuality{
            return
        }
        currentMediaQualityPreference = recommendedQuality
        
        updateProducerLayers()
        updateAllPreferredQuality(recommendedQuality)
    }
    
    fileprivate func updateAllPreferredQuality(_ recommendedQuality: JMMediaQuality){
        LOG.debug("Quality- Recommended is \(recommendedQuality)")
        
        for (remoteId,videoConsumerId) in totalVideoConsumer{
            if var updatedPeer = self.peersMap[remoteId] {
                
                if updatedPeer.preferredFeed == recommendedQuality{
                    return
                }
                
                updatedPeer.preferredFeed = recommendedQuality
                self.peersMap[remoteId] = updatedPeer
                socketEmitSetPreferredLayer(for: videoConsumerId, spatialLayer: recommendedQuality.rawValue, temporalLayer: 2)
            }
        }
    }
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
            LOG.debug("Priority- Video- set to \(userState.remoteScreenShareEnabled ? "LOW" : "MEDIUM"). cid- \(consumerId)")
            socketEmitSetPreferredPriority(for: [consumerId], priority: userState.remoteScreenShareEnabled ? JMMediaQualityPriority.low.rawValue : JMMediaQualityPriority.medium.rawValue)
            self.updatePreferredQuality()
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
    
    fileprivate func socketEmitSetPreferredLayer(for consumerId: String, spatialLayer: Int, temporalLayer: Int) {
        self.jioSocket.emit(action: .setConsumerPreferredLayers, parameters: JioSocketProperty.getPreferredLayerProperty(consumerId: consumerId, spatialLayer: spatialLayer, temporalLayer: temporalLayer))
    }
}

//MARK: PRODUCER
extension JMManagerViewModel{
        
    func updateProducerLayers(){
        
        if !mediaOptions.isHDEnabled{
            return
        }
        
        if let videoProducer = videoProducer{
            qJMMediaBGQueue.async {
                self.handleMediaSoupErrors("Video- Reconnect-"){
                    
                    let recommendedLayer = self.getSpatialValues()
                    try videoProducer.setMaxSpatialLayer(recommendedLayer)
                    LOG.info("Video- Reconnect- producer layers set to \(recommendedLayer).")
                }
            }
        }
    }
    
    //Spatial layer has some issue and it starts with 1 when setting 'setMaxSpatialLayer'
    fileprivate func getSpatialValues() -> Int{
        
        if connectionNetworkType != .WIFI{
            return 2
        }
        
        switch currentMediaQualityPreference {
        case .high:
            return 3
        case .medium:
            return 2
        case .low:
            return 1
        }
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
