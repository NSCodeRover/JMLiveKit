//
//  JMRTCLogger.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 04/10/23.
//

import Foundation
import WebRTC

// Global Signal Handler Function
func globalSignalHandler(_ signal: Int32) {
    let signalDescription = String(describing: Signal(rawValue: signal))
    JMLoggerOption.shared.log("Caught signal: \(signalDescription)")
    exit(EXIT_FAILURE)
}

// Signal Enum for Readable Signal Descriptions
enum Signal: Int32 {
    case SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE

    var description: String {
        switch self {
        case .SIGABRT: return "SIGABRT"
        case .SIGILL: return "SIGILL"
        case .SIGSEGV: return "SIGSEGV"
        case .SIGFPE: return "SIGFPE"
        case .SIGBUS: return "SIGBUS"
        case .SIGPIPE: return "SIGPIPE"
        }
    }
}


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
        setupCrashHandlers()

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
            if let data = "\(message)\n".data(using: .utf8) {
                self.fileHandle.write(data)
            }
        }
    }
    
    private func setupCrashHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            JMLoggerOption.shared.log("Crash: \(exception)")
            JMLoggerOption.shared.log("Stack Trace: \(exception.callStackSymbols)")
        }

        signal(SIGABRT, globalSignalHandler)
        signal(SIGILL, globalSignalHandler)
        signal(SIGSEGV, globalSignalHandler)
        signal(SIGFPE, globalSignalHandler)
        signal(SIGBUS, globalSignalHandler)
        signal(SIGPIPE, globalSignalHandler)
    }

    
    deinit {
        queue.sync {
            fileHandle.closeFile()
        }
    }
}

