import Foundation
import SwiftUI
import SwiftData


// MARK: - Snapshot Models

struct CapturedExecution {
    let price: Double
    let quantity: Double
    let type: ExecutionType
}

struct CapturedCapitalEvent {
    let date: Date
    let amount: Double
}

struct CapturedTrade {
    let id: UUID
    let ticker: String
    let status: TradeStatus
    let side: TradeSide
    let entryPrice: Double?
    let exitPrice: Double?
    let quantity: Double?
    let dateAdded: Date
    let dateClosed: Date?
    let stopLoss: Double?
    let confidenceScore: Int
    let executions: [CapturedExecution]
    
    init(_ trade: Trade) {
        self.id = trade.id
        self.ticker = trade.ticker
        self.status = trade.status
        self.side = trade.side
        self.entryPrice = trade.entryPrice
        self.exitPrice = trade.exitPrice
        self.quantity = trade.quantity
        self.dateAdded = trade.dateAdded
        self.dateClosed = trade.dateClosed
        self.stopLoss = trade.stopLoss
        self.confidenceScore = trade.confidenceScore
        self.executions = trade.executions.map { 
            CapturedExecution(price: $0.price, quantity: $0.quantity, type: $0.type) 
        }
    }
}

@Observable
class AccountingEngine {
    static let shared = AccountingEngine()

    // Output
    var portfolioState: AccountingState = .empty
    private(set) var tradeAccounting: [UUID: TradeAccounting] = [:]

    // Internal state
    private var trades: [Trade] = []
    private var quotes: [String: StockQuote] = [:]
    private var startingBalance: Double = 0.0
    private var capturedCapitalEvents: [CapturedCapitalEvent] = []

    private var calculationTask: Task<Void, Never>?

    nonisolated private init() {}
    
    /// Clears all cached math and trades. Use only for testing or full data resets.
    func reset() {
        self.trades = []
        self.tradeAccounting = [:]
        self.portfolioState = .empty
        self.quotes = [:]
        self.capturedCapitalEvents = []
    }
    
    /// Internal method for testing to simulate price moves.
    func testOnly_setQuote(ticker: String, price: Double) {
        let quote = StockQuote(symbol: ticker.uppercased(), currentPrice: price, previousClose: price, change: 0, changePercent: 0, volume: nil, marketCap: nil)
        self.quotes[ticker.uppercased()] = quote
    }
    
    // MARK: - Input updates
    
    func update(trades: [Trade], startingBalance: Double, capitalEvents: [CapitalEvent] = []) {
        self.trades = trades
        self.startingBalance = startingBalance
        self.capturedCapitalEvents = capitalEvents.map { CapturedCapitalEvent(date: $0.date, amount: $0.amount) }
        recalculate()
    }

    func update(quotes: [String: StockQuote]) {
        self.quotes = quotes
        recalculate()
    }

    /// Call immediately after mutating a trade's executions so the UI reflects
    /// the change without waiting for the DashboardView @Query onChange cycle.
    func refresh() {
        recalculate()
    }
    
    // MARK: - Core Math Engine
    
