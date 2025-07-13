//
//  Item.swift
//  VirtualHub
//
//  Created by 진수민 on 7/13/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
