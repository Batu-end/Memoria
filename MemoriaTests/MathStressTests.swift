import XCTest
@testable import Memoria

final class MathStressTests: XCTestCase {
    
    var engine: AccountingEngine!
    
    override func setUp() {
        super.setUp()
        engine = AccountingEngine.shared
        engine.reset()
    }
    
    /// Scenario 1: Rounding Error Check
    /// 100 partial buys of 1.5 shares at varying prices to check for floating point drift.
    func testHighFrequencyPartialFills() async {
        let trade = Trade(ticker: "STRESS")
        var expectedTotalCost = 0.0
        let quantityPerFill = 1.5
        
        for i in 0..<100 {
            let price = 100.0 + Double(i) * 0.1 // Incremental prices
            let fill = Execution(price: price, quantity: quantityPerFill, type: .buy, date: Date())
            trade.executions.append(fill)
            expectedTotalCost += (price * quantityPerFill)
        }
        
        let expectedVwap = expectedTotalCost / (100.0 * quantityPerFill)
        
        engine.update(trades: [trade], startingBalance: 10000)
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s for heavy load
        
        let math = engine.mathForTrade(trade.id)
        XCTAssertNotNil(math)
        XCTAssertEqual(math?.vwap ?? 0, expectedVwap, accuracy: 0.0001, "VWAP should not drift after 100 partials")
        XCTAssertEqual(math?.effectiveQuantity, 150.0, "Total quantity should be exactly 150.0")
    }
    
    /// Scenario 2: Ticker Isolation
    /// Two separate trades for same ticker (AAPL) should never leak into each other.
    func testTickerIsolation() async {
        let tradeA = Trade(ticker: "AAPL")
        tradeA.executions = [
            Execution(price: 150, quantity: 10, type: .buy, date: Date().addingTimeInterval(-86400)),
            Execution(price: 160, quantity: 10, type: .sell, date: Date().addingTimeInterval(-86300))
        ]
        tradeA.status = .closed // Pnl: +100
        
        let tradeB = Trade(ticker: "AAPL")
        tradeB.executions = [
            Execution(price: 100, quantity: 10, type: .buy, date: Date())
        ]
        tradeB.status = .open // Still open
        
        engine.update(trades: [tradeA, tradeB], startingBalance: 1000)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let mathA = engine.mathForTrade(tradeA.id)
        let mathB = engine.mathForTrade(tradeB.id)
        
        XCTAssertEqual(mathA?.totalPnl, 100.0)
        XCTAssertEqual(mathB?.realizedPnl ?? 0, 0.0, "Trade B should NOT inherit realized PnL from Trade A just because they share a ticker.")
    }
    
    /// Scenario 3: Bulk Engine Update
    /// Spawning 100 trades to check engine stability.
    func testBulkEngineUpdate() async {
        var bulkTrades: [Trade] = []
        for i in 0..<100 {
            let t = Trade(ticker: "T\(i)")
            t.executions = [Execution(price: 100, quantity: 1, type: .buy, date: Date())]
            bulkTrades.append(t)
        }
        
        engine.update(trades: bulkTrades, startingBalance: 10000)
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s for bulk update
        
        XCTAssertEqual(engine.portfolioState.openTradesCount, 100)
        XCTAssertEqual(engine.portfolioState.totalExposure, 10000.0, "100 trades * 1 share * $100 = $10,000")
    }
    
    /// Scenario 4: Simultaneous Long/Short
    /// Liquidity math must handle opposing directions correctly.
    func testSimultaneousLongShort() async {
        let long = Trade(ticker: "NVDA", side: .long)
        long.executions = [Execution(price: 1000, quantity: 1, type: .buy, date: Date())] // Exposure: $1000
        
        let short = Trade(ticker: "SPY", side: .short)
        short.executions = [Execution(price: 500, quantity: 2, type: .sell, date: Date())] // Exposure: $1000
        
        // Inject mock quotes to match entry prices (unrealized = 0)
        engine.testOnly_setQuote(ticker: "NVDA", price: 1000.0)
        engine.testOnly_setQuote(ticker: "SPY", price: 500.0)
        
        engine.update(trades: [long, short], startingBalance: 10000)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let state = engine.portfolioState
        XCTAssertEqual(state.totalExposure, 2000.0, "Both Long and Short contribute to total risk exposure")
        XCTAssertEqual(state.netLiquidity, 10000.0, "Unrealized is 0, so Liquidity remains $10,000")
    }
}
