//
//  JMRTCLogger.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 04/10/23.
//

import Foundation
import WebRTC

public class JMRTCLogger {
   public static let shared = JMRTCLogger()
    
    private var logFileURL: URL
    private var fileHandle: FileHandle
    private let queue = DispatchQueue(label: "com.jmedia.webrtc.logQueue")
    
    let webrtcLogger = RTCCallbackLogger()
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logFileURL = documentsDirectory.appendingPathComponent("JMMediaStack-WEBRTC.log")
        
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        self.fileHandle = try! FileHandle(forWritingTo: logFileURL)
    }
    
    func setLogFileName(fileName:String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logFileURL = documentsDirectory.appendingPathComponent("\(fileName).log")
        
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        self.fileHandle = try! FileHandle(forWritingTo: logFileURL)
    }
    
    func enableWebRTCLogs(isEnabled:Bool = true,severity: RTCLoggingSeverity = .info,fileName:String = "", completionHandler: @escaping (String) -> Void) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logFileURL = documentsDirectory.appendingPathComponent("JMMediaStack-WEBRTC-\(fileName).log")
        
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        self.fileHandle = try! FileHandle(forWritingTo: logFileURL)
        webrtcLogger.severity = severity
        if isEnabled {
            webrtcLogger.stop()
            webrtcLogger.start { (message) in
                // Inside the log callback, pass the message to the completionHandler
                completionHandler("[webrtc] 💙" + message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }else{
            completionHandler("Log Disabled")
            webrtcLogger.stop()
        }
    }
    
public  func log(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let formattedDate = dateFormatter.string(from: Date())
        
        let logEntry = "[\(formattedDate)] \(message)\n"
        
        queue.async {
            if let data = logEntry.data(using: .utf8) {
                self.fileHandle.write(data)
            }
        }
    }
    
    deinit {
        queue.sync {
            fileHandle.closeFile()
        }
    }
}

