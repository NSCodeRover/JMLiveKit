//
//  JMMediaTransport.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 30/06/23.
//

import Foundation

@_implementationOnly import SwiftyJSON
import Mediasoup

extension JMManagerViewModel {
    
    func createSendTransport(json: [String: Any], device: Device?) -> SendTransport? {
        
        var sendTransport: SendTransport? = nil
        let result = handleMediaSoupErrors("Transport- Send-"){
            let tuple = self.getTransportParameters(json: json)
            sendTransport = try device?.createSendTransport(
                id: tuple.id,
                iceParameters: tuple.iceParameters,
                iceCandidates: tuple.iceCandidates,
                dtlsParameters: tuple.dtlsParameters,
                sctpParameters: nil,
                iceServers: tuple.iceServers,
                iceTransportPolicy: tuple.isRelayTransportPolicy ? .relay : .all,
                appData: nil
            )
        }
        
        if !result{
            LOG.error("Transport- Send- Failed  \(String(describing: result.toDictionary()))")
        }else{
            LOG.info("Transport- Send- Successful \(String(describing: result.toDictionary()))")
        }
        
        return sendTransport
    }
        
    func createReceiveTransport(json: [String: Any], device: Device?) -> ReceiveTransport? {
        
        var receiveTransport: ReceiveTransport? = nil
        let result = handleMediaSoupErrors("Transport- Receive-"){
            let tuple = self.getTransportParameters(json: json)
            receiveTransport = try device?.createReceiveTransport(
                id: tuple.id,
                iceParameters: tuple.iceParameters,
                iceCandidates: tuple.iceCandidates,
                dtlsParameters: tuple.dtlsParameters,
                iceServers: tuple.iceServers,
                iceTransportPolicy: tuple.isRelayTransportPolicy ? .relay : .all
            )
        }
        
        if !result{
            LOG.error("Transport- Receive- Failed  \(String(describing: result.toDictionary()))")
        }else{
            LOG.info("Transport- Receive- Successful \(String(describing: result.toDictionary()))")
        }
        
        return receiveTransport
    }
    
    private func getTransportParameters(json: [String: Any]) -> (id: String, iceParameters: String, iceCandidates: String, dtlsParameters: String, iceServers: String?, isRelayTransportPolicy: Bool) {
        let id = json.strValue("id")
        let iceParameters = JSON(json.dictionary(SocketDataKey.iceParameters.rawValue)).description
        let iceCandidatesArray = json.array(SocketDataKey.iceCandidates.rawValue)
        let iceCandidates = JSON(iceCandidatesArray).description
        let dtlsParameters = JSON(json.dictionary(SocketDataKey.dtlsParameters.rawValue)).description
        
        let iceServers = getIceServer(from: json)
        let isRelayTransportPolicy = isRelayTransportPolicy(forTransport: json)
        
        let tuple: (id: String, iceParameters: String, iceCandidates: String, dtlsParameters: String, iceServers: String?, isRelayTransportPolicy: Bool) = (id: id, iceParameters: iceParameters, iceCandidates: iceCandidates, dtlsParameters: dtlsParameters,iceServers: iceServers, isRelayTransportPolicy: isRelayTransportPolicy)
            
        return tuple
    }
}

extension JMManagerViewModel: SendTransportDelegate, ReceiveTransportDelegate{
        
    func onProduce(transport: Transport, kind: MediaKind, rtpParameters: String, appData: String,
        callback: @escaping (String?) -> Void) {
        LOG.debug("Transport- On produce callback TID - \(transport.id)")
        let kindValue = kind == MediaKind.video ? "video" : "audio"
        self.emitOnProduce(transportId: transport.id, kind: kindValue, rtpParameters: rtpParameters, appData: appData) { producerId in
            LOG.debug("Transport- producerId - \(producerId)")
            callback(producerId)
        }
    }

    func onProduceData(transport: Transport, sctpParameters: String, label: String,
        protocol dataProtocol: String, appData: String, callback: @escaping (String?) -> Void) {
        LOG.debug("Transport- on produce data \(label)")
    }

    func onConnect(transport: Transport, dtlsParameters: String) {
        self.emitOnConnectWebRtc(transportId: transport.id, dtlsParameters: dtlsParameters, handler: {_ in })
    }

    func onConnectionStateChange(transport: Transport, connectionState: TransportConnectionState) {
        LOG.debug("Transport- Reconnect- \(transport.id == sendTransport?.id ? "send" : "receive") onConnectionStateChange == \(connectionState)")
        
        /*
        qJMMediaBGQueue.async {
            if connectionState == .disconnected{
                LOG.error("Transport- End- transport closed")
                transport.close()
                return
            }
            
            if connectionState == .closed && transport.id == self.sendTransport?.id{
                LOG.error("Transport- End- transport sent closed - stop capture")
                self.videoCapture?.stopCapture()
            }
        }
        */
    }
}

