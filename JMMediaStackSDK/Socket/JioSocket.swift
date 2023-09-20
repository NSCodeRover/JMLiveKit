
import Foundation
import SocketIO

enum SocketEvent: String,CaseIterable {
    //SELF
    case connect
    case peerConnected
    case disconnect
    case reconnect
    case reconnectAttempt
    
    case socketConnected
    case socketReconnected
    
    //TOP speakers
    case audioLevel
    
    //Remote users
    case newPeer
    case peerClosed
    
    //Remote Producer, we will consume.
    case newProducer
    case producerEnd
    case pausedProducer
    case resumedProducer
    
    //RTM
    case broadcastMessage
    case broadcastMessageToPeer
    
    //EXTRA
    case botsJoined
    case botsLeft
    case score
    case layerschange
    case userRoleUpdated
}

enum SocketEmitAction: String {
    //SELF
    case join
    case connectWebRtcTransport
    case peerLeave
        
    //Remote
    case consume
    case resumeConsumer
    case pauseConsumer
    
    case setConsumerPreferredLayers
    case setConsumersPreferedLayersNPriorities
    
    //SELF
    case produce
    case closeProducer
    case pauseProducer
    case resumeProducer
    
    case getTransportStats
    case restartIce
    
    //RTM
    case broadcastMessage
    case broadcastMessageToPeer
}

protocol JioSocketDelegate: NSObject {
    func didConnectionStateChange(_ state: JMSocketConnectionState)
    func didReceive(event: SocketEvent, data: [Any], ack: SocketAckEmitter?)
    func didEmit(event: SocketEmitAction, data: [Any])
}

class JioSocket : NSObject {
    private var socketIp = ""
    private var roomId = ""
    private var jwtToken = ""
    
    private var manager:SocketManager?
    private var socket: SocketIOClient!
    
    var selfPeerId: String = ""
    
    private enum SocketKey: String {
        case roomId
        case token
        case oldPeerId
    }
    
    private weak var delegate: JioSocketDelegate?
    private var socketEvents: [SocketEvent] = []
    
    func connect(socketUrl: String, roomId: String, jwtToken: String, ip: String, delegate: JioSocketDelegate?, socketEvents: [SocketEvent], isRejoin: Bool) {
        if let url = URL.init(string: socketUrl) {
            manager = SocketManager(socketURL: url,config: getSocketConfiguration())
            if let manager = self.manager {
                self.delegate = delegate
                self.socketIp = ip
                self.roomId = roomId
                self.jwtToken = jwtToken
                self.socketEvents = socketEvents
                socket = manager.defaultSocket
                self.addSocketListener()
                socket.connect(withPayload: getPayload(roomId: roomId, jwtToken: jwtToken, isRejoin: isRejoin))
            }
        }
    }
    
    func disconnectSocket() {
        manager?.disconnect()
        socket.disconnect()
        manager = nil
        socket = nil
    }
    
    func getReconnect(){
        manager?.reconnect()
    }
    
    func getSocketIp() -> String {
        return self.socketIp
    }
    
    func getSocket() -> SocketIOClient {
        return self.socket
    }
    
    func getManager() -> SocketManager {
        return self.manager!
    }
    
    func updateConfig(_ selfID: String){
        selfPeerId = selfID
        getManager().config.insert(.connectParams(["peerId": selfID]))
    }

    func emit(action: SocketEmitAction, parameters: [String: Any]) {
        self.socket.emitWithAck(action.rawValue, parameters).timingOut(after: 5) {[weak self] data in
            
            if let json = self?.getJson(data: data), let status = json["status"] as? String{
                if status.lowercased() != "ok"{
                    LOG.debug("Socket- Ack- Event-\(action.rawValue) Status:\(status) error: \(json["error"])")
                }
            }
            
            if var outerDictionary = parameters as? [String: Any],let innerDictionary = outerDictionary["appData"] as? [String: Any],let shareValue = innerDictionary["share"] as? Bool, shareValue {
                //Screenshare producer ID workaround.
                var datashare = self?.getJson(data: data)
                datashare?["share"] = true
                self?.delegate?.didEmit(event: action, data: [datashare])
            }
            else {
                self?.delegate?.didEmit(event: action, data: data)
            }
        }
    }
    
    func emit(action: SocketEmitAction, parameters: [String: Any],callback: (([Any])->())?) {
        self.socket.emitWithAck(action.rawValue, parameters).timingOut(after: 5) { data in
            callback?(data)
        }
    }
    func emit(ack: Int, parameters: [String]) {
        self.socket.emitAck(ack, with: parameters)
    }
    
    func getJson(data: [Any]) -> [String: Any]? {
        if data.count > 0 {
            if let json = data[0] as? [String: Any] {
                return json
            }
        }
        return nil
    }
}


// MARK: - Private Methods
extension JioSocket {
    private func getSocketConfiguration() -> SocketIOClientConfiguration {
        return [
            .log(false),
            .compress,
            .path("/socket.io/"),
            
            .forceNew(false),
            .reconnects(true),    // Enable reconnection attempts
            .reconnectAttempts(10), // Set the number of reconnection attempts
            .reconnectWait(1),
            .reconnectWaitMax(2) //After 2 secs, it will attempt to reconnect //Ping pong takes 8 seconds to detect network loss. Total = 20sec.
        ]
    }
    
    private func getPayload(roomId: String, jwtToken: String, isRejoin: Bool) -> [String: Any] {
        if isRejoin {
            return [
                SocketKey.oldPeerId.rawValue : selfPeerId,
                SocketKey.roomId.rawValue: roomId,
                SocketKey.token.rawValue: jwtToken
            ]
        }
        return [
            SocketKey.roomId.rawValue: roomId,
            SocketKey.token.rawValue: jwtToken
        ]
    }
    
    private func addSocketListener() {
        for event in socketEvents {
            if event == .connect {
                socket.on(clientEvent: .connect) { data, ack in
                    self.delegate?.didConnectionStateChange(.connected)
                    self.delegate?.didReceive(event: event, data: data, ack: ack)
                }
            }
            else if event == .disconnect {
                socket.on(clientEvent: .disconnect) { data, ack in
                    self.delegate?.didConnectionStateChange(.disconnected)
                    self.delegate?.didReceive(event: event, data: data, ack: ack)
                }
            }
            else if event == .reconnect  {
                socket.on(clientEvent: .reconnect) {data, ack in
                    LOG.debug("Reconnect- reconnected | \(data.description)")
                    self.delegate?.didConnectionStateChange(.connected)
                }
            }
            else if event == .reconnectAttempt  {
                socket.on(clientEvent: .reconnectAttempt) { data, ack in
                    LOG.debug("Reconnect- reconnectAttempting... | \(data.description)")
                    self.delegate?.didConnectionStateChange(.reconnecting)
                }
            }
            else {
                socket.on(event.rawValue) { data, ack in
                    self.delegate?.didReceive(event: event, data: data, ack: ack)
                }
            }
        }
    }
}
