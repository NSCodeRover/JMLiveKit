//
//  JMManager-BroadcastMessage.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 21/08/23.
//

import Foundation

// Sender function to broadcast a message

extension JMManagerViewModel {
    
    func sendJMBroadcastPublicMessage(messageInfo:[String: Any]){
        
        let broadcastMessage: [String: Any] = [
               "eventName": JMRTMMessagesType.broadcastMessage.rawValue,
               "timeStamp":  Date().timeIntervalSince1970 * 1000,
               "peerId": selfPeerId,
               "msgData": messageInfo
           ]
        
        self.jioSocket.emit(action: SocketEmitAction.init(rawValue: JMRTMMessagesType.broadcastMessage.rawValue) ?? .none, parameters:broadcastMessage ){ _ in }
    }
    
    func sendJMBroadcastPrivateMessage(messageInfo:[String: Any]){
        let broadcastMessage: [String: Any] = [
               "eventName": JMRTMMessagesType.broadcastMessageToPeer.rawValue,
               "timeStamp":  Date().timeIntervalSince1970 * 1000,
               "peerId": selfPeerId,
               "msgData": messageInfo
           ]
        
        self.jioSocket.emit(action: SocketEmitAction.init(rawValue: JMRTMMessagesType.broadcastMessageToPeer.rawValue) ?? .none, parameters:broadcastMessage ){ _ in }
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
