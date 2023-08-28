
import Foundation
import Mediasoup
import UIKit

struct Peer: Codable {
    public var peerId: String
    public var displayName: String
    
    public var remoteView: UIView?
    public var remoteScreenshareView: UIView?
    public var consumerAudio: Consumer?
    public var consumerVideo: Consumer?
    public var consumerScreenShare: Consumer?
    
    public var producers: [PeerProducer]
    public var isAudioEnabled: Bool = false
    public var isVideoEnabled: Bool = false
    public var isScreenShareEnabled: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case peerId
        case displayName
        case consumer
        case producers
    }
    
    init() {
        self.peerId = ""
        self.displayName = ""
        self.consumerAudio = nil
        self.consumerVideo = nil
        self.consumerScreenShare = nil
        self.producers = []
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        peerId = try values.decodeIfPresent(String.self, forKey: .peerId) ?? ""
        displayName = try values.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        consumerAudio = nil
        consumerVideo = nil
        consumerScreenShare = nil
        producers = try values.decodeIfPresent([PeerProducer].self, forKey: .producers) ?? []
        
        for producer in producers{
            let jmMediaType: JMMediaType = producer.share ? .shareScreen : producer.mediaType == "video" ? .video : .audio
            let isEnable = !producer.paused
            
            switch jmMediaType{
            case .audio:
                isAudioEnabled = isEnable
            case .video:
                isVideoEnabled = isEnable
            case .shareScreen:
                isScreenShareEnabled = isEnable
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {}
    
    func getProducerId(for mediaType: JMMediaType) -> String?{
        if let objectPresent = producers.first(where: {
            mediaType == .shareScreen ? ($0.mediaType == "video" && $0.share == true) : ($0.mediaType == mediaType.rawValue) }) {
            LOG.warning("Subscribe- get producer id \(objectPresent.producerId)")
            return objectPresent.producerId
        }
        
        LOG.warning("Subscribe- get producer id nil \(mediaType)")
        return nil
    }
    
    func getConsumer(for mediaType: JMMediaType) -> Consumer?{
        var consumerObject: Consumer?
        switch mediaType{
        case .audio:
            consumerObject = consumerAudio
        case .video:
            consumerObject = consumerVideo
        case .shareScreen:
            consumerObject = consumerScreenShare
        }
        return consumerObject
    }
}

public struct PeerProducer: Codable {
    public var mediaType: String
    public var producerId: String
    public var share: Bool
    public var paused: Bool

    enum CodingKeys: String, CodingKey {
        case mediaType
        case producerId
        case share
        case paused
    }
    
    init(mediaType: String,producerId:String,share:Bool,paused:Bool){
        self.mediaType = mediaType
        self.producerId = producerId
        self.share = share
        self.paused = paused
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType) ?? ""
        producerId = try values.decodeIfPresent(String.self, forKey: .producerId) ?? ""
        share = try values.decodeIfPresent(Bool.self, forKey: .share) ?? false
        paused = try values.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {}
}

struct JoinResponse: Codable {
    var data: JoinData?
    enum CodingKeys: String, CodingKey {
        case data
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        data = try values.decodeIfPresent(JoinData.self, forKey: .data) ?? nil
    }
    func encode(to encoder: Encoder) throws {}
}

struct JoinData: Codable {
    var peers: [Peer]
    enum CodingKeys: String, CodingKey {
        case peers
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        peers = try values.decodeIfPresent([Peer].self, forKey: .peers) ?? []
    }
    func encode(to encoder: Encoder) throws {}
}
