//
//  AddTradeViewModel.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class AddTradeViewModel {
    // MARK: - Properties
    var ticker: String = ""
    var priceString: String = ""
    var capitalString: String = ""
    var side: TradeSide = .long
    var assetType: AssetType = .stock
    var selectedStrategy: TradeStrategy? = nil
    var customStrategy: String = ""
    var stopLossString: String = ""
    var takeProfitString: String = ""
    var notes: String = ""
    var confidenceScore: Int = 0

    // Past trade mode
    var isPastTrade: Bool = false
    var openDate: Date = Date()
    var exitPriceString: String = ""
    var closeDate: Date = Date()
    
    // MARK: - Validation
    
    var isValidPrice: Bool {
        priceString.isEmpty || Double(priceString) != nil
    }
    
    var isValidCapital: Bool {
        capitalString.isEmpty || Double(capitalString) != nil
    }
    
    var isValidStopLoss: Bool {
        stopLossString.isEmpty || Double(stopLossString) != nil
    }
    
    var isValidTakeProfit: Bool {
        takeProfitString.isEmpty || Double(takeProfitString) != nil
    }
    
    var isValidExitPrice: Bool {
        exitPriceString.isEmpty || Double(exitPriceString) != nil
    }

    var isValidForm: Bool {
        guard !ticker.isEmpty && !priceString.isEmpty && isValidPrice && isValidCapital && isValidStopLoss && isValidTakeProfit else { return false }
        if isPastTrade {
            return !exitPriceString.isEmpty && isValidExitPrice
        }
        return true
    }
    
    /// The resolved strategy string — uses custom if "Other" is selected
    var resolvedStrategy: String? {
        guard let strat = selectedStrategy else { return nil }
        if strat == .other {
            return customStrategy.isEmpty ? nil : customStrategy
        }
        return strat.rawValue
    }
    
    // MARK: - Actions
    
    func addTrade(context: ModelContext) {
        let status: TradeStatus = isPastTrade ? .closed : .open
        let trade = Trade(ticker: ticker.uppercased(), status: status, side: side, assetType: assetType)
        let price = Double(priceString)
        let capital = Double(capitalString)

        trade.entryPrice = price
        trade.dateAdded = isPastTrade ? openDate : Date()
        if let p = price, let c = capital, p > 0 {
            trade.quantity = c / p
        }

        trade.stopLoss = Double(stopLossString)
        trade.takeProfit = Double(takeProfitString)
        trade.strategy = resolvedStrategy
        trade.notes = notes.isEmpty ? nil : notes
        trade.confidenceScore = confidenceScore

        // Opening execution
        let openExecType: ExecutionType = side == .long ? .buy : .sell
        if let p = price, let q = trade.quantity {
            let openExec = Execution(price: p, quantity: q, type: openExecType, date: isPastTrade ? openDate : Date())
            trade.executions.append(openExec)
        }

        // Closing execution (past trades only)
        if isPastTrade, let exitPrice = Double(exitPriceString), let q = trade.quantity {
            let closeExecType: ExecutionType = side == .long ? .sell : .buy
            let closeExec = Execution(price: exitPrice, quantity: q, type: closeExecType, date: closeDate)
            trade.executions.append(closeExec)
            trade.exitPrice = exitPrice
            trade.dateClosed = closeDate
        }

        context.insert(trade)

        let logType: AnalyticsEvent = isPastTrade ? .tradeClosed : .tradeOpened
        AnalyticsService.shared.log(logType, details: "Ticker: \(ticker), Side: \(side.rawValue)", context: context)
    }
}
