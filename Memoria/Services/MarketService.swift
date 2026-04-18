//
//  MarketService.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//  Checks if the market is open or closed.

import Foundation

enum MarketStatus {
    case preMarket
    case open
    case postMarket
    case closed
    case weekend
    
    var title: String {
        switch self {
        case .preMarket: return "Pre-Market"
        case .open: return "Market Open"
        case .postMarket: return "Post-Market"
        case .closed: return "Market Closed"
        case .weekend: return "Weekend"
        }
    }
    
    var color: String { // Returning system image colors logic could go here, but keeping simple
        switch self {
        case .preMarket: return "yellow"
        case .open: return "green"
        case .postMarket: return "yellow"
        case .closed: return "gray"
        case .weekend: return "orange"
        }
    }
}

class MarketService {
    static let shared = MarketService()
    
    // Check if NYSE is open (9:30 AM - 4:00 PM ET, Mon-Fri)
    func currentStatus() -> MarketStatus {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        guard let nyTimeZone = TimeZone(identifier: "America/New_York") else { return .closed }
        calendar.timeZone = nyTimeZone
        
        // 1. Check Weekend
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 { // Sunday=1, Saturday=7
            return .weekend
        }
        
        // 2. Check Time
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // Convert to minutes from midnight for easy comparison
        let currentMinutes = hour * 60 + minute
        
        let preMarketStart = 4 * 60      // 4:00 AM = 240
        let openMinutes = 9 * 60 + 30    // 9:30 AM = 570
        let closeMinutes = 16 * 60       // 4:00 PM = 960
        let postMarketEnd = 20 * 60      // 8:00 PM = 1200
        
        if currentMinutes >= preMarketStart && currentMinutes < openMinutes {
            return .preMarket
        } else if currentMinutes >= openMinutes && currentMinutes < closeMinutes {
            return .open
        } else if currentMinutes >= closeMinutes && currentMinutes < postMarketEnd {
            return .postMarket
        } else {
            return .closed
        }
    }
}
