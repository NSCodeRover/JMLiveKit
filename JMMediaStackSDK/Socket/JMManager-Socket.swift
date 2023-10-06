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
    
    internal func connect(socketUrl: String, roomId: String, jwtToken: String, isRejoin: Bool) {
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
            .broadcastMessageToPeer,
            
            .score
            
            //NOT NEEDED
//            .layerschange
            
            //NOT HANDLED
//            .botsJoined,
//            .botsLeft,
//            .userRoleUpdated
        ]
        initFactoryAndStream()
        jioSocket?.connect(socketUrl: url, roomId: roomId, jwtToken: jwtToken, ip: ip, delegate: self, socketEvents: events, isRejoin: isRejoin, queue: qJMMediaNWQueue)
    }
}

// MARK: - Socket Callbacks
extension JMManagerViewModel: JioSocketDelegate {
    
    func didConnectionStateChange(_ state: JMSocketConnectionState) {
        LOG.info("Reconnect- state: \(state)")
        
        if connectionState == state{
            return
        }
        
        connectionState = state
        delegateBackToManager?.sendClientConnectionStateChanged(state: connectionState)
        
        if connectionState == .disconnected && !isCallEnded{
            //Clearing data for rejoin/leave
            self.qJMMediaBGQueue.async {
                self.dispose()
            }
        }
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
            
        case .score: //Remote quality
            handleSocketScoreChange(json)
            
        case .layerschange: //Layer (Resolution/FPS) producer change
            handleLayerChange(json)
            
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
                
                if let audioConsumer = $0.producers.first(where: { $0.mediaType == .audio }){
                    self.socketEmitGetConsumerInfo(for: $0.peerId, consumerId: audioConsumer.producerId)
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
                    self.userState.enableSelfScreenShare(producerId: id)
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
                    self.updateVideoProducerId(producerId, remoteId: remoteId, mediaType: jmMediaType)
                }
                else if event == .producerEnd{
                    self.endProducer(for: remoteId, mediaType: jmMediaType)
                }
                
                self.onProducerUpdate(producerId, remoteId: remoteId, mediaType: jmMediaType, event: event)
            }
        }
    }
    
    private func handleSocketSelfPeerConnected(_ json: [String : Any]) {
        if let peerId = json[SocketDataKey.peerId.rawValue] as? String {
            self.userState.selfPeerId = peerId
            self.jioSocket?.updateConfig(peerId)
            
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
        if let peerId = json[SocketDataKey.peerId.rawValue] as? String{
            LOG.debug("UserLeave- \(peerId) with reason \(json["reason"] as? String)")
            let reason: JMUserLeaveReason = (json["reason"] as? String ?? "").lowercased() == "quit" ? .userAction : .unknown
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
            self.delegateBackToManager?.sendClientBroadcastMessageToPeer(msg: msgData)
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
    
    private func handleSocketScoreChange(_ json: [String : Any]) {
        //LOG.debug("Score- "+json.description)
        if let score = parse(json: json, model: ScoreInfo.self) {
            let scoreQuality:JMNetworkQuality = score.score.score <= 7 ? .Bad : .Good
            let mediaType: JMMediaType = score.share ? .shareScreen : score.mediaType == "video" ? .video : .audio
            LOG.debug("Score- for \(score.producerPeerId)|\(score.score.score)|\(mediaType.rawValue)")
            self.delegateBackToManager?.sendClientRemoteNetworkQuality(id: score.producerPeerId, quality: scoreQuality, mediaType: mediaType)
        }
    }
    
    private func handleLayerChange(_ json: [String : Any]) {
        //Future scope - We are not yet handling anything for layer change.
        LOG.debug("Layer- \(json.description)")
    }
}

//MARK: Consume
extension JMManagerViewModel{
    
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
            
            guard let recvTransport = recvTransport else {
                LOG.error("recvTransport- recvTransport Transport not available. remote - \(remoteId)")
                return
            }
            
            let isScreenShareEnabled = appData["share"] as? Bool ?? false
            let jmMediaType: JMMediaType = isScreenShareEnabled ? .shareScreen : mediaKind == .video ? .video : .audio
            
            let result = handleMediaSoupErrors("Subscribe-"){
                let consumer = try recvTransport.consume(consumerId: consumerId, producerId: producerId, kind: mediaKind, rtpParameters: rtpParameters, appData: JSON(appData).description)
                
                self.updatePeerMediaConsumer(consumer, remoteId: remoteId, mediaType: jmMediaType)
                self.updatePeerMediaState(true, remoteId: remoteId, mediaType: jmMediaType)
                self.socketEmitResumeConsumer(for: consumerId)
                consumer.resume()
                
                //Update renderer track
                if jmMediaType == .shareScreen{
                    self.updateRemoteScreenShareRenderViewTrack(for: remoteId)
                    self.userState.enableRemoteScreenShare(for: remoteId, consumerId: consumerId)
                    self.setPreferredPriority(remoteId: remoteId, consumerId: consumerId, mediaType: jmMediaType)
                }
                else if jmMediaType == .video{
                    self.updateRemoteRenderViewTrack(for: remoteId)
                    self.totalVideoConsumer[remoteId] = consumerId
                    self.setPreferredPriority(remoteId: remoteId, consumerId: consumerId, mediaType: jmMediaType)
                }
            }
            
            LOG.info("Subscribe- \(jmMediaType) \(producerId) consumer \(result ? "added" : "failed")")
            if !result{
                delegateBackToManager?.sendClientError(error: JMMediaError.init(type: getStreamingError(for: jmMediaType), description: remoteId))
            }
        }
    }
}

