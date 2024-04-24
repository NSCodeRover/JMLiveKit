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
            
            .closeProducer,
            
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
        getConnectAfterDelay()
    }
    
    fileprivate func getConnectAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if self.connectionState == .connecting {
                self.jioSocket?.getReconnect()
            }
        }
    }
    
    func getJMMediaType(_ type: String, isScreenShareEnabled: Bool) -> JMMediaType{
        let mediaType = type.lowercased()
        
        if mediaType == "video" && isScreenShareEnabled{
            return JMMediaType.shareScreen
        }
        else if mediaType == "audio" && isScreenShareEnabled{
            return JMMediaType.shareScreenAudio
        }
        else if mediaType == "video"{
            return JMMediaType.video
        }
        
        return JMMediaType.audio
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
            
        case .closeProducer: //Server requesting to stop
            handleSocketProducer(json, event: event)
            
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
            print("addPeerIfAlreadyJoinMeetingRoom out Start")
            self.addPeerIfAlreadyJoinMeetingRoom(json: json) { peers in
                for peer in peers {
                    self.delegateBackToManager?.sendClientUserJoined(user: self.formatToJMUserInfo(from: peer))
                    if let audioConsumer =  peer.producers.first(where: { $0.mediaType == .audio }){
                        self.socketEmitGetConsumerInfo(for: peer.peerId, consumerId: audioConsumer.producerId)
                    }
                }
            }
            print("addPeerIfAlreadyJoinMeetingRoom out End")
        }
    }
    
    private func handleSocketEmitNewConsumer(_ json: [String : Any]) {
        qJMMediaBGQueue.async {
            self.onNewConsumer(json: json)
        }
    }
    
    private func handleSocketEmitPeerLeave() {
        qJMMediaBGQueue.async { [weak self] in
            self?.dispose()
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
                let jmMediaType: JMMediaType = self.getJMMediaType(mediaType, isScreenShareEnabled: isScreenShareEnabled)
                
                if event == .closeProducer{ //self event
                    self.handleSocketSelfCloseRequest(producerId, peerId: remoteId, mediaType: jmMediaType)
                    return
                }
                
                LOG.debug("Subscribe- Socket- \(event) for type- \(mediaType) and sharing \(isScreenShareEnabled) == \(jmMediaType)")
                self.updateVideoProducerId(producerId, remoteId: remoteId, mediaType: jmMediaType, event: event)
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
        qJMMediaBGQueue.async {
            if let peer = self.parse(json: json, model: Peer.self) {
                let user = self.formatToJMUserInfo(from: peer)
                self.delegateBackToManager?.sendClientUserJoined(user: user)
                self.updatePeerMap(for: peer.peerId, withPeer: peer)
            }
        }
    }
    
    private func handleSocketPeerLeft(_ json: [String : Any]) {
        if let peerId = json[SocketDataKey.peerId.rawValue] as? String{
            LOG.debug("UserLeave- \(peerId) with reason \(json["reason"] as? String)")
            let reason: JMUserLeaveReason = (json["reason"] as? String ?? "").lowercased() == "quit" ? .userAction : .unknown
            self.delegateBackToManager?.sendClientUserLeft(id: peerId, reason: reason)
            removePeer(for: peerId)
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
            LOG.debug("Reconnect- reconnected  device == nil")
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
            let mediaType: JMMediaType = getJMMediaType(score.mediaType, isScreenShareEnabled: score.share)
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
            let jmMediaType: JMMediaType = getJMMediaType(kind, isScreenShareEnabled: isScreenShareEnabled)
            
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
                else{
                    if audioRemotePeerVolume != -1.0{
                        LOG.info("Audio- User- \(remoteId) Remote peer volume set to \(audioRemotePeerVolume)")
                        setVolume(consumer)
                    }
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
        
        self.jioSocket?.getSocket()?.emitWithAck(SocketEmitAction.connectWebRtcTransport.rawValue, parameters).timingOut(after: 10) { data in
            
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
            self.jioSocket?.getSocket()?.emitWithAck(SocketEmitAction.produce.rawValue, parameters).timingOut(after: 10) { data in
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
    
    func handleSocketSelfCloseRequest(_ producerId: String, peerId: String, mediaType: JMMediaType){
        
        guard peerId == userState.selfPeerId else { return }
        LOG.debug("Socket- Self stop request for type- \(mediaType)")
        
        switch mediaType {
        case .audio:
            if producerId == audioProducer?.id{
                disableMic()
                delegateBackToManager?.sendClientSelfLocalMediaState(type: mediaType, reason: .audioStoppedByServer)
            }
        case .video:
            if producerId == videoProducer?.id{
                disableVideo()
                delegateBackToManager?.sendClientSelfLocalMediaState(type: mediaType, reason: .videoStoppedByServer)
            }
        case .shareScreen:
            if producerId == screenShareProducer?.id{
                updateStopScreenShare()
                delegateBackToManager?.sendClientSelfLocalMediaState(type: mediaType, reason: .screenshareStoppedByServer)
            }
            
        default: break
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
        else if mediaType == .shareScreen{
            updatePeerMediaState(mediaStateEnabled, remoteId: remoteId, mediaType: mediaType)
        }
        else{
            feedHandler(mediaStateEnabled, remoteId: remoteId, mediaType: mediaType)
        }
    }
}

//MARK: Media state updation
extension JMManagerViewModel{
    
    func updatePeerMediaConsumer(_ consumer: Consumer?, remoteId: String, mediaType: JMMediaType){
        if var updatedPeer = self.getPeerObject(for: remoteId) {
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
            else if mediaType == .shareScreenAudio{
                updatedPeer.consumerScreenShareAudio = consumer
            }
            updatePeerMap(for: remoteId, withPeer: updatedPeer)
        }
    }
    
    func updatePeerMediaState(_ isEnabled: Bool, remoteId: String, mediaType: JMMediaType, isSelfAction: Bool = false) {
        if var updatedPeer = self.getPeerObject(for: remoteId) {
            if mediaType == .audio{
                if updatedPeer.isAudioEnabled == isEnabled{
                    return
                }
                updatedPeer.isAudioEnabled = isEnabled
            }
            else if mediaType == .video{
                if updatedPeer.isVideoEnabled == isEnabled{
                    return
                }
                updatedPeer.isVideoEnabled = isEnabled
            }
            else if mediaType == .shareScreen{
                if (updatedPeer.isScreenShareEnabled == isEnabled) && isEnabled {
                    return
                }
                updatedPeer.isScreenShareEnabled = isEnabled
            }
            updatePeerMap(for: remoteId, withPeer: updatedPeer)
            
            if isSelfAction && mediaType == .shareScreen {
                //Workaround - Cpass need this to handle the screenshare. self action for camera, mic is needed but not for screenshare.
                LOG.debug("Subscribe- SELF ACTION callback ignored. User- \(updatedPeer.displayName) for type- \(mediaType)")
            }
            else{
                self.setRemoteUserMediaAction(isEnabled: isEnabled, id: remoteId, type: mediaType)
            }
        }
    }
}

//MARK: Producer id updation
extension JMManagerViewModel{
    
    func endProducer(for remoteId: String, mediaType: JMMediaType) {
        guard var updatedPeer = self.getPeerObject(for: remoteId) else {
            return
        }
        
        LOG.debug("Subscribe- consumer updated to nil. User- \(updatedPeer.displayName) for type- \(mediaType)")
        switch mediaType {
        case .video:
            if !(updatedPeer.consumerVideo?.closed ?? true) {
                updatedPeer.consumerVideo?.close()
            }
            updatedPeer.consumerVideo = nil
            
            self.updatePreferredQuality()
            
        case .shareScreen:
            if !(updatedPeer.consumerScreenShare?.closed ?? true) {
                updatedPeer.consumerScreenShare?.close()
            }
            updatedPeer.consumerScreenShare = nil
            removeRemoteShareViews(updatedPeer.remoteScreenshareView)
            updatedPeer.remoteScreenshareView = nil
            
            userState.disableRemoteScreenShare()
            self.updatePreferredPriority()
            
        case .shareScreenAudio:
            updatedPeer.consumerScreenShareAudio?.close()
            updatedPeer.consumerScreenShareAudio = nil
            
        case .audio:
            updatedPeer.consumerAudio?.close()
            updatedPeer.consumerAudio = nil
        }
        
        //Clear the consumer queue for type.
        updatedPeer.consumerQueue.removeValue(forKey: mediaType)
        
        //Deleting the producer object...
        if let objectPresentAtIndex = updatedPeer.producers.firstIndex(where: { $0.mediaType == mediaType })
        {
            updatedPeer.producers.remove(at: objectPresentAtIndex)
        }
        updatePeerMap(for: remoteId, withPeer: updatedPeer)
    }
    
    func updateVideoProducerId(_ producerId: String, remoteId: String, mediaType: JMMediaType, event: SocketEvent){
        if event == .newProducer || event == .resumedProducer{
            updateVideoProducerId(producerId, producerPaused: false, remoteId: remoteId, mediaType: mediaType)
        }
        else if event == .pausedProducer{
            updateVideoProducerId(producerId, producerPaused: true, remoteId: remoteId, mediaType: mediaType)
        }
        else if event == .producerEnd{
            endProducer(for: remoteId, mediaType: mediaType)
        }
    }
    
    func updateVideoProducerId(_ producerId: String, producerPaused: Bool, remoteId: String, mediaType: JMMediaType){
        if var updatedPeer = self.getPeerObject(for: remoteId) {
            
            //On new producer, clear the consumer queue.
            updatedPeer.consumerQueue.removeValue(forKey: mediaType)
            
            if let objectPresentAtIndex = updatedPeer.producers.firstIndex(where: { $0.mediaType == mediaType })
            {
                LOG.debug("Subscribe- pid updated. User- \(updatedPeer.displayName) for type- \(mediaType)")
                var updatedProducer = updatedPeer.producers[objectPresentAtIndex]
                updatedProducer.producerId = producerId
                updatedProducer.paused = producerPaused
                updatedPeer.producers[objectPresentAtIndex] = updatedProducer
            }
            else{
                LOG.debug("Subscribe- new pid updated. User- \(updatedPeer.displayName) for type- \(mediaType)")
                let producer = PeerProducer(mediaType: mediaType, producerId: producerId, paused: producerPaused)
                updatedPeer.producers.append(producer)
            }
            updatePeerMap(for: remoteId, withPeer: updatedPeer)
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
        if jioSocket?.getSocket()?.status != .connected {
            return
        }
        subscriptionHandler(isSubscribe, remoteId: remoteId, mediaType: mediaType)
        
        if !isVideoFeedDisable(mediaType){
            feedHandler(isSubscribe, remoteId: remoteId, mediaType: mediaType, isSelfAction: true)
        }
    }
    
    func feedHandler(_ isSubscribe: Bool, remoteId: String, mediaType: JMMediaType, isSelfAction: Bool = false){
        guard var peer = self.getPeerObject(for: remoteId)
        else{
            LOG.error("Subscribe- peer not present. uid-\(remoteId) for type- \(mediaType).")
            return
        }
        
        let consumer = peer.getConsumer(for: mediaType)
        if isSubscribe {
            
            guard let producerId = peer.getProducerId(for: mediaType)
            else{
                LOG.debug("Subscribe- Not producing id. No action. User- \(peer.displayName) for type- \(mediaType).")
                return
            }
            
            if peer.isProducerPaused(for: mediaType){
                LOG.debug("Subscribe- Not producing enable. No action. User- \(peer.displayName) for type- \(mediaType).")
                return
            }
            
            if let consumer = consumer, consumer.producerId == producerId{
                
                if peer.isResumed(for: mediaType){
                    LOG.debug("Subscribe- Consumer already resumed. no action. User- \(peer.displayName) for type- \(mediaType).")
                    return
                }
                
                LOG.debug("Subscribe- consumer resumed. User- \(peer.displayName) for type- \(mediaType).")
                consumer.resume()
                updatePeerMediaState(true, remoteId: remoteId, mediaType: mediaType, isSelfAction: isSelfAction)
                socketEmitResumeConsumer(for: consumer.id)
            }
            else{
                if peer.consumerQueue[mediaType] == nil{
                    LOG.debug("Subscribe- consumer fetch User- \(peer.displayName) for type- \(mediaType).")
                    socketEmitGetConsumerInfo(for: remoteId, consumerId: producerId)
                    
                    //Adding to queue
                    peer.consumerQueue[mediaType] = true
                    updatePeerMap(for: remoteId, withPeer: peer)
                }
            }
        }
        else{
            if let consumer = consumer{
                
                if !peer.isResumed(for: mediaType){
                    LOG.debug("Subscribe- Consumer already paused. no action. User- \(peer.displayName) for type- \(mediaType).")
                    return
                }
                
                consumer.pause()
                socketEmitPauseConsumer(for: consumer.id)
                LOG.debug("Subscribe- consumer paused. User- \(peer.displayName) for type- \(mediaType).")
            }
            else{
                LOG.debug("Subscribe- Not an issue. Consumer is nil. User- \(peer.displayName) for type- \(mediaType).")
            }
            
            updatePeerMediaState(false, remoteId: remoteId, mediaType: mediaType, isSelfAction: isSelfAction)
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

//MARK: Peer updation

extension JMManagerViewModel {
    func updatePeerMap(for remoteId: String, withPeer: Peer) {
     //   lockPeer.writeLock()
        //semaphore.wait()
      //  var peers = self.peersMap
        self.peersMap[remoteId] = withPeer
        //self.peersMap = peers
     //   peers.removeAll()
        //semaphore.signal()
       // lockPeer.unlock()
    }
    
    func removePeer(for remoteId: String) {
        //lockPeer.writeLock()
      //  semaphore.wait()
        self.peersMap.removeValue(forKey: remoteId)
       // semaphore.signal()
        //lockPeer.unlock()
    }
    
    func getPeerObject(for remoteId: String) -> Peer? {
       // semaphore.wait()
        //var peers = self.peersMap
     //  lockPeer.readLock()
        let peer = peersMap[remoteId]
      //  semaphore.signal()
        //peers.removeAll()
      //  lockPeer.unlock()
        return peer
    }
}
