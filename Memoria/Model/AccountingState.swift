import Foundation

/// A lightweight container for portfolio-level accounting stats.
struct AccountingState {
    var netLiquidity: Double = 0
    var unrealizedPnl: Double = 0
    var unrealizedReturn: Double = 0
    var totalExposure: Double = 0
    var totalPnl: Double = 0
    var winCount: Int = 0
    var lossCount: Int = 0
    var winRate: Double = 0
    var profitFactor: Double = 0
    var avgWin: Double = 0
    var avgLoss: Double = 0
    var maxDrawdown: Double = 0
    var equityCurve: [EquityDataPoint] = []
    var openTradesCount: Int = 0
    var closedTradesCount: Int = 0
    
    static let empty = AccountingState()
}
