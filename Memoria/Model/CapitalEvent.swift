//
//  CapitalEvent.swift
//  Memoria

import Foundation
import SwiftData

@Model
final class CapitalEvent {
    var id: UUID
    var date: Date
    var amount: Double      // positive = deposit, negative = withdrawal
    var portfolio: Portfolio?

    init(amount: Double, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.amount = amount
    }
}
