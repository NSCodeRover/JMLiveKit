//
//  JMRTCLogger.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 04/10/23.
//

import Foundation
import WebRTC

public class JMLoggerOption {
    public static let shared = JMLoggerOption()
    
    private var logFileURL: URL
    private var fileHandle: FileHandle
    private let queue = DispatchQueue(label: "com.jmedia.webrtc.logQueue")
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logFileURL = documentsDirectory.appendingPathComponent("JMMediaStack-WEBRTC.log")
        
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        self.fileHandle = try! FileHandle(forWritingTo: logFileURL)
    }
    
    public func setLogFileName(fileName:String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logFileURL = documentsDirectory.appendingPathComponent("\(fileName).log")
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        self.fileHandle = try! FileHandle(forWritingTo: logFileURL)
    }
    
    public  func log(_ message: String) {
        queue.async {
            if let data = message.data(using: .utf8) {
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

