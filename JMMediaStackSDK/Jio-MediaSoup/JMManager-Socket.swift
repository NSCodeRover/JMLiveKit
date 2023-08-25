//
//  VM-JMManager-Socket.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 03/07/23.
//


import Foundation

import SocketIO
import SwiftyJSON
import Mediasoup

extension JMManagerViewModel {
    
    internal func connect(socketUrl: String, roomId: String, jwtToken: String) {
        LOG.debug("socket- \(#function) \(socketUrl)|\(roomId)|\(jwtToken)")
        
        let ip = socketUrl.replacingOccurrences(of: "wss://", with: "")
        let url = socketUrl.replacingOccurrences(of: "wss", with: "https")
        
        let events: [SocketEvent] = [
            .connect,
            .disconnect,
            .socketConnected,
            
            .reconnect,
            .reconnectAttempt,
            
            .peerConnected,
            .newPeer,
            .peerClosed,
            
            .audioLevel,
            
            .newProducer,
            .producerEnd,
            .pausedProducer,
            .resumedProducer,
            
            .broadcastMessage,
            .broadcastMessageToPeer
            
            //NOT HANDLED
//            .layerschange,
//            .botsJoined,
//            .botsLeft,
//            .score,
//            .userRoleUpdated
        ]
        initFactoryAndStream()
        jioSocket.connect(socketUrl: url, roomId: roomId, jwtToken: jwtToken, ip: ip, delegate: self, socketEvents: events)
    }
}

extension JMManagerViewModel{
    func emitOnConnectWebRtc(transportId:String, dtlsParameters: String!, handler: ((([String:Any]) -> Void)?)) {
        let parameters:[String:Any] = [SocketDataKey.transportId.rawValue: transportId, SocketDataKey.dtlsParameters.rawValue: dtlsParameters.toDic()]
        
        if self.jioSocket.getSocket().status != .connected {
            LOG.warning("Transport- socket not connected")
            return
        }
        
        self.jioSocket.getSocket().emitWithAck(SocketEmitAction.connectWebRtcTransport.rawValue, parameters).timingOut(after: 10) { data in
            if let json = self.getJson(data: data) {
                LOG.debug("Transport- Emit Webrtc json == \(json)")
                handler?(json)
            }
            else{
                handler?([:])
            }
        }
    }
    
    func emitOnProduce(transportId:String, kind:String, rtpParameters:String, appData: String, handler: ((String) -> ())?) {
        var parameters:[String:Any] = [
            SocketDataKey.transportId.rawValue: transportId, SocketDataKey.kind.rawValue: kind, SocketDataKey.rtpParameters.rawValue: rtpParameters.toDic()
        ]
        
        if appData == JioMediaAppData.screenShareAppData{
            parameters[SocketDataKey.appData.rawValue] = ["share":true]
            self.jioSocket.emit(action: .produce, parameters: parameters)
            handler?("ID not found")
        }else {
            self.jioSocket.getSocket().emitWithAck(SocketEmitAction.produce.rawValue, parameters).timingOut(after: 10) { data in
                if let json = self.getJson(data: data),let dataObj = json["data"] as? [String:Any], let id = dataObj["id"] as? String {
                    handler?(id)
                }
                else{
                    handler?("ID not found")
                }
            }
        }
            
       
    }
}

// MARK: - Socket Callbacks
extension JMManagerViewModel: JioSocketDelegate {
    
    func didConnectionStateChange(connectionState: JMSocketConnectionState) {
        self.connectionState = connectionState
        LOG.info("Reconnect- state: \(connectionState)")
    }
    
    func didEmit(event: SocketEmitAction, data: [Any]) {

        if event == .peerLeave{
            handleSocketEmitPeerLeave()
        }

        if let json = self.getJson(data: data) {
            
            switch event {
                
            case .join:
                handleSocketEmitJoin(json)
                
            case .consume:
                handleSocketEmitNewConsumer(json)
                
            case .getTransportStats:
                handleSocketEmitStats(json)
                
            case .produce:
                handleSocketEmitScreenShareProduce(json)
                
            case .restartIce:
                handleSocketEmitRestartICE(json)
                
            default: break
            }
        }
    }
    
