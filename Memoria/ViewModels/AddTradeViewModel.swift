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
    var quantityString: String = ""
    var side: TradeSide = .long
    var assetType: AssetType = .stock
    var selectedStrategy: TradeStrategy? = nil
    var customStrategy: String = ""
    var stopLossString: String = ""
    var takeProfitString: String = ""
    var notes: String = ""
    
    // MARK: - Validation
    
    var isValidPrice: Bool {
        priceString.isEmpty || Double(priceString) != nil
    }
    
    var isValidQuantity: Bool {
        quantityString.isEmpty || Double(quantityString) != nil
    }
    
    var isValidStopLoss: Bool {
        stopLossString.isEmpty || Double(stopLossString) != nil
    }
    
    var isValidTakeProfit: Bool {
        takeProfitString.isEmpty || Double(takeProfitString) != nil
    }
    
    var isValidForm: Bool {
        !ticker.isEmpty && !priceString.isEmpty && isValidPrice && isValidQuantity && isValidStopLoss && isValidTakeProfit
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
        trade.entryPrice = Double(priceString)
        trade.quantity = Double(quantityString)
        trade.stopLoss = Double(stopLossString)
        trade.takeProfit = Double(takeProfitString)
        trade.strategy = resolvedStrategy
        trade.notes = notes.isEmpty ? nil : notes
        
        context.insert(trade)
        
        AnalyticsService.shared.log(.tradeOpened, details: "Ticker: \(ticker), Side: \(side.rawValue)", context: context)
    }
}
