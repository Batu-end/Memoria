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
    
    var totalBoughtQuantity: Double {
        executions.filter { $0.type == .buy }.reduce(0) { $0 + $1.quantity }
    }
    
    var totalSoldQuantity: Double {
        executions.filter { $0.type == .sell }.reduce(0) { $0 + $1.quantity }
    }
    
    var effectiveQuantity: Double {
        let multiQty = totalBoughtQuantity - totalSoldQuantity
        return multiQty > 0 ? multiQty : (quantity ?? 0)
    }
    
    /// True Average Entry (VWAP) based on all buy executions
    var vwap: Double? {
        let buys = executions.filter { $0.type == .buy }
        guard !buys.isEmpty else { return entryPrice } // Fallback to manual entry for migration
        
        let totalCost = buys.reduce(0) { $0 + ($1.price * $1.quantity) }
        let totalQty = buys.reduce(0) { $0 + $1.quantity }
        return totalQty > 0 ? totalCost / totalQty : entryPrice
    }
    
    // MARK: - Computed Financials
    
    /// Profit or Loss in dollars, accounting for quantity and side.
    /// Prefers multi-execution data if available.
    /// Sum of all profit/loss fixed from partial sales.
    var realizedPnl: Double {
        let currentVwap = vwap ?? 0
        let direction: Double = (side == .short) ? -1.0 : 1.0
        let sells = executions.filter { $0.type == .sell }
        return sells.reduce(0) { $0 + (($1.price - currentVwap) * $1.quantity * direction) }
    }
    
    /// Total Profit/Loss (Realized + Unrealized).
    /// If trade is open, exitPrice acts as the current market price for unrealized calculations.
    var pnl: Double? {
        let currentVwap = vwap ?? 0
        let direction: Double = (side == .short) ? -1.0 : 1.0
        
        let realized = realizedPnl
        
        // If we have an exitPrice (either final exit or last market price), calc unrealized
        guard let exit = exitPrice else { 
            return realized != 0 ? realized : nil 
        }
        
        let unrealized = (exit - currentVwap) * effectiveQuantity * direction
        return realized + unrealized
    }
    
    var percentReturn: Double? {
        guard let entry = vwap, let currentPnl = pnl, entry != 0 else { return nil }
        // We calculate return relative to the TOTAL capital invested across all buys
        let totalCostBasis = executions.filter { $0.type == .buy }.reduce(0) { $0 + ($1.price * $1.quantity) }
        guard totalCostBasis > 0 else { return nil }
        return (currentPnl / totalCostBasis) * 100.0
    }
    
    var rMultiple: Double? {
        guard let entry = vwap, let sl = stopLoss else { return percentReturn }
        let riskPerShare = abs(entry - sl)
        guard riskPerShare > 0 else { return nil }
        
        // Original risk = riskPerShare * originalQuantity
        let originalQty = executions.filter { $0.type == .buy }.reduce(0) { $0 + $1.quantity }
        let originalRisk = riskPerShare * originalQty
        
        guard let currentPnl = pnl, originalRisk > 0 else { return nil }
        return currentPnl / originalRisk
    }

    
    /// Risk-to-Reward ratio based on stop loss and take profit targets.
    /// E.g., "1:3" means risking 1 to make 3.
    var riskRewardRatio: Double? {
        guard let entry = vwap, let sl = stopLoss, let tp = takeProfit else { return nil }
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
        guard let entry = vwap else { return nil }
        return entry * effectiveQuantity
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