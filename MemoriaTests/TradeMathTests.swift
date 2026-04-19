import XCTest
@testable import Memoria

final class TradeMathTests: XCTestCase {

    func testVwapCalculation() {
        let trade = Trade(ticker: "AAPL", side: .long)
        
        // Scenario: Buy 100 @ 10, then 100 @ 20
        let buy1 = Execution(price: 10, quantity: 100, type: .buy, date: Date())
        let buy2 = Execution(price: 20, quantity: 100, type: .buy, date: Date())
        
        trade.executions = [buy1, buy2]
        
        XCTAssertEqual(trade.vwap, 15.0, "VWAP should be the average of entries: (100*10 + 100*20) / 200 = 15")
        XCTAssertEqual(trade.effectiveQuantity, 200, "Effective quantity should be 200")
    }
    
    func testRealizedPnlOnPartialExit() {
        let trade = Trade(ticker: "TSLA", side: .long)
        
        // Step 1: Buy 200 @ $100 (Total cost $20,000)
        let entry = Execution(price: 100, quantity: 200, type: .buy, date: Date())
        trade.executions = [entry]
        
        // Step 2: Partial Exit 100 @ $150
        // We profit ($150 - $100) * 100 = $5,000
        let partialExit = Execution(price: 150, quantity: 100, type: .sell, date: Date())
        trade.executions.append(partialExit)
        
        XCTAssertEqual(trade.realizedPnl, 5000.0, "Realized P&L should be $5,000 after selling half at $150")
        XCTAssertEqual(trade.effectiveQuantity, 100, "Effective quantity should drop to 100")
        
        // Step 3: Total P&L when current price (exitPrice) is $160
        // Unrealized = ($160 - $100) * 100 = $6,000
        // Total = Realized ($5k) + Unrealized ($6k) = $11,000
        trade.exitPrice = 160
        XCTAssertEqual(trade.pnl, 11000.0, "Total P&L should be Realized + Unrealized")
    }
    
    func testShortPositionMath() {
        let trade = Trade(ticker: "SPY", side: .short)
        
        // Step 1: Short 100 @ $400
        let entry = Execution(price: 400, quantity: 100, type: .buy, date: Date()) // Model uses .buy for entry regardless of side
        trade.executions = [entry]
        
        // Step 2: Cover half 50 @ $350 (Price went down, this is a profit)
        // Profit = ($400 - $350) * 50 = $2,500
        let cover = Execution(price: 350, quantity: 50, type: .sell, date: Date())
        trade.executions.append(cover)
        
        XCTAssertEqual(trade.realizedPnl, 2500.0, "Short profit should be positive when price drops")
    }
    
    func testRMultipleWithScales() {
        let trade = Trade(ticker: "AMD", side: .long)
        trade.stopLoss = 90
        
        // Entry: 100 @ $100. Risk = $10/share. Total Risk $1,000.
        let entry = Execution(price: 100, quantity: 100, type: .buy, date: Date())
        trade.executions = [entry]
        
        // Scenario A: P&L is $1,000. R-Multiple should be 1.0.
        trade.exitPrice = 110
        XCTAssertEqual(trade.rMultiple, 1.0, "R-Multiple should be exactly 1.0 when P&L equals initial risk")
        
        // Scenario B: We scale in. Buy 100 more @ $110.
        // New VWAP = $105. Total Risk = (105 - 90) * 200 = $3,000.
        // Wait, my implementation uses ORIGINAL RISK = (vwap_now - sl) * total_qty_bought
        let entry2 = Execution(price: 110, quantity: 100, type: .buy, date: Date())
        trade.executions.append(entry2) // VWAP is now 105. Total Qty is 200.
        
        // P&L at $120 = (120 - 105) * 200 = $3,000.
        // Total Risk = (105 - 90) * 200 = $3,000.
        // R-Multiple should be 1.0.
        trade.exitPrice = 120
        XCTAssertEqual(trade.pnl, 3000.0)
        XCTAssertEqual(trade.rMultiple, 1.0, "R-Multiple should adapt to total capital at risk")
    }
}
