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
    
    typealias StatsTuple = (quality: Int, packetLoss: Int)
    
    func getTransportStats(statsArray: [[String: Any]], sendTransportId: String, receiveTransportId: String) -> JMNetworkStatistics? {
        
        var mNetworkQuality: Int = 0
        var mUplinkPacketLoss: Int = 0
        var mDownlinkPacketLoss: Int = 0
      
        var uplinkData: StatsTuple? = nil
        var downlinkData: StatsTuple? = nil
        
        for stats in statsArray {
             guard let transportId = stats["transport"] as? String else {
                 continue
             }
             
             if sendTransportId == transportId && uplinkData == nil {
                 uplinkData = qualityAndPacketLoss(isSendTransport: true, stats: (stats["stats"] as? [[String: Any]])?.first ?? [:])
             }
             
             if receiveTransportId == transportId && downlinkData == nil {
                 downlinkData = qualityAndPacketLoss(isSendTransport: false, stats: (stats["stats"] as? [[String: Any]])?.first ?? [:])
             }
        }
        
        if let uplinkData = uplinkData, let downlinkData = downlinkData {
            if uplinkData.quality != 0 && downlinkData.quality != 0 {
                mNetworkQuality = max(uplinkData.quality, downlinkData.quality)
            } else {
                mNetworkQuality = uplinkData.quality > 0 ? uplinkData.quality : downlinkData.quality
            }
            mUplinkPacketLoss = uplinkData.packetLoss
            mDownlinkPacketLoss = downlinkData.packetLoss
        }
        
        //LOG.debug(("Stats- Network quality:" + mNetworkQuality.description + " | uplinkLoss:" ) + (mUplinkPacketLoss.description + " | downlinkLoss:" + mDownlinkPacketLoss.description))
        
        return JMNetworkStatistics(networkQuality: mNetworkQuality,remotePacketPercentLoss: mDownlinkPacketLoss,localPacketPercentLoss: mUplinkPacketLoss)
    }

    private func qualityAndPacketLoss(isSendTransport: Bool, stats: [String: Any]) -> StatsTuple {
        let rtpPacketLoss = isSendTransport ? stats["rtpPacketLossSent"] as? Double ?? 0 : stats["rtpPacketLossReceived"] as? Double ?? 0
        var quality = 0
        var packetLoss = 0

        if !rtpPacketLoss.isNaN {
            packetLoss = Int(rtpPacketLoss * 100)
            // Assign quality based on loss percentage
            if packetLoss <= 1 {
                quality = 1
            }
            else if packetLoss <= 3 {
                quality = 2
            }
            else if packetLoss <= 10 {
                quality = 3
            }
            else if packetLoss <= 15 {
                quality = 4
            }
            else if packetLoss > 15 {
                quality = 5
            }
        }
        return (quality, packetLoss)
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
        data["peerId"] = selfPeerId
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
