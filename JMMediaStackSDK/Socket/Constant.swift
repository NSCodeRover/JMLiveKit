//  Constant.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 07/02/23.
//

import Foundation

enum SocketDataKey: String {
    case producerId
    case producerPeerId
    case peerId
    case mediaType
    case video
    case audio
    case appData
    case rtpParameters
    case kind
    case status
    case data
    case consumerInfo
    case ok
    case consumerId
    case transportId
    case dtlsParameters
    case device
    case rtpCapabilities
    case sctpCapabilities
    case metaData
    case userType
    case userRole
    case human
    case host
    case videoGoogleStartBitrate
    case receiveTransport
    case sendTransport
    case iceParameters
    case iceCandidates
}

enum ReceiveTransportKey: String {
    case dtlsParameters
    case iceServers
    case iceTransportPolicy
}
