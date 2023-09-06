
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

class JioSocketProperty {
    
    static func getProducerProperty(with producerId: String) -> [String: Any] {
        return [
            "producerId": producerId
        ]
    }
    static func getConsumerProperty(with consumerId: String) -> [String: Any] {
        return [
            "consumerId": consumerId
        ]
    }
        
    static func getClosePeerLeaveProperty(peerId: String) -> [String: Any] {
        return [
            "peerId": peerId
        ]
    }
    
    static func getTransportProperty(with transportId: String, dtlsParameters: String) -> [String: Any] {
        return [
            SocketDataKey.transportId.rawValue: transportId,
            SocketDataKey.dtlsParameters.rawValue: dtlsParameters.toDic()
        ]
    }
    
    static func getTransportProduceProperty(with transportId: String, kind: String, rtpParameters: String) -> [String: Any] {
        return [
            SocketDataKey.transportId.rawValue: transportId,
            SocketDataKey.kind.rawValue: kind,
            SocketDataKey.rtpParameters.rawValue: rtpParameters.toDic()
        ]
    }
    
    //Priority
    static func createPreferredPriorityObject(for consumerId: String, priority: Int) -> [String: Any] {
        var consumerObject: [String: Any] = [:]
        consumerObject["consumerId"] = consumerId
        consumerObject["priority"] = priority
        return consumerObject
    }
    
    static func getPreferredPriorityProperty(consumerObjects: [[String:Any]]) -> [String: Any] {
        return [
            "consumers": consumerObjects
        ]
    }
    
    static func getPreferredLayerProperty(consumerId: String, spatialLayer: Int, temporalLayer: Int) -> [String: Any] {
        var consumerObject: [String: Any] = [:]
        consumerObject["consumerId"] = consumerId
        consumerObject["spatialLayer"] = spatialLayer
        consumerObject["temporalLayer"] = temporalLayer
        
        return consumerObject
    }
}

struct SocketUtil {
    public static func getSocketKey() -> Int {
        var randomString = ""
        for _ in stride(from: 1, to: 8, by: 1) {
            let val = max(1, arc4random() % 9)
            randomString = "\(randomString)\(val)"
        }
        return Int(randomString) ?? 0
    }
 
    public static func deviceInfo()->[String:Any]{
        let name = "test"//UIDevice.current.name
        let flag = UIDevice.current.systemName
        let version = UIDevice.current.systemVersion
        return ["name":name,"flag":flag,"version":version]
    }
}

extension String {
    func toDic()->[String:Any]{
        if self.count == 0{return[:]}
        let data = self.data(using: String.Encoding.utf8)
        var tempDic:[String:Any] = [:]
        if let dict = try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any] {
            tempDic = dict
        }
        if !tempDic.isEmpty{return tempDic}
        
        guard let dic = try? JSONSerialization.jsonObject(with: self.data(using: .utf8)!, options: .allowFragments) as? [String:Any] ?? [:] else {
            let beginStr = "\"{"
            let endStr = "}\""
            let str = self
            if str.hasPrefix(beginStr) && str.hasSuffix(endStr){
               let subStr = str.getSubString(startIndex: 1, endIndex: str.count-2)
                guard let vDic = try? JSONSerialization.jsonObject(with: subStr.data(using: .utf8)!, options: .allowFragments) as? [String:Any] ?? [:] else {
                    return [:]
                }
                return vDic
            }
            
            return [:]
        }
        return dic
    }
    
    func getSubString(startIndex:Int, endIndex:Int) -> String {
        var endInt = endIndex
        if self.count < endInt{
            endInt = self.count
        }
        let start = self.index(self.startIndex, offsetBy: startIndex)
        let end = self.index(self.startIndex, offsetBy: endInt)
        return String(self[start...end])
    }
    
    func intValue()->Int{
        if self.count == 0{return 0}
        if let num = NumberFormatter().number(from: self) {
            return num.intValue
        } else {
            return 0
        }
    }
    
}

extension Dictionary {
    
    func toString() -> String {
        let jsonData = try? JSONSerialization.data(withJSONObject: self, options: [])
        return String(data: jsonData!, encoding: .utf8) ?? ""
    }
    
    func strValue(_ key:Key)->String{
        if let val = self[key] as? String {return val}
        if let val2 = self[key] as? Int {return "\(val2)"}
        if let val3 = self[key] as? Double {return "\(val3)"}
        if let val4 = self[key] as? CGFloat {return "\(val4)"}
        if let val5 = self[key] as? Float {return "\(val5)"}
        return ""
    }
    
    func intValue(_ key:Key)->Int{
        if let va = self[key]{
            return "\(va)".intValue()
        }
        return 0
    }
    
    func intValue(_ key:Key,replace:Int)->Int{
        if let va = self[key]{
            return "\(va)".intValue()
        }
        return replace
    }
    
    func dictionary(_ key:Key)->[String:Any]{
        let dic = self[key] as? [String:Any] ?? [:]
        return dic
    }
    
    func array(_ key:Key)->[[String:Any]]{
        let array = self[key] as? [[String:Any]] ?? []
        return array
    }
}

func parse<T: Codable>(json: [String: Any], model: T.Type) -> T? {
    do {
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        let decoder = JSONDecoder()
        let model = try? decoder.decode(model.self, from: data)
        return model
    } catch {
        print(error.localizedDescription)
    }
    return nil
}
