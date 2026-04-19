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
    
    var isValidForm: Bool {
        !ticker.isEmpty && !priceString.isEmpty && isValidPrice && isValidCapital && isValidStopLoss && isValidTakeProfit
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
        let trade = Trade(ticker: ticker.uppercased(), status: .open, side: side, assetType: assetType)
        let price = Double(priceString)
        let capital = Double(capitalString)
        
        trade.entryPrice = price
        if let p = price, let c = capital, p > 0 {
            trade.quantity = c / p
        }

        trade.stopLoss = Double(stopLossString)
        trade.takeProfit = Double(takeProfitString)
        trade.strategy = resolvedStrategy
        trade.notes = notes.isEmpty ? nil : notes
        trade.confidenceScore = confidenceScore
        
        // ── Step 3: Record Initial Execution ────────
        if let p = price, let q = trade.quantity {
            let initialExecution = Execution(price: p, quantity: q, type: .buy)
            trade.executions.append(initialExecution)
        }
        
        context.insert(trade)
        
        AnalyticsService.shared.log(.tradeOpened, details: "Ticker: \(ticker), Side: \(side.rawValue)", context: context)
    }
}
