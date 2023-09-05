//
//  Models-Public+BroadcastMessage.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 21/08/23.
//

import Foundation


public enum JMRTMMessagesType: String, Codable {
    case broadcastMessage
    case broadcastMessageToPeer
}
public enum JMRTMMessage: String,Codable {
    case PARTICIPANT_BACKGROUND_ACTIVATED = "PARTICIPANT_BACKGROUND_ACTIVATED"
    case PARTICIPANT_BACKGROUND_INACTIVATED = "PARTICIPANT_BACKGROUND_INACTIVATED"
    case NONE = ""
}
