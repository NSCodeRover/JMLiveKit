//
//  JMMediaTransport.swift
//  MediaStack
//
//  Created by Harsh1 Surati on 30/06/23.
//

import Foundation

import SwiftyJSON
import Mediasoup

extension JMManagerViewModel {
    
    func createSendTransport(json: [String: Any], device: Device?, socketIp: String) -> SendTransport? {
        
        let tuple = self.getTransportParameters(json: json, socketIp: socketIp)
        do {
            let sendTransport = try device?.createSendTransport(
                id: tuple.id,
                iceParameters: tuple.iceParameters,
                iceCandidates: tuple.iceCandidates,
                dtlsParameters: tuple.dtlsParameters,
                sctpParameters: nil,
                appData: nil)
            return sendTransport
        }
        catch let error as MediasoupError {
            LOG.debug("Transport- Send- Error- \(error.localizedDescription)")
        }
        catch {
            LOG.debug("Transport Send- Error- unknown \(error.localizedDescription)")
        }
        return nil
    }
        
    func createReceiveTransport(json: [String: Any], device: Device?, socketIp: String) -> ReceiveTransport? {
        
        let tuple = self.getTransportParameters(json: json, socketIp: socketIp)
        do {
            let receiveTransport = try device?.createReceiveTransport(
                id: tuple.id,
                iceParameters: tuple.iceParameters,
                iceCandidates: tuple.iceCandidates,
                dtlsParameters: tuple.dtlsParameters)
            return receiveTransport
        }
        catch let error as MediasoupError {
            LOG.debug("Transport- Receive- Error- \(error.localizedDescription)")
        }
        catch {
            LOG.debug("Transport- Receive- Error- unknown \(error.localizedDescription)")
        }
        return nil
    }
    
    private func getTransportParameters(json: [String: Any], socketIp: String) -> (id: String, iceParameters: String, iceCandidates: String, dtlsParameters: String) {
        let id = json.strValue("id")
        let iceParameters = JSON(json.dictionary(SocketDataKey.iceParameters.rawValue)).description
        var iceCandidatesArray = json.array(SocketDataKey.iceCandidates.rawValue)
        if var first = iceCandidatesArray.first{
            first["ip"] = socketIp
            iceCandidatesArray[0] = first
        }
        let iceCandidates = JSON(iceCandidatesArray).description
        let dtlsParameters = JSON(json.dictionary(SocketDataKey.dtlsParameters.rawValue)).description
        let tuple: (id: String, iceParameters: String, iceCandidates: String, dtlsParameters: String) = (id: id, iceParameters: iceParameters, iceCandidates: iceCandidates, dtlsParameters: dtlsParameters)
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
        
        //MeetingEndCase
        if connectionState == .disconnected && isCallEnded{
            LOG.error("Transport- End- transport close")
            transport.close()
        }
    }
}