    func didReceive(event: SocketEvent, data: [Any], ack: SocketAckEmitter?) {

        if event == .connect{
            handleSocketReconnected()
            return
        }
        else if event == .socketReconnected{
            handleSocketPostReconnectedEvents(data)
            return
        }
        
        guard let json = self.getJson(data: data) else{
            LOG.error("Socket- No json found for event: \(event.rawValue) | \(data.description)")
            return
        }
        
        switch event {
            
        case .socketConnected:
            handleSocketConnected(json)
            
        case .peerConnected: // When Local User call connected
            handleSocketSelfPeerConnected(json)
            
        case .newPeer: // When Local User call connected
            handleSocketNewPeerJoined(json)
         
        case .peerClosed: // When someone from Remote User leave/End Call.
            handleSocketPeerLeft(json)
            
        case .newProducer: // When Remote User Turn On Audio/Video First Time
            handleSocketProducer(json, event: event)
            
        case .pausedProducer: // When Remote User Turn Off Audio multiple times
            handleSocketProducer(json, event: event)
            
        case .resumedProducer: // When Remote User Turn On Audio multiple times
            handleSocketProducer(json, event: event)
            
        case .producerEnd: // When Remote User Turn Off Video
            handleSocketProducer(json, event: event)
            
        case .audioLevel: //Audio level for each user
            handleSocketAudioLevelForActiveSpeakers(json)
            
        case .broadcastMessage: //Group message
            handleSocketBroadcastMessage(json)
            
        case .broadcastMessageToPeer: //1-1 messaging
            handleSocketBroadcastMessageToPeer(json)
            
        default: break
        }
    }    
}

//MARK: Socket emit handler
extension JMManagerViewModel{
    private func handleSocketEmitJoin(_ json: [String : Any]) {
        qJMMediaBGQueue.async {
            self.createSendAndReceiveTransport()
            self.addPeerIfalreadyJoinMeetingRoom(json: json).forEach {
                self.delegateBackToManager?.sendClientUserJoined(user: self.formatToJMUserInfo(from: $0))
                
                if let audioConsumer = $0.producers.first(where: { $0.mediaType == "audio" }){
                    self.socketEmitGetProducerInfo(for: audioConsumer.producerId)
                }
            }
        }
    }
    
    private func handleSocketEmitNewConsumer(_ json: [String : Any]) {
        qJMMediaBGQueue.async {
            self.onNewConsumer(json: json)
        }
    }
    
    private func handleSocketEmitPeerLeave() {
        qJMMediaBGQueue.async {
            self.dispose()
        }
    }
    
    private func handleSocketEmitStats(_ json: [String : Any]) {
        qJMMediaBGQueue.async {
            self.setTransportState(json)
        }
    }
}

//MARK: Socket receive handler
extension JMManagerViewModel{
    private func handleSocketEmitRestartICE(_ json: [String : Any]) {
        
        qJMMediaBGQueue.async {
            if let data = json["data"] as? [String: Any] {
                self.onRestartIce(restartData: data)
            }
        }
    }
    
   private func handleSocketEmitScreenShareProduce(_ json: [String : Any]) {
       if let share = json["share"] as? Bool, share {
           if let data = json["data"] as? [String: Any] {
               if let id = data["id"] as? String {
                   self.screenShareProducerID = id
               }
           }
       }
   }
    
