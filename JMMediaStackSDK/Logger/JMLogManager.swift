//
//  Logger.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 27/07/23.
//

import Foundation
import WebRTC

@objc public class JMLogManager: NSObject{
    @objc public static let shared = JMLogManager()
    
    static var isEnabled: Bool = false
    let webrtcLogger = RTCCallbackLogger()
    static var delegateToManager: delegateManager? = nil
    private let queue = DispatchQueue(label: "com.jmedia.webrtc.logQueue")
    private override init(){}
    internal func setupLogger(){
    }
    
    public func enableLogs(isEnabled:Bool = true,severity: RTCLoggingSeverity = .info) {
        JMLogManager.isEnabled = isEnabled
        webrtcLogger.severity = severity
        if isEnabled {
            webrtcLogger.stop()
            webrtcLogger.start { (message) in
                // Inside the log callback, pass the message to the completionHandler
                JMLogManager.delegateToManager?.sendClientLogMsg(log: JMLogManager.log("[webrtc] \(self.getHeart(severity: severity))" + message.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }else{
            webrtcLogger.stop()
        }
    }
    
    func getHeart(severity:RTCLoggingSeverity)->String {
        switch severity {
        case .error:
            return "❤️"
        case .info:
            return "💙"
        case .verbose:
            return "💜"
        case .warning:
            return "💛"
        default:
            return "💚"
        }
    }
    
    public class func log(_ message: String)->String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let formattedDate = dateFormatter.string(from: Date())
        return "[\(formattedDate)] \(message)\n"
    }
}

extension JMLogManager {
    
    /// log something generally unimportant (lowest priority)
    open class func verbose(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💜 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    /// log something which help during debugging (low priority)
    open class func debug(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💚 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    /// log something which you are really interested but which is not an issue or error (normal priority)
    open class func info(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💙 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    /// log something which may cause big trouble soon (high priority)
    open class func warning(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💛 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }
   

    /// log something which will keep you awake at night (highest priority)
    open class func error(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" ❤️ \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }
}
