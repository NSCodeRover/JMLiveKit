//
//  JioSocketProperty.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 06/03/23.
//

import Foundation

class JioSocketProperty {
    static func getCloseProducerProperty(producerId: String) -> [String: Any] {
        return [
            "producerId": producerId
        ]
    }
    
    static func getClosePeerLeaveProperty(peerId: String) -> [String: Any] {
        return [
            "peerId": peerId
        ]
    }
    
    static func getConsumeProperty(producerId: String) -> [String: Any] {
        return [
            "producerId": producerId
        ]
    }
    
    static func getResumeConsumerProperty(consumerId: String) -> [String: Any] {
        return [
            "consumerId": consumerId
        ]
    }
    
    static func getPauseAndResumerProducerProperty(producerId: String) -> [String: Any] {
        return [
            "producerId": producerId
        ]
    }
}
