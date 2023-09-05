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

    func sendJMBroadcastPublicMessage(messageInfo:[String: Any]){
        
        let broadcastMessage: [String: Any] = [
               "eventName": SocketEmitAction.broadcastMessage.rawValue,
               "timeStamp":  Date().timeIntervalSince1970 * 1000,
               "peerId": userState.selfPeerId,
               "msgData": messageInfo
           ]
        
        self.jioSocket.emit(action: .broadcastMessage, parameters:broadcastMessage){ _ in }
    }
    
    func sendJMBroadcastPrivateMessage(messageInfo:[String: Any]){
        let broadcastMessage: [String: Any] = [
               "eventName": SocketEmitAction.broadcastMessageToPeer.rawValue,
               "timeStamp":  Date().timeIntervalSince1970 * 1000,
               "peerId": userState.selfUserName,
               "msgData": messageInfo
           ]
        
        self.jioSocket.emit(action: .broadcastMessageToPeer, parameters:broadcastMessage){ _ in }
    }
    
    func createMessageInfo(message: String, senderName: String, senderParticipantId: String) -> [String: Any] {
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
