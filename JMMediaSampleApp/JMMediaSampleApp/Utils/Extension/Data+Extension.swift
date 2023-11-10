//
//  Data+Extension.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 14/02/23.
//

import Foundation

extension Data {
    func toString() -> String {
        return String(decoding: self, as: UTF8.self)
    }
}
