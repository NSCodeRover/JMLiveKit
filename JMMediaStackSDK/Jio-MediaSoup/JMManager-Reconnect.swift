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
    func restartIce(transport: JMMediaTransport) {
        LOG.debug(transport)
        qJMMediaWorkHandler.async {
            do {
                if transport == .send {
                    if let mediaSendTransport = self.sendTransport {
                        var restartData = [String: Any]()
                        restartData["peerId"] = self.selfPeerId
                        restartData["transportType"] = "send"
                        self.restartIce(restartData: restartData)
                    }
                } else {
                    if let mediaReceiveTransport = self.recvTransport {
                        var restartData = [String: Any]()
                        restartData["peerId"] = self.selfPeerId
                        restartData["transportType"] = "receive"
                        self.restartIce(restartData: restartData)
                    }
                }
            } catch {
                print("Error in restart ice")
            }
        }
    }
    
    func restartIce(restartData: [String: Any]?) {
        LOG.debug(restartData?.description)
        jioSocket.emit(
            action: .restartIce, parameters:restartData ?? [:], callback: { [weak self] args in
                guard let self = self else { return }
                if let data = args.first as? [String: Any],
                   let status = data["status"] as? String,
                   status.lowercased() == "ok" {
                    if let responseData = data["data"] as? [String: Any] {
                        self.onRestartIce(restartData: responseData)
                    }
                }
            }
        )
    }
    
    func onRestartIce(restartData: [String: Any]?) {
        LOG.debug(restartData?.description)
        if let iceRestartParameters = restartData?["iceRestartParameters"] as? [[String: Any]],
           let iceData = iceRestartParameters.first,
           let consumeFlag = iceData["consuming"] as? Bool,
           let iceParams = iceData["iceParameters"] as? [String: Any] {
            
            if let jsonString = convertDictionaryToJsonString(dictionary: iceParams) {
                do {
                    consumeFlag ? try self.recvTransport?.restartICE(with: jsonString) : try self.sendTransport?.restartICE(with: jsonString)
                }
                catch{
                    LOG.error("RestartICE- failed: \(consumeFlag) with \(jsonString)")
                }
            }
            else {
                LOG.error("RestartICE- Conversion to JSON string failed.")
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
            LOG.error("RestartICE- Error converting dictionary to JSON string: \(error)")
        }
        return nil
    }
}

//MARK: Socket Reconnect
extension JMManagerViewModel {
    func setupSocketReconnectionHandling() {
        
        if jioSocket.isListenerAddedForReconnect{
            return
        }
        
        jioSocket.isListenerAddedForReconnect = true
        self.jioSocket.getSocket().on(clientEvent: .connect) { data, ack in
            LOG.debug("Socket: reconnected (Join Back)"+data.description)
            self.networkConnectionState = .connected
            self.delegateBackToManager?.sendClientConnectionStateChanged(state: .connected)
            self.handleSocketReconnection()
            self.jioSocket.getManager().config.insert(.connectParams(["peerId": self.selfPeerId]))
        }
        
        self.jioSocket.getSocket().on(clientEvent: .reconnect) { data, ack in
            LOG.debug("Socket: start to Attempting to reconnect process..."+data.description)
            self.delegateBackToManager?.sendClientConnectionStateChanged(state: .connecting)
            self.jioSocket.getManager().config.insert(.connectParams(["peerId": self.selfPeerId]))
            self.networkConnectionState = .reconnecting
        }
        
        self.jioSocket.getSocket().on(clientEvent: .reconnectAttempt) { data, ack in
            LOG.debug("Socket: start to Attempting to reconnect process..."+data.description)
            self.delegateBackToManager?.sendClientConnectionStateChanged(state: .connecting)
            self.networkConnectionState = .reconnecting
        }
        
        self.jioSocket.getSocket().on(clientEvent: .disconnect) { data, ack in
            LOG.debug("Socket: Reconnection attempts failed..(max try failed) "+data.description)
            self.delegateBackToManager?.sendClientConnectionStateChanged(state: .disconnected)
            self.networkConnectionState = .disconnected
        }
    }
    
    func handleSocketReconnection(){
        restartIce(transport: .receive)
        restartIce(transport: .send)
    }
}
