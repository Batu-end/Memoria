import Foundation

/// A lightweight container for individual trade accounting stats.
struct TradeAccounting {
    var tradeId: UUID
    var vwap: Double?
    var realizedPnl: Double = 0
    var unrealizedPnl: Double = 0
    var totalPnl: Double?
    var percentReturn: Double?
    var effectiveQuantity: Double = 0
    var positionSize: Double?
    var rMultiple: Double?
    var riskRewardRatio: Double?
    var winStatus: Bool = false
    var entryPrice: Double?
    var exitPrice: Double?
}
