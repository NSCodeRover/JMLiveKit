//
//  AppConfiguration.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 07/02/23.
//

import Foundation

enum AppEnvironment {
    case production
    case rc
    case prestage
}

let appIdentifier = Bundle.main.bundleIdentifier!
class AppConfiguration {
    static let shared: AppConfiguration = AppConfiguration()
    
    var baseUrl: String  {
        get {
            #if PROD
                return "https://meeting-controller.jiomeet.com/"
            #elseif RC
                return "https://rc-meeting-controller.jiomeet.com/"
            #else
                return "https://mediaengine-demo.jiomeetcloud.com/"
            #endif
        }
    }
    
    var environment: AppEnvironment  {
        get {
            #if PROD
                return .production
            #elseif RC
                return .rc
            #else
                return .prestage
            #endif
        }
    }
    
}
