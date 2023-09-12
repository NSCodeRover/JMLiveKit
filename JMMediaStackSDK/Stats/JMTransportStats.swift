//
//  TransportStats.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 28/07/23.
//

import Foundation

class JMTransportStats {
    static let shared = JMTransportStats()
    private init() {}
    
    typealias StatsTuple = (quality: JMNetworkQuality, packetLoss: Int)
    
    func getTransportStats(statsArray: [[String: Any]], sendTransportId: String, receiveTransportId: String) -> JMNetworkStatistics? {
        
        var mNetworkQuality: JMNetworkQuality = .Good
        var mUplinkPacketLoss: Int = 0
        var mDownlinkPacketLoss: Int = 0
      
        var uplinkData: StatsTuple? = nil
        var downlinkData: StatsTuple? = nil
        
        for stats in statsArray {
             guard let transportId = stats["transport"] as? String else {
                 continue
             }
             
             if sendTransportId == transportId && uplinkData == nil {
                 //LOG.debug("NetworkQuality- up stats: \((stats["stats"] as? [[String: Any]])?.first ?? [:])")
                 uplinkData = qualityAndPacketLoss(stats: (stats["stats"] as? [[String: Any]])?.first ?? [:])
             }
             
             if receiveTransportId == transportId && downlinkData == nil {
                 //LOG.debug("NetworkQuality- down stats: \((stats["stats"] as? [[String: Any]])?.first ?? [:])")
                 downlinkData = qualityAndPacketLoss(stats: (stats["stats"] as? [[String: Any]])?.first ?? [:])
             }
        }
        
        mNetworkQuality =  JMNetworkQuality(rawValue: max(uplinkData?.quality.rawValue ?? 0 ,downlinkData?.quality.rawValue ?? 0)) ?? .Good
        mUplinkPacketLoss = uplinkData?.packetLoss ?? 0
        mDownlinkPacketLoss = downlinkData?.packetLoss ?? 0
        
        //LOG.debug(("Stats- Network quality:" + mNetworkQuality.description + " | uplinkLoss:" ) + (mUplinkPacketLoss.description + " | downlinkLoss:" + mDownlinkPacketLoss.description))
        
        return JMNetworkStatistics(networkQuality: mNetworkQuality,remotePacketPercentLoss: mDownlinkPacketLoss,localPacketPercentLoss: mUplinkPacketLoss)
    }

    private func qualityAndPacketLoss(stats: [String: Any]) -> StatsTuple {
        let rtpPacketLoss = stats["rtpPacketLossSent"] as? Double ?? stats["rtpPacketLossReceived"] as? Double ?? 0
        var networkQuality: JMNetworkQuality = .Good
        var packetLoss = 0

        if !rtpPacketLoss.isNaN {
            packetLoss = Int(rtpPacketLoss * 100)
            if packetLoss <= 3 {
                networkQuality = .Good
            }
            else if packetLoss <= 15 {
                networkQuality = .Bad
            }
            else if packetLoss > 15 {
                networkQuality = .VeryBad
            }
        }
        return (networkQuality, packetLoss)
    }
}

//MARK: Get TransportStats Helper
extension JMManagerViewModel {
    
    func startTransportStatsScheduler() {
        setTransportStatRequestParam()
        scheduleTask()
    }
    
    private func scheduleTask() {
        self.socketEmitSetTransportStats()
        if sendTransport == nil || recvTransport == nil{
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if case .connected = self?.connectionState {
                self?.scheduleTask()
            }
        }
    }
    
    func setTransportStatRequestParam() {
        var data = [String: Any]()
        var transportIds = [String]()
        if let sendTransportId = sendTransport?.id, let receiveTransportId = recvTransport?.id {
            transportIds.append(receiveTransportId)
            transportIds.append(sendTransportId)
        }
        data["peerId"] = self.userState.selfPeerId
        data["transportIds"] = transportIds
        transportStatsParam = data
    }
    
    func setTransportState(_ json: [String : Any]) {
        if let status = json["status"] as? String, status.lowercased() == "ok",
           let data = json["data"] as? [String: Any],
           let statsArray = data["stats"] as? [[String: Any]] {
           let transportStats = JMTransportStats.shared.getTransportStats(statsArray: statsArray, sendTransportId: sendTransport?.id ?? "", receiveTransportId: recvTransport?.id ?? "")
           if let stats = transportStats {
               self.delegateBackToManager?.sendClientNetworkQuality(stats: stats)
           }
       }
   }
    
}


public struct ScoreData: Codable {
    public let type: Int
    public let data: ScoreDataDetails
    public let id: Int
    public let placeholders: Int
    public let nsp: String

    public enum CodingKeys: String, CodingKey {
        case type
        case data
        case id
        case placeholders
        case nsp = "namespace"
    }
}

public struct ScoreDataDetails: Codable {
    public let score: ScoreInfo

    public enum CodingKeys: String, CodingKey {
        case score
    }
}

public struct ScoreInfo: Codable {
    public let consumerId: String
    public let currentLayers: CurrentLayers
    public let eventName: String
    public let mediaType: String
    public let peerId: String
    public let producerPeerId: String
    public let score: ProducerScore
    public let share: Int
    public let timeStamp: Int

    public enum CodingKeys: String, CodingKey {
        case consumerId
        case currentLayers
        case eventName
        case mediaType
        case peerId
        case producerPeerId
        case score
        case share
        case timeStamp
    }
}

public struct CurrentLayers: Codable {
    public let spatialLayer: Int
    public let temporalLayer: Int

    public enum CodingKeys: String, CodingKey {
        case spatialLayer
        case temporalLayer
    }
}

public struct ProducerScore: Codable {
    public let producerScore: Int
    public let producerScores: [Int]
    public let score: Int

    public enum CodingKeys: String, CodingKey {
        case producerScore
        case producerScores
        case score
    }
}

struct LayersChangeData: Codable {
    let type: String
    let data: LayersChangeDetails
}

struct LayersChangeDetails: Codable {
    let eventName: String
    let peerId: String
    let producerPeerId: String
    let eventEmitterPeerId: String
    let consumerId: String
    let mediaType: String
    let share: Bool
    let layers: Layers
    let score: Score
    let timeStamp: Int
}

struct Layers: Codable {
    let spatialLayer: Int
    let temporalLayer: Int
}

struct Score: Codable {
    let producerScore: Int
    let producerScores: [Int]
    let score: Int
}
