//
//  StockQuoteService.swift
//  Memoria
//
//  Fetches live stock quotes from Yahoo Finance (v8 chart API).
//  Uses the chart endpoint which is more reliable than the quote endpoint.
//

import Foundation

/// Represents a single stock quote
struct StockQuote: Equatable {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let volume: Int?
    let marketCap: Double?
}

struct HistoricalQuote: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let close: Double
}

/// Service responsible for fetching live stock data
class StockQuoteService {
    static let shared = StockQuoteService()
    private init() {}
    
    /// Fetches quotes for multiple symbols (one request per symbol via the chart API).
    /// Returns a dictionary keyed by symbol for easy lookup.
    func fetchQuotes(for symbols: [String]) async -> [String: StockQuote] {
        var results: [String: StockQuote] = [:]
        
        // Fetch each symbol concurrently using a task group
        await withTaskGroup(of: (String, StockQuote?).self) { group in
            for symbol in symbols {
                group.addTask {
                    let quote = await self.fetchSingleQuote(symbol: symbol)
                    return (symbol.uppercased(), quote)
                }
            }
            
            for await (symbol, quote) in group {
                if let quote = quote {
                    results[symbol] = quote
                }
            }
        }
        
        return results
    }
    
    /// Convenience: fetch a single symbol
    func fetchQuote(for symbol: String) async -> StockQuote? {
        return await fetchSingleQuote(symbol: symbol)
    }
    
    
    /// Fetches the closing price of a symbol on or immediately after a specific date.
    /// Useful for calculating benchmark returns (e.g., SPY price when the portfolio started).
    func fetchBaselinePrice(symbol: String, startDate: Date) async -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        // Fetch a 7-day window to guarantee we hit a trading day (skipping weekends/holidays)
        guard let endOfDay = calendar.date(byAdding: .day, value: 7, to: startOfDay) else { return nil }
        
        let p1 = Int(startOfDay.timeIntervalSince1970)
        let p2 = Int(endOfDay.timeIntervalSince1970)
        
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&period1=\(p1)&period2=\(p2)"
        
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let result = results.first,
                  let indicators = result["indicators"] as? [String: Any],
                  let quote = indicators["quote"] as? [[String: Any]],
                  let firstQuote = quote.first,
                  let closes = firstQuote["close"] as? [Double?] else {
                return nil
            }
            
            // Return the first valid closing price in the window
            return closes.compactMap { $0 }.first
        } catch {
            return nil
        }
    }
    
    /// Fetches a historical series of closing prices from the start date to today.
    func fetchHistoricalSeries(symbol: String, startDate: Date) async -> [HistoricalQuote]? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        // Ensure we request up to tomorrow to capture today's close if available
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        let p1 = Int(startOfDay.timeIntervalSince1970)
        let p2 = Int(endOfDay.timeIntervalSince1970)
        
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&period1=\(p1)&period2=\(p2)"
        
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let result = results.first,
                  let timestamps = result["timestamp"] as? [Int],
                  let indicators = result["indicators"] as? [String: Any],
                  let quote = indicators["quote"] as? [[String: Any]],
                  let firstQuote = quote.first,
                  let closes = firstQuote["close"] as? [Double?] else {
                return nil
            }
            
            var series: [HistoricalQuote] = []
            for (i, ts) in timestamps.enumerated() {
                if i < closes.count, let close = closes[i] {
                    let date = Date(timeIntervalSince1970: TimeInterval(ts))
                    series.append(HistoricalQuote(date: date, close: close))
                }
            }
            return series
        } catch {
            return nil
        }
    }
    
    /// Fetches today's intraday closes at 5-minute intervals for a sparkline.
    func fetchSparkline(symbol: String) async -> [Double] {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=5m&range=1d"
        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let indicators = result["indicators"] as? [String: Any],
              let quote = indicators["quote"] as? [[String: Any]],
              let closes = quote.first?["close"] as? [Double?] else { return [] }
        return closes.compactMap { $0 }
    }

    // MARK: - Internal
    
    private func fetchSingleQuote(symbol: String) async -> StockQuote? {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"
        
        guard let url = URL(string: urlString) else {
            print("⚠️ StockQuoteService: Invalid URL for \(symbol)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("⚠️ StockQuoteService: HTTP \(httpResponse.statusCode) for \(symbol)")
                    return nil
                }
            }
            
            return parseChartResponse(data, symbol: symbol)
        } catch {
            print("⚠️ StockQuoteService: \(error.localizedDescription) for \(symbol)")
            return nil
        }
    }
    
    private func parseChartResponse(_ data: Data, symbol: String) -> StockQuote? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let meta = result["meta"] as? [String: Any] else {
            print("⚠️ StockQuoteService: Failed to parse JSON for \(symbol)")
            return nil
        }
        
        let currentPrice = meta["regularMarketPrice"] as? Double ?? 0
        let previousClose = meta["chartPreviousClose"] as? Double
                         ?? meta["previousClose"] as? Double ?? 0
        let change = currentPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
        let volume = meta["regularMarketVolume"] as? Int
        let marketCap = meta["marketCap"] as? Double

        return StockQuote(
            symbol: symbol.uppercased(),
            currentPrice: currentPrice,
            previousClose: previousClose,
            change: change,
            changePercent: changePercent,
            volume: volume,
            marketCap: marketCap
        )
    }
}
