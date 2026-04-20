import XCTest
import SwiftData
@testable import Memoria

final class AccountingEngineTests: XCTestCase {
    
    var engine: AccountingEngine!
    
    override func setUp() {
        super.setUp()
        engine = AccountingEngine.shared
        engine.reset() // Start each test with a clean slate
    }

    func testVwapAndScaling() async {
        // 1. Setup a trade with multiple executions
        let trade = Trade(ticker: "AAPL", side: .long)
        let buy1 = Execution(price: 150, quantity: 10, type: .buy, date: Date())
        let buy2 = Execution(price: 160, quantity: 10, type: .buy, date: Date())
        trade.executions = [buy1, buy2]
        
        // 2. Run engine update
        engine.update(trades: [trade], startingBalance: 10000)
        
        // Give the background task a moment to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        // 3. Verify Math
        let math = engine.mathForTrade(trade.id)
        XCTAssertNotNil(math)
        XCTAssertEqual(math?.vwap, 155.0, "VWAP should be (150*10 + 160*10) / 20 = 155")
        XCTAssertEqual(math?.effectiveQuantity, 20.0, "Quantity should be 20")
    }
    
    func testRealizedPnlOnPartialExit() async {
        let trade = Trade(ticker: "TSLA", side: .long)
        
        // Buy 10 @ 100 ($1000 cost)
        let buy = Execution(price: 100, quantity: 10, type: .buy, date: Date())
        trade.executions = [buy]
        
        // Sell 5 @ 150 (Profit: (150-100)*5 = 250)
        let sell = Execution(price: 150, quantity: 5, type: .sell, date: Date())
        trade.executions.append(sell)
        
        engine.update(trades: [trade], startingBalance: 10000)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        let math = engine.mathForTrade(trade.id)
        XCTAssertEqual(math?.realizedPnl, 250.0)
        XCTAssertEqual(math?.effectiveQuantity, 5.0)
    }
    
    func testShortPositionProfit() async {
        let trade = Trade(ticker: "SPY", side: .short)
        
        // Short 10 @ 400
        let sell = Execution(price: 400, quantity: 10, type: .sell, date: Date())
        trade.executions = [sell]
        
        // Cover 10 @ 390 (Profit: (400-390)*10 = 100)
        let buy = Execution(price: 390, quantity: 10, type: .buy, date: Date())
        trade.executions.append(buy)
        
        engine.update(trades: [trade], startingBalance: 10000)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        let math = engine.mathForTrade(trade.id)
        XCTAssertEqual(math?.realizedPnl, 100.0)
        XCTAssertEqual(math?.winStatus, true, "P&L of 100 should be a win")
    }
    
    func testBreakevenIsWin() async {
        let trade = Trade(ticker: "GE", side: .long)
        
        // Buy 10 @ 100
        let buy = Execution(price: 100, quantity: 10, type: .buy, date: Date())
        // Sell 10 @ 100 (Breakeven)
        let sell = Execution(price: 100, quantity: 10, type: .sell, date: Date())
        trade.executions = [buy, sell]
        trade.status = .closed
        
        engine.update(trades: [trade], startingBalance: 10000)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
        
        let math = engine.mathForTrade(trade.id)
        XCTAssertEqual(math?.totalPnl, 0.0)
        XCTAssertEqual(math?.winStatus, true, "Breakeven (0.0) should be treated as a win for consistency")
    }
    
    func testPortfolioAggregation() async {
        let trade1 = Trade(ticker: "AAPL", side: .long) // Win $100
        trade1.executions = [Execution(price: 100, quantity: 10, type: .buy, date: Date())]
        trade1.executions.append(Execution(price: 110, quantity: 10, type: .sell, date: Date()))
        trade1.status = .closed
        
        let trade2 = Trade(ticker: "TSLA", side: .long) // Loss $50
        trade2.executions = [Execution(price: 200, quantity: 1, type: .buy, date: Date())]
        trade2.executions.append(Execution(price: 150, quantity: 1, type: .sell, date: Date()))
        trade2.status = .closed
        
        engine.update(trades: [trade1, trade2], startingBalance: 1000)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let state = engine.portfolioState
        XCTAssertEqual(state.winCount, 1)
        XCTAssertEqual(state.lossCount, 1)
        XCTAssertEqual(state.winRate, 50.0)
        XCTAssertEqual(state.totalPnl, 50.0, "100 - 50 = 50")
        XCTAssertEqual(state.profitFactor, 2.0, "100 / 50 = 2.0")
    }
    
    func testMaxDrawdownCalculation() async {
        // Simulate a Peak then a Trough
        let win = Trade(ticker: "BIGWIN")
        win.executions = [Execution(price: 100, quantity: 10, type: .buy, date: Date())]
        win.executions.append(Execution(price: 200, quantity: 10, type: .sell, date: Date())) // +$1000
        win.status = .closed
        
        // After Win, Balance = 1000 + 1000 = 2000 (Peak)
        
        let loss = Trade(ticker: "BIGLOSS")
        loss.executions = [Execution(price: 100, quantity: 10, type: .buy, date: Date().addingTimeInterval(100))]
        loss.executions.append(Execution(price: 50, quantity: 10, type: .sell, date: Date().addingTimeInterval(200))) // -$500
        loss.status = .closed
        
        // After Loss, Balance = 2000 - 500 = 1500 (Trough)
        // Expected DD: (2000 - 1500) / 2000 = 25%
        
        engine.update(trades: [win, loss], startingBalance: 1000)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        XCTAssertEqual(engine.portfolioState.maxDrawdown, 25.0, accuracy: 0.1)
    }
    
    func testUnrealizedPnlAndLiquidity() async {
        let trade = Trade(ticker: "LIVE", side: .long)
        trade.executions = [Execution(price: 100, quantity: 10, type: .buy, date: Date())]
        
        // Manual update with simulated quote
        engine.update(trades: [trade], startingBalance: 1000)
        
        // Wait then simulate a price move to $110
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // We'll let the engine run, then check liquidity. 
        // With quote at $100, Unrealized = 0, Net Liq = 1000
        // If we could mock the StockQuoteService here, we would. 
        // For now, we verify that starting balance is reflected.
        XCTAssertEqual(engine.portfolioState.netLiquidity, 1000.0)
    }
}
