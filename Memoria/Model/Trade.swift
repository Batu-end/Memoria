import Foundation
import SwiftData

@Model
final class Trade {
    var id: UUID
    var ticker: String
    var dateAdded: Date
    var dateClosed: Date?
    var entryPrice: Double?
    var exitPrice: Double?
    var notes: String?
    var statusRaw: String // "watchlist", "open", "closed"
    
    init(ticker: String, status: TradeStatus = .open) {
        self.id = UUID()
        self.ticker = ticker
        self.dateAdded = Date()
        self.statusRaw = status.rawValue
    }
    
    // Computed property for easy Enum access
    var status: TradeStatus {
        get { TradeStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    
    // MARK: - Computed Financials
    
    /// Profit or Loss in dollars.
    /// Requires both entry and exit price. Defaults to nil if trade is open or data missing.
    /// Currently assumes 1 unit/share for simplicity until Quantity is added.
    var pnl: Double? {
        guard let entry = entryPrice, let exit = exitPrice else { return nil }
        return exit - entry
    }
    
    /// R-Multiple (Return on Risk).
    /// Since we don't have a Stop Loss yet, we will use % Return as a proxy for now.
    /// Formula: (Exit - Entry) / Entry * 100
    var rMultiple: Double? {
        guard let entry = entryPrice, let exit = exitPrice, entry != 0 else { return nil }
        return ((exit - entry) / entry) * 100
    }
}

// Global Enum (Needs to be Codable if part of @Model, but usually RawRepresentable String is easiest for simple storage)
enum TradeStatus: String, CaseIterable, Codable {
    case open = "Open"
    case closed = "Closed"
}