    private func recalculate() {
        // 1. Capture snapshot on Main Thread (safe for SwiftData models)
        let capturedTrades = self.trades.map { CapturedTrade($0) }
        let currentQuotes = self.quotes
        let balance = self.startingBalance
        let capturedEvents = self.capturedCapitalEvents
        
        // 2. Cancel any pending calculation
        calculationTask?.cancel()
        
        // 3. Offload math to background
        calculationTask = Task.detached(priority: .userInitiated) {
            var newState = AccountingState()
            var newTradeMath: [UUID: TradeAccounting] = [:]
            
            let openTrades = capturedTrades.filter { $0.status == .open }
            let closedTrades = capturedTrades.filter { $0.status == .closed }
            
            newState.openTradesCount = openTrades.count
            newState.closedTradesCount = closedTrades.count
            
            // Calculate each trade's math using snapshots
            for trade in capturedTrades {
                if Task.isCancelled { return }
                
                // Initialize trade-specific math container
                var math = TradeAccounting(tradeId: trade.id)
                
                // 1. Determine Basis (VWAP) based on Side
                let openingExecs = trade.side == .long ? 
                    trade.executions.filter { $0.type == .buy } : 
                    trade.executions.filter { $0.type == .sell }
                
                let closingExecs = trade.side == .long ? 
                    trade.executions.filter { $0.type == .sell } : 
                    trade.executions.filter { $0.type == .buy }
                
                let totalOpeningQty = openingExecs.reduce(0) { $0 + $1.quantity }
                let totalCostBasis = openingExecs.reduce(0) { $0 + ($1.price * $1.quantity) }
                
                let totalClosingQty = closingExecs.reduce(0) { $0 + $1.quantity }
                
                math.vwap = totalOpeningQty > 0 ? totalCostBasis / totalOpeningQty : trade.entryPrice
                // Fall back to trade.quantity when executions haven't loaded yet (SwiftData lazy-loads cascades)
                math.effectiveQuantity = totalOpeningQty > 0 ? totalOpeningQty - totalClosingQty : (trade.quantity ?? 0)
                
                let currentVwap = math.vwap ?? 0
                let direction: Double = (trade.side == .short) ? -1.0 : 1.0
                
                // Realized P&L: (Exit Price - Entry VWAP) * Qty * Direction
                math.realizedPnl = closingExecs.reduce(0) { $0 + (($1.price - currentVwap) * $1.quantity * direction) }
                
                if trade.status == .open {
                    if let livePrice = currentQuotes[trade.ticker.uppercased()]?.currentPrice {
                        math.unrealizedPnl = (livePrice - currentVwap) * math.effectiveQuantity * direction
                    }
                    math.totalPnl = (math.realizedPnl ?? 0) + math.unrealizedPnl
                } else {
                    math.unrealizedPnl = 0
                    // For closed trades without explicit executions (legacy or manual), use exitPrice
                    if closingExecs.isEmpty, let exit = trade.exitPrice {
                         math.totalPnl = (exit - currentVwap) * math.effectiveQuantity * direction
                    } else {
                         math.totalPnl = math.realizedPnl
                    }
                }
                
                if let pnl = math.totalPnl, totalCostBasis > 0 {
                    math.percentReturn = (pnl / totalCostBasis) * 100.0
                }
                
                math.positionSize = (math.vwap ?? 0) * math.effectiveQuantity
                math.winStatus = (math.totalPnl ?? 0) >= 0
                
                if let sl = trade.stopLoss, let entry = math.vwap {
                    let risk = abs(entry - sl)
                    if risk > 0 {
                        let currentPrice = (trade.status == .closed) ? (trade.exitPrice ?? entry) : (currentQuotes[trade.ticker.uppercased()]?.currentPrice ?? entry)
                        let pnlPerShare = (currentPrice - entry) * (trade.side == .long ? 1.0 : -1.0)
                        math.rMultiple = pnlPerShare / risk
                    }
                }
                
                newTradeMath[trade.id] = math
            }
            
            // Aggregate Portfolio Math
            newState.totalPnl = closedTrades.compactMap { newTradeMath[$0.id]?.totalPnl }.reduce(0, +)
            newState.unrealizedPnl = openTrades.compactMap { newTradeMath[$0.id]?.unrealizedPnl }.reduce(0, +)
            newState.totalExposure = openTrades.compactMap { newTradeMath[$0.id]?.positionSize }.reduce(0, +)
            newState.netLiquidity = balance + newState.totalPnl + newState.unrealizedPnl
            
            if newState.totalExposure > 0 {
                newState.unrealizedReturn = (newState.unrealizedPnl / newState.totalExposure) * 100.0
            }
            
            let closedWithPnl = closedTrades.compactMap { newTradeMath[$0.id] }
            if !closedWithPnl.isEmpty {
                let wins = closedWithPnl.filter { $0.winStatus }
                let losses = closedWithPnl.filter { !($0.winStatus) }
                
                newState.winCount = wins.count
                newState.lossCount = losses.count
                newState.winRate = (Double(wins.count) / Double(closedWithPnl.count)) * 100.0
                
                let grossWin = wins.compactMap { $0.totalPnl }.reduce(0, +)
                let grossLoss = abs(losses.compactMap { $0.totalPnl }.reduce(0, +))
                newState.profitFactor = grossLoss > 0 ? grossWin / grossLoss : (grossWin > 0 ? .infinity : 0)
                
                newState.avgWin = wins.isEmpty ? 0 : grossWin / Double(wins.count)
                newState.avgLoss = losses.isEmpty ? 0 : abs(losses.compactMap { $0.totalPnl }.reduce(0, +)) / Double(losses.count)
            }
            
            // Helper for curve calculation inside the background task
            func backgroundCurve(closedMath: [TradeAccounting], tradesSnapshot: [CapturedTrade], floating: Double, startingBalance: Double) -> [EquityDataPoint] {
                struct TradePoint {
                    let date: Date
                    let pnl: Double
                    let isWin: Bool
                    let ticker: String
                }
                var datePoints: [TradePoint] = []
                for math in closedMath {
                    if let trade = tradesSnapshot.first(where: { $0.id == math.tradeId }) {
                        let date = trade.dateClosed ?? trade.dateAdded
                        datePoints.append(TradePoint(date: date, pnl: math.totalPnl ?? 0, isWin: math.winStatus, ticker: trade.ticker))
                    }
                }
                let sortedPoints = datePoints.sorted { $0.date < $1.date }
                var history: [EquityDataPoint] = []
                var runningPnl = 0.0
                if let firstDate = sortedPoints.first?.date {
                    history.append(EquityDataPoint(date: firstDate.addingTimeInterval(-86400), balance: startingBalance))
                } else {
                    history.append(EquityDataPoint(date: Date(), balance: startingBalance))
                }
                for pt in sortedPoints {
                    runningPnl += pt.pnl
                    history.append(EquityDataPoint(date: pt.date, balance: startingBalance + runningPnl, isTrade: true, isWin: pt.isWin, ticker: pt.ticker))
                }
                history.append(EquityDataPoint(date: Date(), balance: startingBalance + runningPnl + floating))
                return history
            }
            
            newState.equityCurve = backgroundCurve(closedMath: closedWithPnl, tradesSnapshot: capturedTrades, floating: newState.unrealizedPnl, startingBalance: balance)
            
            // Max Drawdown calculation
            var peak = newState.equityCurve.first?.balance ?? 0
            var maxDD = 0.0
            for pt in newState.equityCurve {
                if pt.balance > peak { peak = pt.balance }
                let dd = peak > 0 ? (peak - pt.balance) / peak * 100 : 0
                if dd > maxDD { maxDD = dd }
            }
            newState.maxDrawdown = maxDD

            // TWR computation
            if balance > 0 {
                let curve = newState.equityCurve
                let sortedEvents = capturedEvents.sorted { $0.date < $1.date }
                var twrFactor = 1.0
                var periodStart = balance
                for event in sortedEvents {
                    let valueAtEvent = curve.last { $0.date <= event.date }?.balance ?? periodStart
                    if periodStart > 0 { twrFactor *= valueAtEvent / periodStart }
                    periodStart = valueAtEvent + event.amount
                }
                if let finalBalance = curve.last?.balance, periodStart > 0 {
                    twrFactor *= finalBalance / periodStart
                }
                newState.twr = twrFactor - 1
            }

            // Daily P&L aggregator (closed trades, grouped by start-of-day)
            var dailyPnl: [Date: Double] = [:]
            let cal = Calendar.current
            for trade in closedTrades {
                if let pnl = newTradeMath[trade.id]?.totalPnl {
                    let day = cal.startOfDay(for: trade.dateClosed ?? trade.dateAdded)
                    dailyPnl[day, default: 0] += pnl
                }
            }
            newState.dailyPnl = dailyPnl

            if Task.isCancelled { return }

            // 4. Update state on Main Thread
            let finalState = newState
            let finalTradeMath = newTradeMath
            await MainActor.run {
                self.portfolioState = finalState
                self.tradeAccounting = finalTradeMath
            }
        }
    }
    
