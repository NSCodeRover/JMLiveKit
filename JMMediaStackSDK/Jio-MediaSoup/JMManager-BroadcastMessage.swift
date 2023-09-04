//
//  JMManager-BroadcastMessage.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 21/08/23.
//

import Foundation

// Sender function to broadcast a message

extension JMManagerViewModel {
    func sendJMBroadcastPublicMessage(message: [String:Codable]) {
        var sender = JMSender()
        sender.name = selfDisplayName
        sender.participantId = selfPeerId

        let broadcastMessage = JMBroadcastMessage(eventName: JMRTMMessagesType.broadcastMessage.rawValue, msgData: message, peerId: sender.participantId, timeStamp: Date().timeIntervalSince1970 * 1000)
        
        print(broadcastMessage.toDictionary() ?? [:])
        
        self.jioSocket.emit(action: SocketEmitAction.init(rawValue: JMRTMMessagesType.broadcastMessage.rawValue) ?? .none, parameters:broadcastMessage.toDictionary() ?? [:] ){ _ in }
    }
    
    func sendJMBroadcastPrivateMessage(message: [String:Codable]) {
        var sender = JMSender()
        sender.name = selfDisplayName
        sender.participantId = selfPeerId
        sender.userId = ""
        
        
        let broadcastMessage = JMBroadcastMessage(eventName: JMRTMMessagesType.broadcastMessageToPeer.rawValue, msgData:message, peerId: sender.participantId, timeStamp: Date().timeIntervalSince1970 * 1000)
        
        self.jioSocket.emit(action: SocketEmitAction.init(rawValue: JMRTMMessagesType.broadcastMessageToPeer.rawValue) ?? .none, parameters:broadcastMessage.toDictionary() ?? [:] ){ _ in }
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