    private func handleSocketProducer(_ json: [String:Any], event: SocketEvent){
        
        qJMMediaBGQueue.async {
            if let remoteId = json[SocketDataKey.peerId.rawValue] as? String,
               let producerId = json[SocketDataKey.producerId.rawValue] as? String,
               let mediaType = json[SocketDataKey.mediaType.rawValue] as? String{
                
                let isScreenShareEnabled = json["share"] as? Bool ?? false
                let jmMediaType: JMMediaType = isScreenShareEnabled ? .shareScreen : mediaType.lowercased() == "video" ? .video : .audio
                
                if event == .newProducer{
                    self.updateVideoProducerId(producerId, remoteId: remoteId, mediaType: mediaType, isScreenShareEnabled: isScreenShareEnabled)
                }
                else if event == .pausedProducer || event == .producerEnd{
                    self.clearVideoProducer(for: remoteId, mediaType: jmMediaType)
                }
                
                self.onProducerUpdate(producerId, remoteId: remoteId, mediaType: mediaType, event: event, isScreenShareEnabled: isScreenShareEnabled)
            }
        }
    }
    
    private func handleSocketSelfPeerConnected(_ json: [String : Any]) {
        if let peerId = json[SocketDataKey.peerId.rawValue] as? String {
            self.selfPeerId = peerId
            self.jioSocket.updateConfig(peerId)
            self.delegateBackToManager?.sendClientJoinSocketSuccess(selfId: peerId)
        }
    }
    
    private func handleSocketNewPeerJoined(_ json: [String : Any]) {
        if let peer = parse(json: json, model: Peer.self) {
            let user = formatToJMUserInfo(from: peer)
            self.delegateBackToManager?.sendClientUserJoined(user: user)
            self.peersMap[peer.peerId] = peer
        }
    }
    
    private func handleSocketPeerLeft(_ json: [String : Any]) {
        if let peerId = json[SocketDataKey.peerId.rawValue] as? String, let reason = json["reason"] as? String {
            self.delegateBackToManager?.sendClientUserLeft(id: peerId, reason: reason)
            self.peersMap.removeValue(forKey: peerId)
        }
    }
    
    private func handleSocketAudioLevelForActiveSpeakers(_ speakerObject: [String: Any]) {
        qJMMediaBGQueue.async {
            var listActiveParticipant: [JMActiveParticipant] = []
            if let speakerList = speakerObject["audioProducers"] as? [[String: Any]] {
                for audioObject in speakerList {
                    guard let peerId = audioObject["peerId"] as? String,
                          let volume = audioObject["volume"] as? Int else {
                        continue
                    }
                    listActiveParticipant.append(JMActiveParticipant(peerId: peerId, volume: Int(volume)))
                }
                self.delegateBackToManager?.sendClientTopSpeakers(listActiveParticipant: listActiveParticipant)
            }
        }
    }
    
    private func handleSocketBroadcastMessage(_ json: [String : Any]) {
        if let msg = json as? [String: Any], let msgData = msg["msgData"] as? [String: Any] {
            self.delegateBackToManager?.sendClientBroadcastMessage(msg: msgData)
        }
    }
    
    private func handleSocketBroadcastMessageToPeer(_ json: [String : Any]) {
        if let msg = json as? [String: Any], let msgData = msg["msgData"] as? [String: Any] {
            self.delegateBackToManager?.sendClientBroadcastMessageToPeer(msg: json)
        }
    }
    
    private func handleSocketConnected(_ json: [String : Any]) {
        self.socketConnectedData = json
        
        if device == nil{
            LOG.debug("Reconnect- Connected (First time)")
            initMediaSoupEngine(with: json)
        }
        else{
            LOG.debug("Reconnect- reconnected (JOIN BACK)")
            validateTransportAndRestart()
        }
    }
    
    private func handleSocketReconnected() {
        if device == nil{
            return
        }
        
        LOG.debug("Reconnect- reconnected (JOIN BACK)")
        validateTransportAndRestart()
    }
   