    func calculateRelativeCurve(from startDate: Date) -> [EquityDataPoint] {
        // Since this is called synchronously from Chart views, we use cached state
        // In a real app with 10k trades, this should also be backgrounded,
        // but for now, we'll keep it as is using the tradeAccounting dictionary.
        
        let closedAfter = trades.filter { 
            ($0.dateClosed ?? $0.dateAdded) >= startDate 
        }.compactMap { tradeAccounting[$0.id] }
        
        var datePoints: [(date: Date, pnl: Double)] = []
        for math in closedAfter {
            if let trade = trades.first(where: { $0.id == math.tradeId }) {
                datePoints.append((date: trade.dateClosed ?? trade.dateAdded, pnl: math.totalPnl ?? 0))
            }
        }
        
        let sorted = datePoints.sorted { $0.date < $1.date }
        var points: [EquityDataPoint] = [EquityDataPoint(date: startDate, balance: 0)]
        var accum = 0.0
        for pt in sorted {
            accum += pt.pnl
            points.append(EquityDataPoint(date: pt.date, balance: accum))
        }
        points.append(EquityDataPoint(date: Date(), balance: accum + portfolioState.unrealizedPnl))
        return points
    }

    func mathForTrade(_ id: UUID) -> TradeAccounting? {
        return tradeAccounting[id]
    }

    func currentPrice(for ticker: String) -> Double? {
        return quotes[ticker.uppercased()]?.currentPrice
    }
}
