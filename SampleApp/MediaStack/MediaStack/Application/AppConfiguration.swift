//
//  AppConfiguration.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 07/02/23.
//

import Foundation


let appIdentifier = Bundle.main.bundleIdentifier!
class AppConfiguration {
    static let shared: AppConfiguration = AppConfiguration()
    
    var baseUrl: String  {
        get {
            switch globalServerPoint{
            case .Prod:
                return "https://meeting-controller.jiomeet.com/"
            case .RC:
                return "https://rc-meeting-controller.jiomeet.com/"
            case .Prestage:
                return "https://mediaengine-demo.jiomeetcloud.com/"
            }
        }
    }
}
