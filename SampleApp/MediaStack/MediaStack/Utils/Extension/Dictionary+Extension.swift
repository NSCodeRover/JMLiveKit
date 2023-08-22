//
//  Dictionary+Extension.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 13/02/23.
//

import Foundation

extension Dictionary {
    func toString() -> String {
        let jsonData = try? JSONSerialization.data(withJSONObject: self, options: [])
        return String(data: jsonData!, encoding: .utf8) ?? ""
    }
}
