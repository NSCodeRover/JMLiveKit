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
    private override init(){}
    internal func setupLogger(){
        if let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let path = url.appendingPathComponent("JMMediaStack.log", isDirectory: false)
            print(path) //This is the path where log is saved. Paste in finder to find the file.
            let file = FileDestination(logFileURL: path)
            LOG.addDestination(file)
        }
        else{
            let file = FileDestination()
            LOG.addDestination(file)
        }
        let console = ConsoleDestination()
        LOG.addDestination(console)
    }
}
