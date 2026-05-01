//
//  Portfolio.swift
//  Memoria

import Foundation
import SwiftData

@Model
final class Portfolio {
    var id: UUID
    var name: String
    var sortOrder: Int
    var startingBalance: Double
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Trade.portfolio)
    var trades: [Trade] = []

    @Relationship(deleteRule: .cascade, inverse: \WatchlistItem.portfolio)
    var watchlistItems: [WatchlistItem] = []

    @Relationship(deleteRule: .cascade, inverse: \AccountSnapshot.portfolio)
    var snapshots: [AccountSnapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \CapitalEvent.portfolio)
    var capitalEvents: [CapitalEvent] = []

    init(name: String, startingBalance: Double = 0.0, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.startingBalance = startingBalance
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
