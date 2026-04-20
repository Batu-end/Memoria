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
    var quantity: Double?
    var notes: String?
    var statusRaw: String       // "Open", "Closed"
    var sideRaw: String?        // "Long", "Short"
    var stopLoss: Double?
    var takeProfit: Double?
    var strategy: String?       // "Breakout", "Momentum", etc.
    var assetTypeRaw: String?   // "Stock", "ETF" (expandable to "Option", "Crypto" later)
    var attachmentId: String?   // UUID representing the local OS file mapping
    var rulesFollowed: [String] = []  // Tracking strategy discipline
    var confidenceScore: Int = 0      // 1-5 rating of trade conviction
    
    @Relationship(deleteRule: .cascade, inverse: \Execution.trade)
    var executions: [Execution] = []
    
    init(ticker: String, status: TradeStatus = .open, side: TradeSide = .long, assetType: AssetType = .stock) {
        self.id = UUID()
        self.ticker = ticker
        self.dateAdded = Date()
        self.statusRaw = status.rawValue
        self.sideRaw = side.rawValue
        self.assetTypeRaw = assetType.rawValue
    }
    
    // MARK: - Enum Accessors
    // SwiftData can't store enums directly in predicates, so we store raw strings
    // and expose computed properties for type-safe access.
    
    var status: TradeStatus {
        get { TradeStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    
    var side: TradeSide {
        get { TradeSide(rawValue: sideRaw ?? "Long") ?? .long }
        set { sideRaw = newValue.rawValue }
    }
    
    var assetType: AssetType {
        get { AssetType(rawValue: assetTypeRaw ?? "Stock") ?? .stock }
        set { assetTypeRaw = newValue.rawValue }
    }
    
    // MARK: - Multi-Execution Helpers
    
    /// Returns the latest accounting snapshot for this trade from the background engine.
    var math: TradeAccounting? {
        AccountingEngine.shared.tradeAccounting[self.id]
    }
    
    var isWin: Bool {
        (math?.totalPnl ?? 0) > 0
    }
    
    var holdingDays: Int? {
        guard let closed = dateClosed else { return nil }
        return Calendar.current.dateComponents([.day], from: dateAdded, to: closed).day
    }
    
    var riskRewardRatio: Double? {
        guard let entry = entryPrice ?? math?.vwap,
              let sl = stopLoss,
              let tp = takeProfit else { return nil }
        let risk = abs(entry - sl)
        let reward = abs(tp - entry)
        return (risk > 0) ? (reward / risk) : nil
    }
}

// MARK: - Enums

enum TradeStatus: String, CaseIterable, Codable {
    case open = "Open"
    case closed = "Closed"
}

enum TradeSide: String, CaseIterable, Codable {
    case long = "Long"
    case short = "Short"
}

enum AssetType: String, CaseIterable, Codable {
    case stock = "Stock"
    case etf = "ETF"
}

/// Preset strategies. Users can also enter custom strings.
enum TradeStrategy: String, CaseIterable {
    case breakout = "Breakout"
    case momentum = "Momentum"
    case scalp = "Scalp"
    case swing = "Swing"
    case earnings = "Earnings"
    case reversal = "Reversal"
    case dip = "Buy the Dip"
    case other = "Other"
}