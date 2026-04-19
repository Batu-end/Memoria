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
    
    // MARK: - Computed Financials
    
    /// Profit or Loss in dollars, accounting for quantity and side.
    var pnl: Double? {
        guard let entry = entryPrice, let exit = exitPrice else { return nil }
        let qty = quantity ?? 1.0
        let direction: Double = (side == .short) ? -1.0 : 1.0
        return (exit - entry) * qty * direction
    }
    
    /// Percentage return: (exit - entry) / entry * 100, adjusted for side.
    var percentReturn: Double? {
        guard let entry = entryPrice, let exit = exitPrice, entry != 0 else { return nil }
        let direction: Double = (side == .short) ? -1.0 : 1.0
        return ((exit - entry) / entry) * 100.0 * direction
    }
    
    /// R-Multiple: how many "R" (units of risk) the trade returned.
    /// R = (P&L) / (Risk per share * Quantity)
    /// Falls back to percentReturn if no stop loss is set.
    var rMultiple: Double? {
        guard let entry = entryPrice, let sl = stopLoss else { return percentReturn }
        let riskPerShare = abs(entry - sl)
        guard riskPerShare > 0 else { return nil }
        guard let realizedPnl = pnl else { return nil }
        let qty = quantity ?? 1.0
        return realizedPnl / (riskPerShare * qty)
    }
    
    /// Risk-to-Reward ratio based on stop loss and take profit targets.
    /// E.g., "1:3" means risking 1 to make 3.
    var riskRewardRatio: Double? {
        guard let entry = entryPrice, let sl = stopLoss, let tp = takeProfit else { return nil }
        let risk = abs(entry - sl)
        let reward = abs(tp - entry)
        guard risk > 0 else { return nil }
        return reward / risk
    }
    
    var isWin: Bool {
        guard let p = pnl else { return false }
        return p > 0
    }
    
    /// Number of calendar days the trade was held.
    var holdingDays: Int? {
        guard let closed = dateClosed else { return nil }
        return Calendar.current.dateComponents([.day], from: dateAdded, to: closed).day
    }
    
    /// Total position size in dollars.
    var positionSize: Double? {
        guard let entry = entryPrice else { return nil }
        return entry * (quantity ?? 1.0)
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