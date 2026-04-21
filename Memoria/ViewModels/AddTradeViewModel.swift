//
//  AddTradeViewModel.swift
//  Memoria

import Foundation
import SwiftData
import SwiftUI

@Observable
class AddTradeViewModel {

    // MARK: - Core
    var ticker: String = ""
    var side: TradeSide = .long
    var assetType: AssetType = .stock
    var selectedStrategy: TradeStrategy? = nil
    var customStrategy: String = ""
    var confidenceScore: Int = 0
    var notes: String = ""

    // MARK: - Mode
    var isPastTrade: Bool = false
    var useSharesMode: Bool = false

    // MARK: - String-backed numeric fields
    var priceString: String = ""
    var capitalString: String = ""
    var sharesString: String = ""
    var stopLossString: String = ""
    var takeProfitString: String = ""
    var exitPriceString: String = ""

    // MARK: - Past trade dates
    var openDate: Date = Date()
    var closeDate: Date = Date()

    // MARK: - Computed doubles
    var price: Double? { Double(priceString) }
    var capital: Double? { Double(capitalString) }
    var shares: Double? { Double(sharesString) }
    var stopLoss: Double? { Double(stopLossString) }
    var takeProfit: Double? { Double(takeProfitString) }
    var exitPrice: Double? { Double(exitPriceString) }

    var effectiveCapital: Double? {
        if useSharesMode, let s = shares, let p = price, p > 0 { return s * p }
        return capital
    }

    var effectiveShares: Double? {
        if let p = price, p > 0 {
            if useSharesMode { return shares }
            if let c = capital { return c / p }
        }
        return nil
    }

    var riskReward: Double? {
        guard let entry = price, let sl = stopLoss, let tp = takeProfit else { return nil }
        let risk = abs(entry - sl)
        let reward = abs(tp - entry)
        guard risk > 0 else { return nil }
        return reward / risk
    }

    var estimatedPnl: Double? {
        guard let entry = price, let exit = exitPrice,
              let c = effectiveCapital, entry > 0 else { return nil }
        let qty = c / entry
        return (exit - entry) * qty * (side == .long ? 1.0 : -1.0)
    }

    // MARK: - Validation
    var isValidForm: Bool {
        guard !ticker.isEmpty, price != nil else { return false }
        let hasSize = effectiveCapital != nil
        if isPastTrade { return hasSize && exitPrice != nil }
        return hasSize
    }

    // MARK: - Actions
    func addTrade(context: ModelContext) {
        guard let p = price else { return }
        let status: TradeStatus = isPastTrade ? .closed : .open
        let trade = Trade(ticker: ticker.uppercased(), status: status, side: side, assetType: assetType)

        trade.entryPrice = p
        trade.dateAdded = isPastTrade ? openDate : Date()

        if let qty = effectiveShares { trade.quantity = qty }

        trade.stopLoss = stopLoss
        trade.takeProfit = takeProfit
        trade.strategy = resolvedStrategy
        trade.notes = notes.isEmpty ? nil : notes
        trade.confidenceScore = confidenceScore

        let openExecType: ExecutionType = side == .long ? .buy : .sell
        if let qty = effectiveShares {
            trade.executions.append(Execution(price: p, quantity: qty, type: openExecType, date: isPastTrade ? openDate : Date()))
        }

        if isPastTrade, let exit = exitPrice, let qty = effectiveShares {
            let closeExecType: ExecutionType = side == .long ? .sell : .buy
            trade.executions.append(Execution(price: exit, quantity: qty, type: closeExecType, date: closeDate))
            trade.exitPrice = exit
            trade.dateClosed = closeDate
        }

        context.insert(trade)
        AnalyticsService.shared.log(
            isPastTrade ? .tradeClosed : .tradeOpened,
            details: "Ticker: \(ticker), Side: \(side.rawValue)",
            context: context
        )
    }

    private var resolvedStrategy: String? {
        guard let strat = selectedStrategy else { return nil }
        return strat == .other ? (customStrategy.isEmpty ? nil : customStrategy) : strat.rawValue
    }
}
