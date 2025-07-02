//
//  Item.swift
//  AudioApp
//
//  Created by Rushal Butala on 7/2/25.
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