//MARK: Socket emit Producer Consumer
extension JMManagerViewModel{
    
    //Self Producer
    func socketEmitCloseProducer(for producerId: String) {
        self.jioSocket?.emit(action: .closeProducer, parameters: JioSocketProperty.getProducerProperty(with: producerId))
    }
    
    func socketEmitPauseProducer(for producerId: String) {
        self.jioSocket?.emit(action: .pauseProducer, parameters: JioSocketProperty.getProducerProperty(with: producerId))
    }
    
    func socketEmitResumeProducer(for producerId: String) {
        self.jioSocket?.emit(action: .resumeProducer, parameters: JioSocketProperty.getProducerProperty(with: producerId))
    }
    
    //Remote Consumer
    func socketEmitGetConsumerInfo(for peerId: String, consumerId: String) {
        //Consume needs producerId
        self.jioSocket?.emit(action: .consume, parameters: JioSocketProperty.getConsumerProperty(with: consumerId, remoteId: peerId))
    }
    
    func socketEmitResumeConsumer(for consumerId: String) {
        self.jioSocket?.emit(action: .resumeConsumer, parameters: JioSocketProperty.getConsumerProperty(with: consumerId))
    }
    
    func socketEmitPauseConsumer(for consumerId: String) {
        self.jioSocket?.emit(action: .pauseConsumer, parameters:JioSocketProperty.getConsumerProperty(with: consumerId))
    }

    //Join, Leave
    func socketEmitSelfPeerLeave() {
        self.jioSocket?.emit(action: .peerLeave, parameters: JioSocketProperty.getClosePeerLeaveProperty(peerId: self.userState.selfPeerId))
    }
    
    //Transportstats
    func socketEmitSetTransportStats() {
        self.jioSocket?.emit(action: .getTransportStats , parameters: transportStatsParam)
    }
    
}

extension JMManagerViewModel{
    func emitOnConnectWebRtc(transportId:String, dtlsParameters: String!, handler: ((([String:Any]) -> Void)?)) {
        let parameters:[String:Any] = JioSocketProperty.getTransportProperty(with: transportId, dtlsParameters: dtlsParameters)
        
        if connectionState != .connected {
            LOG.warning("Socket- Transport- Ack- socket not connected")
            return
        }
        
        self.jioSocket?.getSocket().emitWithAck(SocketEmitAction.connectWebRtcTransport.rawValue, parameters).timingOut(after: 10) { data in
            
            if let json = self.getJson(data: data) {
                LOG.debug("Socket- Transport- Ack- Emit Webrtc json == \(json)")
                handler?(json)
            }
            else{
                LOG.warning("Socket- Transport- Ack- Emit Webrtc NO json")
                handler?([:])
            }
        }
    }
    
    func emitOnProduce(transportId:String, kind:String, rtpParameters:String, appData: String, handler: ((String) -> ())?) {
        var parameters:[String:Any] = JioSocketProperty.getTransportProduceProperty(with: transportId, kind: kind, rtpParameters: rtpParameters)
        
        if appData == JioMediaAppData.screenShareAppData{
            parameters[SocketDataKey.appData.rawValue] = ["share":true]
            self.jioSocket?.emit(action: .produce, parameters: parameters)
            handler?("ID not found")
        }
        else {
            self.jioSocket?.getSocket().emitWithAck(SocketEmitAction.produce.rawValue, parameters).timingOut(after: 10) { data in
                if let json = self.getJson(data: data),
                   let dataObj = json["data"] as? [String:Any],
                   let id = dataObj["id"] as? String {
                    LOG.debug("Socket- Transport- Ack- produce Id == \(id)")
                    handler?(id)
                }
                else{
                    LOG.warning("Socket- Transport- Ack- produce no Id.")
                    handler?("ID not found")
                }
            }
        }
    }
}


