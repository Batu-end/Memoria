//
//  AddTradeViewModel.swift
//  Memoria

import SwiftUI
import SwiftData

@Observable
final class AddTradeViewModel {

    // MARK: - Form State
    var ticker = ""
    var priceString = ""
    var capitalString = ""
    var sharesString = ""
    var useSharesMode = false
    var side: TradeSide = .long
    var assetType: AssetType = .stock
    var selectedStrategy: TradeStrategy? = nil
    var customStrategy = ""
    var stopLossString = ""
    var takeProfitString = ""
    var confidenceScore = 0
    var notes = ""
    var isPastTrade = false
    var openDate = Date()
    var exitPriceString = ""
    var closeDate = Date()

    // MARK: - Parsed Values
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
        return (exit - entry) * (c / entry) * (side == .long ? 1.0 : -1.0)
    }

    var isValid: Bool {
        guard !ticker.isEmpty, price != nil else { return false }
        let hasSize = effectiveCapital != nil
        if isPastTrade { return hasSize && exitPrice != nil }
        return hasSize
    }

    var resolvedStrategy: String? {
        guard let strat = selectedStrategy else { return nil }
        return strat == .other ? (customStrategy.isEmpty ? nil : customStrategy) : strat.rawValue
    }

    // MARK: - Save
    func saveTrade(context: ModelContext, portfolio: Portfolio) {
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

        trade.portfolio = portfolio
        context.insert(trade)
        AnalyticsService.shared.log(
            isPastTrade ? .tradeClosed : .tradeOpened,
            details: "Ticker: \(ticker), Side: \(side.rawValue)",
            context: context
        )
    }
}