    private func handleSocketPostReconnectedEvents(_ data: [Any]) {
        LOG.debug("Reconnect- socketReconnected events")
        if let jsonArr = self.getJsonArr(data: data){
            for eventDict in jsonArr {
               if let eventName = eventDict["eventName"] as? String,
                  let eventType = SocketEvent(rawValue: eventName) {
                   let json = [eventDict]
                   LOG.debug("Reconnect- reconnected - handling missing event \(eventName)")
                   didReceive(event: eventType, data: json, ack: nil)
               }
            }
        }
        else{
            LOG.error("Reconnect- socketReconnected event json mismatch \(data.description)")
        }
    }
}

//MARK: Join and leave socket
extension JMManagerViewModel{
    
    func selfPeerLeave() {
        self.jioSocket.emit(action: .peerLeave, parameters: JioSocketProperty.getClosePeerLeaveProperty(peerId: self.selfPeerId))
    }

    func checkIfAnyPeerAlreadyPresentInMeetingRoom(json: [String: Any]) -> [Peer] {
        if let response = parse(json: json, model: JoinResponse.self), let data = response.data {
            return data.peers
        }
        return []
    }
    
    func addPeerIfalreadyJoinMeetingRoom(json: [String: Any]) -> [Peer] {
        let peerList = self.checkIfAnyPeerAlreadyPresentInMeetingRoom(json: json)
        self.peersMap = Dictionary(uniqueKeysWithValues: peerList.map { ($0.peerId, $0) })
        return Array(peersMap.values)
    }

    func socketEmitSetTransportStats() {
        self.jioSocket.emit(action: .getTransportStats , parameters: transportStatsParam)
    }
}

//MARK: Client remote media state update
extension JMManagerViewModel {
    func setRemoteUserMediaAction(isEnabled:Bool,id:String,type:JMMediaType){
        if isEnabled {
            self.delegateBackToManager?.sendClientUserPublished(id: id, type: type)
        }
        else{
            self.delegateBackToManager?.sendClientUserUnPublished(id: id, type: type)
        }
    }
}

//MARK: Consume
extension JMManagerViewModel{
    func socketEmitGetProducerInfo(for producerId: String) {
        self.jioSocket.emit(action: .consume, parameters: JioSocketProperty.getConsumeProperty(producerId: producerId))
    }
    
    func socketEmitResumeConsumer(for consumerId: String) {
        self.jioSocket.emit(action: .resumeConsumer, parameters: JioSocketProperty.getResumeConsumerProperty(consumerId: consumerId)){ _ in }
    }
    
    //Remote user feeds
    func onNewConsumer(json: [String: Any]) {

        if let status = json[SocketDataKey.status.rawValue] as? String,
           let data = json[SocketDataKey.data.rawValue] as? [String: Any],
           status == SocketDataKey.ok.rawValue,
           let consumerInfo = self.getDataOf(key: SocketDataKey.consumerInfo.rawValue, dictionary: data)
        {
            let appData = consumerInfo.dictionary(SocketDataKey.appData.rawValue)
            let kind = consumerInfo.strValue(SocketDataKey.kind.rawValue)
            let remoteId = consumerInfo.strValue(SocketDataKey.producerPeerId.rawValue)
            let consumerId = consumerInfo.strValue(SocketDataKey.consumerId.rawValue)
            let producerId = consumerInfo.strValue(SocketDataKey.producerId.rawValue)
            let rtpParameters = JSON(consumerInfo.dictionary(SocketDataKey.rtpParameters.rawValue)).description
            
            let mediaKind = kind == JMMediaType.audio.rawValue ? MediaKind.audio : MediaKind.video
            if let consumer = try? self.recvTransport?.consume(consumerId: consumerId, producerId: producerId, kind: mediaKind, rtpParameters: rtpParameters, appData: JSON(appData).description) {
                
                let isScreenShareEnabled = appData["share"] as? Bool ?? false
                let jmMediaType: JMMediaType = isScreenShareEnabled ? .shareScreen : mediaKind == .video ? .video : .audio
                
                self.updatePeerMediaConsumer(consumer, remoteId: remoteId, mediaType: jmMediaType)
                self.updatePeerMediaState(true, remoteId: remoteId, mediaType: jmMediaType)
                self.socketEmitResumeConsumer(for: consumerId)
                consumer.resume()
                
                //Update renderer track
                if jmMediaType == .shareScreen{
                    self.updateRemoteScreenShareRenderViewTrack(for: remoteId)
                }
                else if jmMediaType == .video{
                    self.updateRemoteRenderViewTrack(for: remoteId)
                }
                
                LOG.debug("Subscribe- \(jmMediaType) consumer added")
            }else{
                LOG.debug("Subscribe-  consumer failed")
            }
        }
    }
}