//MARK: Producer updation : Socket
extension JMManagerViewModel{
        
    func onProducerUpdate(_ producerId: String, remoteId: String, mediaType: JMMediaType, event: SocketEvent) {

        if isVideoFeedDisable(mediaType){
            //IGNORE updating video for AudioOnly
            return
        }
        
        let mediaStateEnabled = (event == .resumedProducer || event == .newProducer) ? true : false
        if mediaType == .video{
            if subscriptionVideoList.contains(remoteId){
                LOG.debug("Subscribe- already in subscribed list. Fetching details...")
                feedHandler(mediaStateEnabled, remoteId: remoteId, mediaType: mediaType)
            }
        }
        else{
            feedHandler(mediaStateEnabled, remoteId: remoteId, mediaType: mediaType)
        }
    }
}

//MARK: Media state updation
extension JMManagerViewModel{
    
    func updatePeerMediaConsumer(_ consumer: Consumer?, remoteId: String, mediaType: JMMediaType){
        if var updatedPeer = self.peersMap[remoteId] {
            updatedPeer.consumerQueue.removeValue(forKey: mediaType)
            
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
    
    func endProducer(for remoteId: String, mediaType: JMMediaType) {
        guard var updatedPeer = self.peersMap[remoteId] else {
            return
        }
        
        LOG.debug("Subscribe- consumer updated to nil \(updatedPeer.displayName) mediatype \(mediaType)")
        switch mediaType {
        case .video:
            updatedPeer.consumerVideo?.close()
            updatedPeer.consumerVideo = nil
            
            self.updatePreferredQuality()
        case .shareScreen:
            updatedPeer.consumerScreenShare?.close()
            updatedPeer.consumerScreenShare = nil
            removeRemoteShareViews(updatedPeer.remoteScreenshareView)
            updatedPeer.remoteScreenshareView = nil
            
            userState.disableRemoteScreenShare()
            self.updatePreferredPriority()
        case .audio:
            updatedPeer.consumerAudio?.close()
            updatedPeer.consumerAudio = nil
        }
        
        peersMap[remoteId] = updatedPeer
    }
    
    func updateVideoProducerId(_ producerId: String, remoteId: String, mediaType: JMMediaType){
        if var updatedPeer = self.peersMap[remoteId] {
            if let objectPresentAtIndex = updatedPeer.producers.firstIndex(where: { $0.mediaType == mediaType })
            {
                LOG.debug("Subscribe- pid updated \(updatedPeer.displayName)")
                var updatedProducer = updatedPeer.producers[objectPresentAtIndex]
                updatedProducer.producerId = producerId
                updatedPeer.producers[objectPresentAtIndex] = updatedProducer
            }
            else{
                LOG.debug("Subscribe- new pid updated \(updatedPeer.displayName)")
                let producer = PeerProducer(mediaType: mediaType, producerId: producerId, paused: false)
                updatedPeer.producers.append(producer)
            }
            peersMap[remoteId] = updatedPeer
        }
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
        guard var peer = peersMap[remoteId], let producerId = peer.getProducerId(for: mediaType)
        else{
            LOG.error("Subscribe- \(peersMap[remoteId]?.displayName) not producing. remoteid-\(remoteId) \(mediaType) ")
            return
        }
        
        let consumer = peer.getConsumer(for: mediaType)
        if isSubscribe {
            if let consumer = consumer, consumer.producerId == producerId{
                LOG.debug("Subscribe- \(mediaType) \(peer.displayName):consumer resumed")
                consumer.resume()
                updatePeerMediaState(true, remoteId: remoteId, mediaType: mediaType)
                socketEmitResumeConsumer(for: consumer.id)
            }
            else{
                if peer.consumerQueue[mediaType] == nil{
                    LOG.debug("Subscribe- \(mediaType) \(peer.displayName):consumer fetch")
                    socketEmitGetConsumerInfo(for: remoteId, consumerId: producerId)
                    
                    //Adding to queue
                    peer.consumerQueue[mediaType] = true
                    peersMap[remoteId] = peer
                }
            }
        }
        else{
            if let consumer = consumer{
                consumer.pause()
                socketEmitPauseConsumer(for: consumer.id)
                LOG.debug("Subscribe- \(mediaType) \(peer.displayName):consumer paused")
            }
            else{
                LOG.debug("Subscribe- Not an issue. Consumer is nil for \(peer.displayName)")
            }
            updatePeerMediaState(false, remoteId: remoteId, mediaType: mediaType)
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
    }
}
