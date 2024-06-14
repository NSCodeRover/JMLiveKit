//
//  Logger.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 27/07/23.
//
//TODO: Check ARC (memory leaks)

import Foundation
import WebRTC

public enum JMLogSeverity{
    case debug
    case info
    case warning
    case error
}
extension JMLogSeverity{
    func webrtcType() -> RTCLoggingSeverity{
        switch self{
        case .debug: return .verbose
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}

@objc public class JMLogManager: NSObject{
    @objc public static let shared = JMLogManager()
    
    let webrtcLogger = RTCCallbackLogger()
    private let queue = DispatchQueue(label: "com.jmedia.webrtc.logQueue")
    
    static var isEnabled: Bool = false
    static var delegateToManager: delegateManager? = nil
    
    private override init(){}
    
    public func enableLogs(isEnabled:Bool = true, severity: JMLogSeverity = .info, delegate:JMMediaEngine) {
        JMLogManager.delegateToManager = delegate
        JMLogManager.isEnabled = isEnabled
        
        listenToWebrtcLogs(isEnabled, severity: severity)
    }
    
    public class func log(_ message: String)->String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let formattedDate = dateFormatter.string(from: Date())
        return "[\(formattedDate)] \(message)\n"
    }
}

//MARK: WEBRTC LOGS
extension JMLogManager{
    
    func listenToWebrtcLogs(_ isEnabled: Bool, severity: JMLogSeverity){
        let webrtcSeverity = severity.webrtcType()
        webrtcLogger.severity = webrtcSeverity
        
        if isEnabled {
            webrtcLogger.stop()
            webrtcLogger.start { (message) in
                // Inside the log callback, pass the message to the completionHandler
                JMLogManager.delegateToManager?.sendClientLogMsg(log: JMLogManager.log("[webrtc] \(self.getHeart(severity: webrtcSeverity))" + message.trimmingCharacters(in: .whitespacesAndNewlines)))
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
}

//For JMMediaStack, we have enabled all logs/ INFO.
extension JMLogManager {

    /// log something which help during debugging (low priority)
    public class func debug(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💚 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    /// log something which you are really interested but which is not an issue or error (normal priority)
    public class func info(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💙 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }

    /// log something which may cause big trouble soon (high priority)
    public class func warning(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" 💛 \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }
   

    /// log something which will keep you awake at night (highest priority)
    public class func error(_ message: String = "",file: String = #file, function: String = #function, line: Int = #line) {
        if isEnabled {
            self.delegateToManager?.sendClientLogMsg(log: JMLogManager.log(" ❤️ \(URL(fileURLWithPath: file).lastPathComponent) \(function) line: \(line) " + message.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }
}


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