//MARK: Producer updation : Socket
extension JMManagerViewModel{
    
    //Producer
    func socketCloseProducer(producerId: String) {
        self.jioSocket.emit(action: .closeProducer, parameters: JioSocketProperty.getCloseProducerProperty(producerId: producerId))
    }
    
    func socketEmitPauseProducer(producerId: String) {
        self.jioSocket.emit(action: .pauseProducer, parameters: JioSocketProperty.getPauseAndResumerProducerProperty(producerId: producerId)){ _ in }
    }
    
    func socketEmitResumeProducer(producerId: String) {
        self.jioSocket.emit(action: .resumeProducer, parameters: JioSocketProperty.getPauseAndResumerProducerProperty(producerId: producerId)){ _ in }
    }
    
    func onProducerUpdate(_ producerId: String, remoteId: String, mediaType: String, event: SocketEvent, isScreenShareEnabled: Bool = false) {
        
        let jmMediaType: JMMediaType = isScreenShareEnabled ? .shareScreen : mediaType == "video" ? .video : .audio
        if isVideoFeedDisable(jmMediaType){
            //IGNORE updating video for AudioOnly
            return
        }
        
        let mediaStateEnabled = (event == .resumedProducer || event == .newProducer) ? true : false
        if jmMediaType == .video{
            if subscriptionVideoList.contains(remoteId){
                LOG.debug("Subscribe- already subscribed")
                feedHandler(mediaStateEnabled, remoteId: remoteId, mediaType: jmMediaType)
            }
        }
        else{
            feedHandler(mediaStateEnabled, remoteId: remoteId, mediaType: jmMediaType)
        }
    }
}

//MARK: Media state updation
extension JMManagerViewModel{
    
    func updatePeerMediaConsumer(_ consumer: Consumer?, remoteId: String, mediaType: JMMediaType){
        if var updatedPeer = self.peersMap[remoteId] {
            if mediaType == .audio{
                updatedPeer.consumerAudio = consumer
            }
            else if mediaType == .video{
                updatedPeer.consumerVideo = consumer
            }
            else if mediaType == .shareScreen{
                updatedPeer.consumerScreenShare = consumer
            }
            
            self.peersMap[remoteId] = updatedPeer
        }
    }
    
    func updatePeerMediaState(_ isEnabled: Bool, remoteId: String, mediaType: JMMediaType) {
        if var updatedPeer = self.peersMap[remoteId] {
            if mediaType == .audio{
                updatedPeer.isAudioEnabled = isEnabled
            }
            else if mediaType == .video{
                updatedPeer.isVideoEnabled = isEnabled
            }
            else if mediaType == .shareScreen{
                updatedPeer.isScreenShareEnabled = isEnabled
            }
             
            self.peersMap[remoteId] = updatedPeer
            self.setRemoteUserMediaAction(isEnabled: isEnabled, id: remoteId, type: mediaType)
        }
    }
    
