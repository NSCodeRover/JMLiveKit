//
//  JMManager-Reconnect.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 08/08/23.
//

import Foundation

import SwiftyJSON
import Mediasoup

//MARK: Transport Reconnect
public enum JMSocketConnectionState: String {
    case connecting = "CONNECTING"
    case connected = "CONNECTED"
    case disconnected = "DISCONNECTED"
    case reconnecting = "RECONNECTING"
    // Add other states as needed
}
enum JMMediaTransport {
    case send
    case receive
}

extension JMManagerViewModel {
    
    func onRestartIce(restartData: [String: Any]) {
        if let iceRestartParameters = restartData["iceRestartParameters"] as? [[String: Any]],
           let iceData = iceRestartParameters.first,
           let consumeFlag = iceData["consuming"] as? Bool,
           let iceParams = iceData["iceParameters"] as? [String: Any] {
            
            if let jsonString = convertDictionaryToJsonString(dictionary: iceParams) {
                do {
                    LOG.info("Reconnect- \(consumeFlag ? "Receive" : "Send") Restart called")
                    consumeFlag ? try self.recvTransport?.restartICE(with: jsonString) : try self.sendTransport?.restartICE(with: jsonString)
                }
                catch{
                    LOG.error("Reconnect- RestartICE- failed: \(consumeFlag) with \(jsonString)")
                }
            }
            else {
                LOG.error("Reconnect- RestartICE- Conversion to JSON string failed. \(iceParams.description)")
            }
        }
    }
    
    func convertDictionaryToJsonString(dictionary: [String: Any]) -> String? {
        LOG.debug(dictionary.description)
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            LOG.error("Reconnect- RestartICE- Error converting dictionary to JSON string: \(error)")
        }
        return nil
    }
}

//MARK: Socket Reconnect
extension JMManagerViewModel{
    func validateTransportAndRestart(){
        if connectionState == .connected{
            if let transport = sendTransport, transport.connectionState == .failed{
                restartIce(transport: "send")
            }
            if let transport = recvTransport, transport.connectionState == .failed{
                restartIce(transport: "receive")
            }
        }
    }
    
    func restartIce(transport: String) {
        var restartData = [String: Any]()
        restartData["peerId"] = self.selfPeerId
        restartData["transportType"] = transport
        self.restartIce(restartData: restartData)
    }
    
    func restartIce(restartData: [String: Any]) {
        LOG.debug("Reconnect- emit restartIce \(restartData.description)")
        jioSocket.emit(action: .restartIce, parameters:restartData)
    }
}
