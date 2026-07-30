//
//  AnalyticsSandbox.swift
//  Memoria
//
//  Preview + debug seeding only. Do NOT use in production logic.

import SwiftUI
import SwiftData

// MARK: - Shared Seeding Logic

/// Inserts a "Demo — 45 Trades" portfolio into any ModelContext.
/// Safe to call on the real app container (debug builds only).
@MainActor
func seedDemoPortfolio(into ctx: ModelContext) {
    let portfolio = Portfolio(name: "Demo — 45 Trades", startingBalance: 50_000)
    ctx.insert(portfolio)

    func trade(
        _ ticker: String, _ side: TradeSide, _ strategy: String,
        entryPrice: Double, exitPrice: Double, qty: Double,
        confidence: Int, daysAgo: Int, holdDays: Int = 2
    ) {
        let t = Trade(ticker: ticker, status: .closed, side: side)
        t.portfolio = portfolio
        t.strategy = strategy
        t.confidenceScore = confidence
        t.dateAdded  = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        t.dateClosed = Calendar.current.date(byAdding: .day, value: -(daysAgo - holdDays), to: Date())!
        ctx.insert(t)

        let entryExec = Execution(
            price: entryPrice, quantity: qty,
            type: side == .long ? .buy : .sell,
            date: t.dateAdded
        )
        entryExec.trade = t
        ctx.insert(entryExec)

        let exitExec = Execution(
            price: exitPrice, quantity: qty,
            type: side == .long ? .sell : .buy,
            date: t.dateClosed!
        )
        exitExec.trade = t
        ctx.insert(exitExec)
    }

    // Breakout — 12 trades, 9W 3L
    trade("NVDA", .long,  "Breakout", entryPrice: 420, exitPrice: 445,  qty: 10, confidence: 8,  daysAgo: 240, holdDays: 3)
    trade("TSLA", .long,  "Breakout", entryPrice: 180, exitPrice: 195,  qty: 20, confidence: 7,  daysAgo: 225, holdDays: 4)
    trade("META", .long,  "Breakout", entryPrice: 320, exitPrice: 345,  qty: 8,  confidence: 9,  daysAgo: 210, holdDays: 2)
    trade("AMD",  .long,  "Breakout", entryPrice: 95,  exitPrice: 105,  qty: 25, confidence: 8,  daysAgo: 195, holdDays: 3)
    trade("AMZN", .long,  "Breakout", entryPrice: 145, exitPrice: 140,  qty: 15, confidence: 4,  daysAgo: 183, holdDays: 2)
    trade("AAPL", .long,  "Breakout", entryPrice: 172, exitPrice: 185,  qty: 30, confidence: 9,  daysAgo: 170, holdDays: 5)
    trade("GOOGL",.long,  "Breakout", entryPrice: 140, exitPrice: 148,  qty: 20, confidence: 7,  daysAgo: 158, holdDays: 3)
    trade("MSFT", .long,  "Breakout", entryPrice: 310, exitPrice: 298,  qty: 10, confidence: 3,  daysAgo: 145, holdDays: 2)
    trade("SPY",  .long,  "Breakout", entryPrice: 450, exitPrice: 460,  qty: 20, confidence: 8,  daysAgo: 132, holdDays: 4)
    trade("QQQ",  .long,  "Breakout", entryPrice: 380, exitPrice: 395,  qty: 15, confidence: 8,  daysAgo: 118, holdDays: 3)
    trade("NVDA", .long,  "Breakout", entryPrice: 450, exitPrice: 440,  qty: 10, confidence: 2,  daysAgo: 102, holdDays: 1)
    trade("TSLA", .short, "Breakout", entryPrice: 175, exitPrice: 165,  qty: 20, confidence: 7,  daysAgo: 88,  holdDays: 3)

    // Momentum — 10 trades, 6W 4L
    trade("NVDA", .long,  "Momentum", entryPrice: 500, exitPrice: 540,  qty: 5,  confidence: 9,  daysAgo: 235, holdDays: 6)
    trade("TSLA", .long,  "Momentum", entryPrice: 220, exitPrice: 200,  qty: 10, confidence: 3,  daysAgo: 220, holdDays: 2)
    trade("AMD",  .long,  "Momentum", entryPrice: 120, exitPrice: 135,  qty: 20, confidence: 8,  daysAgo: 205, holdDays: 4)
    trade("META", .short, "Momentum", entryPrice: 350, exitPrice: 370,  qty: 8,  confidence: 2,  daysAgo: 188, holdDays: 2)
    trade("AAPL", .long,  "Momentum", entryPrice: 190, exitPrice: 200,  qty: 25, confidence: 7,  daysAgo: 174, holdDays: 5)
    trade("GOOGL",.short, "Momentum", entryPrice: 155, exitPrice: 145,  qty: 10, confidence: 6,  daysAgo: 160, holdDays: 3)
    trade("MSFT", .long,  "Momentum", entryPrice: 380, exitPrice: 395,  qty: 8,  confidence: 8,  daysAgo: 147, holdDays: 4)
    trade("AMZN", .long,  "Momentum", entryPrice: 185, exitPrice: 178,  qty: 10, confidence: 3,  daysAgo: 133, holdDays: 2)
    trade("NVDA", .short, "Momentum", entryPrice: 550, exitPrice: 565,  qty: 5,  confidence: 2,  daysAgo: 119, holdDays: 1)
    trade("SPY",  .long,  "Momentum", entryPrice: 470, exitPrice: 480,  qty: 20, confidence: 7,  daysAgo: 105, holdDays: 3)

    // Scalp — 8 trades, 5W 3L
    trade("AAPL", .long,  "Scalp",    entryPrice: 180, exitPrice: 183,  qty: 50, confidence: 5,  daysAgo: 230, holdDays: 1)
    trade("TSLA", .long,  "Scalp",    entryPrice: 200, exitPrice: 197,  qty: 30, confidence: 3,  daysAgo: 215, holdDays: 1)
    trade("AMD",  .long,  "Scalp",    entryPrice: 100, exitPrice: 104,  qty: 40, confidence: 6,  daysAgo: 200, holdDays: 1)
    trade("NVDA", .short, "Scalp",    entryPrice: 480, exitPrice: 475,  qty: 10, confidence: 6,  daysAgo: 185, holdDays: 1)
    trade("META", .long,  "Scalp",    entryPrice: 330, exitPrice: 327,  qty: 20, confidence: 2,  daysAgo: 171, holdDays: 1)
    trade("SPY",  .long,  "Scalp",    entryPrice: 460, exitPrice: 463,  qty: 30, confidence: 6,  daysAgo: 156, holdDays: 1)
    trade("QQQ",  .long,  "Scalp",    entryPrice: 390, exitPrice: 387,  qty: 20, confidence: 3,  daysAgo: 141, holdDays: 1)
    trade("MSFT", .short, "Scalp",    entryPrice: 365, exitPrice: 358,  qty: 15, confidence: 5,  daysAgo: 127, holdDays: 1)
    // Extra scalp losses — pushes WR below 50% so the bar falls under the breakeven line
    trade("TSLA", .long,  "Scalp",    entryPrice: 215, exitPrice: 208,  qty: 20, confidence: 2,  daysAgo: 112, holdDays: 1)
    trade("AAPL", .long,  "Scalp",    entryPrice: 188, exitPrice: 181,  qty: 25, confidence: 3,  daysAgo: 97,  holdDays: 1)
    trade("AMD",  .long,  "Scalp",    entryPrice: 105, exitPrice: 99,   qty: 30, confidence: 2,  daysAgo: 82,  holdDays: 1)
    trade("NVDA", .short, "Scalp",    entryPrice: 520, exitPrice: 535,  qty: 5,  confidence: 1,  daysAgo: 67,  holdDays: 1)

    // Reversal — 8 trades, 6W 2L
    trade("TSLA", .long,  "Reversal", entryPrice: 155, exitPrice: 175,  qty: 15, confidence: 9,  daysAgo: 228, holdDays: 7)
    trade("AMD",  .long,  "Reversal", entryPrice: 85,  exitPrice: 100,  qty: 30, confidence: 10, daysAgo: 213, holdDays: 8)
    trade("GOOGL",.long,  "Reversal", entryPrice: 130, exitPrice: 125,  qty: 15, confidence: 4,  daysAgo: 198, holdDays: 3)
    trade("META", .long,  "Reversal", entryPrice: 280, exitPrice: 310,  qty: 10, confidence: 9,  daysAgo: 182, holdDays: 6)
    trade("AAPL", .short, "Reversal", entryPrice: 200, exitPrice: 190,  qty: 20, confidence: 8,  daysAgo: 168, holdDays: 4)
    trade("NVDA", .long,  "Reversal", entryPrice: 380, exitPrice: 370,  qty: 10, confidence: 3,  daysAgo: 153, holdDays: 2)
    trade("SPY",  .long,  "Reversal", entryPrice: 430, exitPrice: 445,  qty: 20, confidence: 8,  daysAgo: 138, holdDays: 5)
    trade("AMZN", .long,  "Reversal", entryPrice: 130, exitPrice: 142,  qty: 15, confidence: 7,  daysAgo: 124, holdDays: 4)

    // Swing — 7 trades, 5W 2L
    trade("NVDA", .long,  "Swing",    entryPrice: 400, exitPrice: 450,  qty: 10, confidence: 9,  daysAgo: 222, holdDays: 14)
    trade("TSLA", .short, "Swing",    entryPrice: 230, exitPrice: 205,  qty: 15, confidence: 8,  daysAgo: 207, holdDays: 10)
    trade("AAPL", .long,  "Swing",    entryPrice: 165, exitPrice: 178,  qty: 25, confidence: 7,  daysAgo: 192, holdDays: 12)
    trade("META", .short, "Swing",    entryPrice: 380, exitPrice: 395,  qty: 10, confidence: 4,  daysAgo: 177, holdDays: 8)
    trade("AMD",  .long,  "Swing",    entryPrice: 80,  exitPrice: 88,   qty: 40, confidence: 7,  daysAgo: 162, holdDays: 11)
    trade("GOOGL",.long,  "Swing",    entryPrice: 148, exitPrice: 143,  qty: 15, confidence: 3,  daysAgo: 147, holdDays: 6)
    trade("MSFT", .long,  "Swing",    entryPrice: 350, exitPrice: 360,  qty: 12, confidence: 6,  daysAgo: 132, holdDays: 9)

    // Explicit Friday losers — forces Friday to show a negative avg P&L
    func nthPreviousFriday(_ n: Int) -> Date {
        var date = Date()
        var count = 0
        while count < n {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            if Calendar.current.component(.weekday, from: date) == 6 { count += 1 }
        }
        return date
    }
    func tradeOnDate(ticker: String, side: TradeSide, strategy: String,
                     entry: Double, exit: Double, qty: Double,
                     confidence: Int, closeDate: Date) {
        let openDate = Calendar.current.date(byAdding: .day, value: -1, to: closeDate)!
        let t = Trade(ticker: ticker, status: .closed, side: side)
        t.portfolio = portfolio; t.strategy = strategy; t.confidenceScore = confidence
        t.dateAdded = openDate; t.dateClosed = closeDate
        ctx.insert(t)
        let e1 = Execution(price: entry, quantity: qty, type: side == .long ? .buy  : .sell, date: openDate)
        let e2 = Execution(price: exit,  quantity: qty, type: side == .long ? .sell : .buy,  date: closeDate)
        e1.trade = t; e2.trade = t
        ctx.insert(e1); ctx.insert(e2)
    }
    // 4 Friday-closing losers: avg ~ −$67 each → Friday avg clearly negative
    tradeOnDate(ticker: "AAPL", side: .long,  strategy: "Momentum", entry: 185, exit: 170, qty: 4, confidence: 3, closeDate: nthPreviousFriday(1)) // −$60
    tradeOnDate(ticker: "MSFT", side: .long,  strategy: "Scalp",    entry: 370, exit: 355, qty: 4, confidence: 2, closeDate: nthPreviousFriday(2)) // −$60
    tradeOnDate(ticker: "AMD",  side: .long,  strategy: "Breakout", entry: 110, exit: 95,  qty: 5, confidence: 3, closeDate: nthPreviousFriday(3)) // −$75
    tradeOnDate(ticker: "TSLA", side: .long,  strategy: "Reversal", entry: 210, exit: 195, qty: 5, confidence: 2, closeDate: nthPreviousFriday(4)) // −$75

    try? ctx.save()
}

// MARK: - Preview Container

@MainActor
private func makeSandboxContainer() throws -> ModelContainer {
    let schema = Schema([
        Portfolio.self, Trade.self, Execution.self,
        AccountSnapshot.self, ActivityLog.self,
        WatchlistItem.self, CapitalEvent.self,
    ])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    seedDemoPortfolio(into: container.mainContext)
    return container
}

// MARK: - Preview

#Preview("Analytics — 45 Trades") {
    let container = try! makeSandboxContainer()
    let portfolio = try! container.mainContext.fetch(FetchDescriptor<Portfolio>()).first!
    return NavigationStack {
        AnalyticsView(portfolio: portfolio)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