    func clearVideoProducer(for remoteId: String, mediaType: JMMediaType) {
        guard var updatedPeer = self.peersMap[remoteId] else {
            return
        }
        
        LOG.debug("Subscribe- consumer updated to nil \(updatedPeer.displayName) mediatype \(mediaType)")
        switch mediaType {
        case .video:
            updatedPeer.consumerVideo = nil
        case .shareScreen:
            LOG.debug("Subscribe- consumer updated to nil \(updatedPeer.displayName) mediatype \(mediaType)")
            updatedPeer.consumerScreenShare = nil
            removeRemoteShareViews(updatedPeer.remoteScreenshareView)
            updatedPeer.remoteScreenshareView = nil
            subscriptionScreenShareVideo = ""
        case .audio:
            updatedPeer.consumerAudio = nil
        }
        
        peersMap[remoteId] = updatedPeer
    }
    
    func updateVideoProducerId(_ producerId: String, remoteId: String, mediaType: String, isScreenShareEnabled: Bool){
        if var updatedPeer = self.peersMap[remoteId] {
            if let objectPresentAtIndex = updatedPeer.producers.firstIndex(where: { isScreenShareEnabled ? ($0.mediaType == "video" && $0.share == true) : ($0.mediaType == mediaType) })
            {
                LOG.debug("Subscribe- pid updated \(updatedPeer.displayName)")
                var updatedProducer = updatedPeer.producers[objectPresentAtIndex]
                updatedProducer.producerId = producerId
                updatedPeer.producers[objectPresentAtIndex] = updatedProducer
            }
            else{
                LOG.debug("Subscribe- new pid updated \(updatedPeer.displayName)")
                let producer = PeerProducer(mediaType: mediaType, producerId: producerId, share: isScreenShareEnabled, paused: false)
                updatedPeer.producers.append(producer)
            }
            peersMap[remoteId] = updatedPeer
        }
    }
}

//MARK: Subscription logic
extension JMManagerViewModel{
    
    //Only client action will call this function
    func subscribeFeed(_ isSubscribe: Bool, remoteId: String, mediaType: JMMediaType){
        LOG.debug("Subscribe- \(isSubscribe)|\(remoteId)|\(mediaType)")
        
        subscriptionHandler(isSubscribe, remoteId: remoteId, mediaType: mediaType)
        
        if !isVideoFeedDisable(mediaType){
            feedHandler(isSubscribe, remoteId: remoteId, mediaType: mediaType)
        }
    }
    
    func feedHandler(_ isSubscribe: Bool, remoteId: String, mediaType: JMMediaType){
        guard let peer = peersMap[remoteId], let producerId = peer.getProducerId(for: mediaType) else{ return }
        
        let consumer = peer.getConsumer(for: mediaType)
        if isSubscribe {
            if let consumer = consumer, consumer.producerId == producerId{
                LOG.debug("Subscribe- \(mediaType) \(remoteId) \(peer.displayName) consumer resumed")
                consumer.resume()
                updatePeerMediaState(true, remoteId: remoteId, mediaType: mediaType)
                socketEmitResumeProducer(producerId: producerId)
            }
            else{
                consumer?.close()
                LOG.debug("Subscribe- \(mediaType) \(remoteId) \(peer.displayName) consumer fetch")
                socketEmitGetProducerInfo(for: producerId)
            }
        }
        else{
            LOG.debug("Subscribe- \(mediaType) \(remoteId) \(peer.displayName) consumer paused")
            consumer?.pause()
            updatePeerMediaState(false, remoteId: remoteId, mediaType: mediaType)
            socketEmitPauseProducer(producerId: producerId)
        }
    }
    
    func subscriptionHandler(_ isSubscribe: Bool, remoteId: String, mediaType: JMMediaType){
        if mediaType == .video {
            if isSubscribe{
                if !subscriptionVideoList.contains(remoteId){
                    LOG.debug("Subscribe- added \(remoteId)")
                    subscriptionVideoList.append(remoteId)
                }
            }
            else{
                LOG.debug("Subscribe- removed \(remoteId)")
                subscriptionVideoList.removeAll(where: {$0 == remoteId})
            }
        }
        else if mediaType == .shareScreen {
            LOG.debug("Subscribe- updated screenshare \(remoteId)")
            subscriptionScreenShareVideo = remoteId
        }
    }
}
