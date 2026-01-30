//
//  ActivityLog.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import Foundation
import SwiftData

@Model
final class ActivityLog {
    var id: UUID
    var date: Date
    var actionType: String // e.g. "Trade", "System", "Note"
    var title: String
    var details: String?
    
    init(title: String, actionType: String = "System", details: String? = nil, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.actionType = actionType
        self.details = details
    }
}
