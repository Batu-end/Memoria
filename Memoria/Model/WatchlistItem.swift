//
//  WatchlistItem.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import Foundation
import SwiftData

@Model
final class WatchlistItem {
    var id: UUID
    var ticker: String
    var dateAdded: Date
    var notes: String?
    var priceAtAdd: Double? // Optional reference price when added. Dynamic price will be fetched from API later.
    
    init(ticker: String, priceAtAdd: Double? = nil, notes: String? = nil) {
        self.id = UUID()
        self.ticker = ticker
        self.dateAdded = Date()
        self.priceAtAdd = priceAtAdd
        self.notes = notes
    }
}
