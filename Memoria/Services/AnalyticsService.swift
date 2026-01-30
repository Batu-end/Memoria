//
//  AnalyticsService.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import Foundation
import SwiftData

/// Defines all possible events we want to track in the app.
/// This prevents typo-prone strings scattered throughout the codebase.
enum AnalyticsEvent: String {
    case tradeOpened = "Trade Opened"
    case tradeClosed = "Trade Closed"
    case watchlistItemAdded = "Watchlist Item Added"
    case watchlistItemDeleted = "Watchlist Item Removed"
    case appLaunched = "App Launched"
}

/// A centralized service responsible for logging user actions.
/// Currently writes to the local database (`ActivityLog`), but could be easily
/// extended to send data to a remote backend (Firebase, Mixpanel, etc).
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    /// Logs an event to the persistent store.
    /// - Parameters:
    ///   - event: The strict enum identifying the action.
    ///   - details: Optional context (e.g., Ticker Symbol, Error Message).
    ///   - context: The SwiftData context to write to.
    func log(_ event: AnalyticsEvent, details: String? = nil, context: ModelContext) {
        let log = ActivityLog(title: event.rawValue, actionType: "User Action", details: details)
        context.insert(log)
        
        // In a real app, you might also send this to Firebase/Mixpanel here
        print("📊 Analytics Logged: \(event.rawValue) - \(details ?? "")")
    }
}
