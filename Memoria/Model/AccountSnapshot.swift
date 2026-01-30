//
//  AccountSnapshot.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import Foundation
import SwiftData

@Model
final class AccountSnapshot {
    var id: UUID
    var date: Date
    var totalEquity: Double
    var cashBalance: Double
    var unrealizedPL: Double
    
    init(totalEquity: Double, cashBalance: Double = 0.0, unrealizedPL: Double = 0.0, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.totalEquity = totalEquity
        self.cashBalance = cashBalance
        self.unrealizedPL = unrealizedPL
    }
}
