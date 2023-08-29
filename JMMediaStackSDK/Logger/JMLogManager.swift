//
//  Logger.swift
//  JMMediaStackSDK
//
//  Created by Harsh1 Surati on 27/07/23.
//

import Foundation
import SwiftyBeaver

@objc public class JMLogManager: NSObject{
    @objc public static let shared = JMLogManager()
    
    var isEnabled: Bool = false
    var logPath: URL!
    
    private override init(){}
    internal func setupLogger(){
        let console = ConsoleDestination()
        LOG.addDestination(console)
    }
    
    func enableLogger(_ isEnable: Bool, withPath path: String = "") -> String{
        
        if !isEnable{
            if isEnabled{
                clearLogs()
            }
            
            isEnabled = isEnable
            return ""
        }
        
        isEnabled = true
        if path != "", let logPathUrl = URL(string: path){
            logPath = logPathUrl
        }
        else{
            if let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                logPath = url.appendingPathComponent("JMMediaStack.log", isDirectory: false)
            }
            else{
                LOG.error("LOG- failed to find any path - \(logPath)")
                return ""
            }
        }
        
        let file = FileDestination(logFileURL: logPath)
        LOG.addDestination(file)
        return logPath.absoluteString
    }
    
    func clearLogs(){
        if logPath != nil {
            do{
                try FileManager.default.removeItem(at: logPath)
            }
            catch(let error){
                LOG.error("LOG- failed to delete the file at path - \(logPath)")
            }
        }
    }
}
