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
    // These properties are bound to the View. When they change, the View updates.
    var ticker: String = ""
    var priceString: String = ""
    
    // MARK: - Validation
    // Computed properties that determine if the form is valid.
    // The View observes these to enable/disable the "Save" button.
    var isValidPrice: Bool {
        return Double(priceString) != nil
    }
    
    var isValidForm: Bool {
        return !ticker.isEmpty && isValidPrice
    }
    
    // MARK: - Actions
    /// Creates a new Trade object and inserts it into the SwiftData context.
    /// Also logs the event to the centralized AnalyticsService.
    func addTrade(context: ModelContext) {
        let trade = Trade(ticker: ticker.isEmpty ? "UNKNOWN" : ticker, status: .open)
        trade.entryPrice = Double(priceString)
        context.insert(trade)
        
        // Log Event
        AnalyticsService.shared.log(.tradeOpened, details: "Ticker: \(ticker)", context: context)
    }
}
