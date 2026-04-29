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
    var sortOrder: Int = 0
    var notes: String?
    var priceAtAdd: Double?       // Reference price when first added
    
    // Live quote data (updated periodically)
    var currentPrice: Double?
    var priceChange: Double?
    var priceChangePercent: Double?
    var volume: Int?
    var marketCap: Double?
    var lastUpdated: Date?
    
    var portfolio: Portfolio?

    init(ticker: String, priceAtAdd: Double? = nil, notes: String? = nil) {
        self.id = UUID()
        self.ticker = ticker.uppercased()
        self.dateAdded = Date()
        self.priceAtAdd = priceAtAdd
        self.notes = notes
    }
    
    /// Updates this item with fresh quote data
    func updateQuote(_ quote: StockQuote) {
        self.currentPrice = quote.currentPrice
        self.priceChange = quote.change
        self.priceChangePercent = quote.changePercent
        self.volume = quote.volume
        self.marketCap = quote.marketCap
        self.lastUpdated = Date()
        
        // If no reference price was set, use the first fetched price
        if self.priceAtAdd == nil {
            self.priceAtAdd = quote.currentPrice
        }
    }
    
    /// Change since the item was added to the watchlist
    var changeSinceAdded: Double? {
        guard let current = currentPrice, let added = priceAtAdd, added > 0 else { return nil }
        return ((current - added) / added) * 100
    }
}
