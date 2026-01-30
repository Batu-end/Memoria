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
}

// Global Enum (Needs to be Codable if part of @Model, but usually RawRepresentable String is easiest for simple storage)
enum TradeStatus: String, CaseIterable, Codable {
    case open = "Open"
    case closed = "Closed"
}