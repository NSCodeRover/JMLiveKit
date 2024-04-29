
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
    public var consumerScreenShareAudio: Consumer?
    var consumerQueue: [JMMediaType:Bool] = [:]
    
    public var producers: [PeerProducer]
    public var isAudioEnabled: Bool = false
    public var isVideoEnabled: Bool = false
    public var isScreenShareEnabled: Bool = false
    
    var preferredFeed: JMMediaQuality = .medium
    
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
        self.consumerScreenShareAudio = nil
        self.producers = []
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        peerId = try values.decodeIfPresent(String.self, forKey: .peerId) ?? ""
        displayName = try values.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        consumerAudio = nil
        consumerVideo = nil
        consumerScreenShare = nil
        consumerScreenShareAudio = nil
        producers = try values.decodeIfPresent([PeerProducer].self, forKey: .producers) ?? []
        
        for producer in producers{
            let isEnable = !producer.paused
            
            switch producer.mediaType{
            case .audio:
                isAudioEnabled = isEnable
            case .video:
                isVideoEnabled = isEnable
            case .shareScreen:
                isScreenShareEnabled = isEnable
            default:break
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {}
    
    func getProducerId(for mediaType: JMMediaType) -> String?{
        if let objectPresent = producers.first(where: { $0.mediaType == mediaType }) {
            return objectPresent.producerId
        }
        return nil
    }
    
    func isProducerPaused(for mediaType: JMMediaType) -> Bool{
        if let objectPresent = producers.first(where: { $0.mediaType == mediaType }) {
            return objectPresent.paused
        }
        return true
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
        case .shareScreenAudio:
            consumerObject = consumerScreenShareAudio
        }
        return consumerObject
    }
    
    func isResumed(for mediaType: JMMediaType) -> Bool{
        switch mediaType{
        case .audio:
            return isAudioEnabled
        case .video:
            return isVideoEnabled
        case .shareScreen:
            return isScreenShareEnabled
        default:return false
        }
    }
}

public struct PeerProducer: Codable {
    public var mediaType: JMMediaType
    public var producerId: String
    public var share: Bool
    public var paused: Bool

    enum CodingKeys: String, CodingKey {
        case mediaType
        case producerId
        case share
        case paused
    }
    
    init(mediaType: JMMediaType,producerId:String,paused:Bool){
        self.mediaType = mediaType
        self.producerId = producerId
        self.share = mediaType == .shareScreen ? true : false
        self.paused = paused
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        producerId = try values.decodeIfPresent(String.self, forKey: .producerId) ?? ""
        share = try values.decodeIfPresent(Bool.self, forKey: .share) ?? false
        paused = try values.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        
        let serverMediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)?.lowercased() ?? ""
        if serverMediaType == "video" && share{
            mediaType = .shareScreen
        }
        else if serverMediaType == "video"{
            mediaType = .video
        }
        else if serverMediaType == "audio"{
            mediaType = .audio
        }
        else{
            mediaType = .audio
            LOG.error("Data- Set audio Producer \(producerId) \(share) \(values)")
        }
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
