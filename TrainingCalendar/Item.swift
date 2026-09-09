//
//  Item.swift
//  TrainingCalendar
//
//  Created by Duc Pham on 8/9/26.
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
