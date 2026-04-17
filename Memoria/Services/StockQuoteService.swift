//
//  StockQuoteService.swift
//  Memoria
//
//  Fetches live stock quotes from Yahoo Finance (v8 chart API).
//  Uses the chart endpoint which is more reliable than the quote endpoint.
//

import Foundation

/// Represents a single stock quote
struct StockQuote {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
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
        
        return StockQuote(
            symbol: symbol.uppercased(),
            currentPrice: currentPrice,
            previousClose: previousClose,
            change: change,
            changePercent: changePercent
        )
    }
}
