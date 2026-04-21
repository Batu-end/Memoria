import Foundation

struct EquityDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double
    var isTrade: Bool = false
    var isWin: Bool? = nil
    var ticker: String? = nil
}

/// A lightweight container for individual trade accounting stats.
struct TradeAccounting {
    var tradeId: UUID
    var vwap: Double?
    var effectiveQuantity: Double = 0
    var realizedPnl: Double?
    var unrealizedPnl: Double = 0
    var totalPnl: Double?
    var percentReturn: Double?
    var positionSize: Double = 0
    var winStatus: Bool = false
    var rMultiple: Double?
}
