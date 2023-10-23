//
//  JMManager-BroadcastMessage.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 21/08/23.
//

import Foundation

public enum JMRTMMessage: String,Codable {
    case PARTICIPANT_BACKGROUND_ACTIVATED = "PARTICIPANT_BACKGROUND_ACTIVATED"
    case PARTICIPANT_BACKGROUND_INACTIVATED = "PARTICIPANT_BACKGROUND_INACTIVATED"
}

extension JMManagerViewModel {

    func sendJMBroadcastPublicMessage(messageInfo:[String: Any],_ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil){
        
        let broadcastMessage: [String: Any] = [
               "eventName": SocketEmitAction.broadcastMessage.rawValue,
               "timeStamp":  Date().timeIntervalSince1970 * 1000,
               "peerId": userState.selfPeerId,
               "msgData": messageInfo
           ]
        
        self.jioSocket?.emit(action: .broadcastMessage, parameters:broadcastMessage){ [weak self] data in
            self?.handleAck(with: data, resultCompletion)
        }
    }
    
   
    func sendJMBroadcastPrivateMessage(messageInfo:[String: Any], toPeer: String,_ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil){
        let broadcastMessage: [String: Any] = [
               "eventName": SocketEmitAction.broadcastMessageToPeer.rawValue,
               "timeStamp":  Date().timeIntervalSince1970 * 1000,
               "peerId": userState.selfPeerId,
               "msgData": messageInfo,
               "targetPeerId": toPeer
           ]
        
        self.jioSocket?.emit(action: .broadcastMessageToPeer, parameters:broadcastMessage){ [weak self] data in
            self?.handleAck(with: data, resultCompletion)
        }
    }
    
    func handleAck(with data: [Any], _ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil){
        if let json = self.getJson(data: data), let status = json["status"] as? String{
            qJMMediaMainQueue.async {
                resultCompletion?(status.lowercased() == "ok")
            }
            
            if status.lowercased() != "ok"{
                LOG.debug("Socket- RTM- Ack- Status:\(status) error: \(json["error"])")
            }
        }
    }
    
    func createMessageInfo(message: String, senderName: String, senderParticipantId: String,_ resultCompletion: ((_ isSuccess: Bool) -> ())? = nil) -> [String: Any] {
        let messageInfo: [String: Any] = [
            "message": message,
            "reactionsType": "",
            "sender": [
                "name": senderName,
                "participantId": senderParticipantId,
                "userId": ""
            ],
            "targetParticipantId": "",
            "type": "PublicChat"
        ]
        
        return messageInfo
    }

}

extension Encodable {
    func toDictionary() -> [String: Any]? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            if let dictionary = jsonObject as? [String: Any] {
                return dictionary
            }
        } catch {
            print("Error converting object to dictionary: \(error)")
        }
        return nil
    }
}
