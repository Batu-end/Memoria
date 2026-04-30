import XCTest
import SwiftData
@testable import Memoria

// MARK: - Helpers

private extension AccountingEngineTests {
    /// Wait for the engine's background Task to write results back to MainActor.
    func settle() async {
        try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms
    }

    func makeLong(_ ticker: String, buys: [(price: Double, qty: Double)], sells: [(price: Double, qty: Double)] = [], status: TradeStatus = .open) -> Trade {
        let t = Trade(ticker: ticker, side: .long)
        t.status = status
        for b in buys { t.executions.append(Execution(price: b.price, quantity: b.qty, type: .buy)) }
        for s in sells { t.executions.append(Execution(price: s.price, quantity: s.qty, type: .sell)) }
        return t
    }

    func makeShort(_ ticker: String, sells: [(price: Double, qty: Double)], buys: [(price: Double, qty: Double)] = [], status: TradeStatus = .open) -> Trade {
        let t = Trade(ticker: ticker, side: .short)
        t.status = status
        for s in sells { t.executions.append(Execution(price: s.price, quantity: s.qty, type: .sell)) }
        for b in buys { t.executions.append(Execution(price: b.price, quantity: b.qty, type: .buy)) }
        return t
    }
}

// MARK: - Test Suite

@MainActor
final class AccountingEngineTests: XCTestCase {

    var engine: AccountingEngine!

    override func setUp() {
        super.setUp()
        engine = AccountingEngine.shared
        engine.reset()
    }

    // MARK: VWAP

    func testVwap_singleBuy() async {
        let t = makeLong("AAPL", buys: [(150, 10)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, 150.0, accuracy: 0.0001)
    }

    func testVwap_scaleIn_twoFills() async {
        // Buy 10 @ 100 + 10 @ 120 → VWAP = (1000 + 1200) / 20 = 110
        let t = makeLong("TSLA", buys: [(100, 10), (120, 10)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, 110.0, accuracy: 0.0001)
        XCTAssertEqual(m?.effectiveQuantity ?? 0, 20.0, accuracy: 0.0001)
    }

    func testVwap_scaleIn_unequalFills() async {
        // Buy 5 @ 100 + 15 @ 140 → VWAP = (500 + 2100) / 20 = 130
        let t = makeLong("NVDA", buys: [(100, 5), (140, 15)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, 130.0, accuracy: 0.0001)
    }

    func testVwap_partialSell_doesNotAffectVwap() async {
        // Selling doesn't change the average cost of what you bought
        let t = makeLong("MSFT", buys: [(100, 10), (120, 10)], sells: [(130, 5)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, 110.0, accuracy: 0.0001, "VWAP must stay 110 regardless of partial sells")
        XCTAssertEqual(m?.effectiveQuantity ?? 0, 15.0, accuracy: 0.0001)
    }

    // MARK: Realized P&L — Long

    func testRealized_longWin() async {
        // Buy 10 @ 100, sell 10 @ 110 → realized = +100
        let t = makeLong("AAPL", buys: [(100, 10)], sells: [(110, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(m?.totalPnl ?? 0, 100.0, accuracy: 0.001)
        XCTAssertTrue(m?.winStatus == true)
    }

    func testRealized_longLoss() async {
        // Buy 10 @ 100, sell 10 @ 90 → realized = -100
        let t = makeLong("AAPL", buys: [(100, 10)], sells: [(90, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, -100.0, accuracy: 0.001)
        XCTAssertTrue(m?.winStatus == false)
    }

    func testRealized_longScaleIn_fullClose() async {
        // Buy 100 @ $10, buy 100 @ $12, sell all 200 @ $13
        // VWAP = 11, realized = (13-11)*200 = 400
        let t = makeLong("SPY", buys: [(10, 100), (12, 100)], sells: [(13, 200)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, 11.0, accuracy: 0.0001)
        XCTAssertEqual(m?.realizedPnl ?? 0, 400.0, accuracy: 0.001)
        XCTAssertEqual(m?.effectiveQuantity ?? 0, 0.0, accuracy: 0.0001)
    }

    func testRealized_longPartialClose() async {
        // Buy 10 @ 100, sell 5 @ 120 → realized = (120-100)*5 = 100, remaining = 5
        let t = makeLong("GOOG", buys: [(100, 10)], sells: [(120, 5)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(m?.effectiveQuantity ?? 0, 5.0, accuracy: 0.0001)
    }

    func testRealized_longMultipleSells() async {
        // Buy 10 @ 100; sell 4 @ 110 (+40), sell 6 @ 90 (-60) → realized = -20
        let t = makeLong("META", buys: [(100, 10)], sells: [(110, 4), (90, 6)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, -20.0, accuracy: 0.001)
        XCTAssertTrue(m?.winStatus == false)
    }

    // MARK: Realized P&L — Short

    func testRealized_shortWin() async {
        // Short 10 @ 100, cover 10 @ 80 → profit = (100-80)*10 = 200
        let t = makeShort("AMZN", sells: [(100, 10)], buys: [(80, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, 200.0, accuracy: 0.001)
        XCTAssertTrue(m?.winStatus == true)
    }

    func testRealized_shortLoss() async {
        // Short 10 @ 100, cover 10 @ 120 → loss = (100-120)*10 = -200
        let t = makeShort("NFLX", sells: [(100, 10)], buys: [(120, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, -200.0, accuracy: 0.001)
        XCTAssertTrue(m?.winStatus == false)
    }

    func testRealized_shortScaleIn() async {
        // Short 10 @ 200, add short 10 @ 180 → VWAP = 190
        // Cover all 20 @ 160 → profit = (190-160)*20 = 600
        let t = makeShort("TSLA", sells: [(200, 10), (180, 10)], buys: [(160, 20)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, 190.0, accuracy: 0.0001)
        XCTAssertEqual(m?.realizedPnl ?? 0, 600.0, accuracy: 0.001)
    }

    // MARK: Unrealized P&L (requires injected quote)

    func testUnrealized_long_profit() async {
        // Buy 10 @ 100, live price 110 → unrealized = +100
        let t = makeLong("LIVE", buys: [(100, 10)])
        engine.testOnly_setQuote(ticker: "LIVE", price: 110.0)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.unrealizedPnl ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(m?.totalPnl ?? 0, 100.0, accuracy: 0.001)
    }

    func testUnrealized_long_loss() async {
        let t = makeLong("DOWN", buys: [(100, 10)])
        engine.testOnly_setQuote(ticker: "DOWN", price: 85.0)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.unrealizedPnl ?? 0, -150.0, accuracy: 0.001)
    }

    func testUnrealized_short_profit() async {
        // Short 10 @ 100, live price drops to 90 → unrealized = +100
        let t = makeShort("SHRTU", sells: [(100, 10)])
        engine.testOnly_setQuote(ticker: "SHRTU", price: 90.0)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.unrealizedPnl ?? 0, 100.0, accuracy: 0.001)
    }

    func testUnrealized_noQuote_isZero() async {
        // Without a live quote the engine cannot compute unrealized
        let t = makeLong("NOQUOTE", buys: [(100, 10)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.unrealizedPnl ?? 0, 0.0, accuracy: 0.0001)
    }

    // MARK: Open trade — partial sell + live unrealized

    func testOpenTrade_partialSellPlusUnrealized() async {
        // Buy 10 @ 100
        // Sell 5 @ 120  → realized = +100
        // Live price 110 → unrealized on remaining 5 = (110-100)*5 = +50
        // totalPnl = 150
        let t = makeLong("COMBO", buys: [(100, 10)], sells: [(120, 5)])
        engine.testOnly_setQuote(ticker: "COMBO", price: 110.0)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.realizedPnl ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(m?.unrealizedPnl ?? 0, 50.0, accuracy: 0.001)
        XCTAssertEqual(m?.totalPnl ?? 0, 150.0, accuracy: 0.001)
    }

    // MARK: Position Size

    func testPositionSize_singleBuy() async {
        // Buy 100 @ $50 → positionSize = 5000
        let t = makeLong("SIZE", buys: [(50, 100)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.positionSize ?? 0, 5_000.0, accuracy: 0.01)
    }

    func testPositionSize_afterScaleIn() async {
        // Buy 100 @ $10, buy 100 @ $12 → VWAP $11, effectiveQty 200 → positionSize = 2200
        let t = makeLong("SCALE", buys: [(10, 100), (12, 100)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.positionSize ?? 0, 2_200.0, accuracy: 0.01)
    }

    func testPositionSize_afterPartialSell() async {
        // Buy 10 @ $100, sell 5 → effectiveQty 5, VWAP 100 → positionSize = 500
        let t = makeLong("TRIM", buys: [(100, 10)], sells: [(110, 5)])
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.positionSize ?? 0, 500.0, accuracy: 0.01)
    }

    // MARK: Percent Return

    func testPercentReturn_closedWin() async {
        // Buy 10 @ $100 (cost basis $1000), sell @ $110 (pnl +100) → return = 10%
        let t = makeLong("RETW", buys: [(100, 10)], sells: [(110, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.percentReturn ?? 0, 10.0, accuracy: 0.001)
    }

    func testPercentReturn_closedLoss() async {
        // Buy 10 @ $100, sell @ $80 → pnl = -200, return = -20%
        let t = makeLong("RETL", buys: [(100, 10)], sells: [(80, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.percentReturn ?? 0, -20.0, accuracy: 0.001)
    }

    // MARK: Win / Loss Status

    func testWinStatus_breakeven_isWin() async {
        let t = makeLong("BE", buys: [(100, 10)], sells: [(100, 10)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        XCTAssertTrue(engine.mathForTrade(t.id)?.winStatus == true, "Breakeven should be treated as a win")
    }

    func testWinStatus_oneCentProfit_isWin() async {
        let t = makeLong("CENT", buys: [(100.00, 1)], sells: [(100.01, 1)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        XCTAssertTrue(engine.mathForTrade(t.id)?.winStatus == true)
    }

    func testWinStatus_oneCentLoss_isLoss() async {
        let t = makeLong("CENTL", buys: [(100.01, 1)], sells: [(100.00, 1)], status: .closed)
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        XCTAssertTrue(engine.mathForTrade(t.id)?.winStatus == false)
    }

    // MARK: Portfolio Aggregation

    func testPortfolio_winRate() async {
        func closed(_ ticker: String, buy: Double, sell: Double) -> Trade {
            makeLong(ticker, buys: [(buy, 10)], sells: [(sell, 10)], status: .closed)
        }
        // 3 wins, 2 losses → 60%
        let trades: [Trade] = [
            closed("W1", buy: 100, sell: 110),
            closed("W2", buy: 100, sell: 105),
            closed("W3", buy: 100, sell: 120),
            closed("L1", buy: 100, sell: 90),
            closed("L2", buy: 100, sell: 95),
        ]
        engine.update(trades: trades, startingBalance: 10_000)
        await settle()
        let s = engine.portfolioState
        XCTAssertEqual(s.winCount, 3)
        XCTAssertEqual(s.lossCount, 2)
        XCTAssertEqual(s.winRate, 60.0, accuracy: 0.001)
    }

    func testPortfolio_profitFactor() async {
        // Win $100, lose $50 → profit factor = 2.0
        let w = makeLong("PFW", buys: [(100, 10)], sells: [(110, 10)], status: .closed)  // +100
        let l = makeLong("PFL", buys: [(100, 10)], sells: [(95, 10)], status: .closed)   // -50
        engine.update(trades: [w, l], startingBalance: 10_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.profitFactor, 2.0, accuracy: 0.001)
    }

    func testPortfolio_totalPnl() async {
        let w = makeLong("T1", buys: [(100, 10)], sells: [(110, 10)], status: .closed)   // +100
        let l = makeLong("T2", buys: [(200, 5)],  sells: [(180, 5)],  status: .closed)   // -100
        engine.update(trades: [w, l], startingBalance: 5_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.totalPnl, 0.0, accuracy: 0.001)
    }

    func testPortfolio_netLiquidity() async {
        // Two closed trades netting +200, balance 1000 → net liq = 1200
        let w1 = makeLong("NL1", buys: [(100, 10)], sells: [(120, 10)], status: .closed) // +200
        engine.update(trades: [w1], startingBalance: 1_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.netLiquidity, 1_200.0, accuracy: 0.001)
    }

    func testPortfolio_unrealizedExposure() async {
        let a = makeLong("EXA", buys: [(100, 10)])   // exposure 1000
        let b = makeLong("EXB", buys: [(200, 5)])    // exposure 1000
        engine.update(trades: [a, b], startingBalance: 10_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.totalExposure, 2_000.0, accuracy: 0.01)
    }

    func testPortfolio_openAndClosedSeparated() async {
        let open   = makeLong("OPEN",   buys: [(100, 1)])
        let closed = makeLong("CLOSED", buys: [(100, 1)], sells: [(110, 1)], status: .closed)
        engine.update(trades: [open, closed], startingBalance: 10_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.openTradesCount, 1)
        XCTAssertEqual(engine.portfolioState.closedTradesCount, 1)
    }

    // MARK: Edge Cases

    func testEdge_zeroQuantityFallback() async {
        // Trade with no executions — should fall back to trade.quantity (0 here)
        let t = Trade(ticker: "EMPTY")
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.effectiveQuantity ?? 0, 0.0)
        XCTAssertEqual(m?.totalPnl ?? 0.0, 0.0, accuracy: 0.0001)
    }

    func testEdge_taskCancellationSafety() async {
        // Rapid sequential updates should not crash; last one wins
        for i in 1...10 {
            let t = makeLong("RAPID", buys: [(Double(i) * 10, Double(i))])
            engine.update(trades: [t], startingBalance: 10_000)
        }
        await settle()
        // If we get here without crashing, cancellation is handled correctly
        XCTAssertNotNil(engine.portfolioState)
    }

    func testEdge_tickerIsolation() async {
        // Two trades in same ticker must never share state
        let t1 = makeLong("AAPL", buys: [(150, 10)], sells: [(160, 10)], status: .closed) // +100
        let t2 = makeLong("AAPL", buys: [(100, 10)])                                      // separate open trade
        engine.update(trades: [t1, t2], startingBalance: 10_000)
        await settle()
        XCTAssertEqual(engine.mathForTrade(t1.id)?.totalPnl ?? 0, 100.0, accuracy: 0.001)
        XCTAssertEqual(engine.mathForTrade(t2.id)?.realizedPnl ?? 0, 0.0, accuracy: 0.001)
    }

    func testEdge_highFrequencyPartialFills() async {
        // 100 partial buys of 1.5 shares — checks for floating-point drift
        let t = Trade(ticker: "HF")
        var expectedCost = 0.0
        for i in 0..<100 {
            let price = 100.0 + Double(i) * 0.1
            t.executions.append(Execution(price: price, quantity: 1.5, type: .buy))
            expectedCost += price * 1.5
        }
        let expectedVwap = expectedCost / (100 * 1.5)
        engine.update(trades: [t], startingBalance: 100_000)
        await settle()
        let m = engine.mathForTrade(t.id)
        XCTAssertEqual(m?.vwap ?? 0, expectedVwap, accuracy: 0.0001)
        XCTAssertEqual(m?.effectiveQuantity ?? 0, 150.0, accuracy: 0.0001)
    }

    // MARK: Max Drawdown

    func testMaxDrawdown() async {
        // Win $1000 (balance peaks at 2000), then lose $500 (balance 1500)
        // DD = (2000 - 1500) / 2000 = 25%
        let win = makeLong("W", buys: [(100, 10)], sells: [(200, 10)], status: .closed)
        let loss = makeLong("L", buys: [(100, 10)], sells: [(50, 10)], status: .closed)
        // Dates must be ordered for equity curve
        loss.executions.forEach { $0.date = Date().addingTimeInterval(3600) }
        engine.update(trades: [win, loss], startingBalance: 1_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.maxDrawdown, 25.0, accuracy: 0.1)
    }

    // MARK: Daily P&L Aggregator

    func testDailyPnl_singleTrade() async {
        let today = Calendar.current.startOfDay(for: Date())
        let t = makeLong("DAY1", buys: [(100, 10)], sells: [(110, 10)], status: .closed)
        t.dateClosed = today
        engine.update(trades: [t], startingBalance: 10_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.dailyPnl[today] ?? 0, 100.0, accuracy: 0.001)
    }

    func testDailyPnl_multipleTradesSameDay_summed() async {
        let today = Calendar.current.startOfDay(for: Date())
        let t1 = makeLong("D1", buys: [(100, 10)], sells: [(110, 10)], status: .closed) // +100
        let t2 = makeLong("D2", buys: [(200, 5)],  sells: [(180, 5)],  status: .closed) // -100
        t1.dateClosed = today
        t2.dateClosed = today
        engine.update(trades: [t1, t2], startingBalance: 10_000)
        await settle()
        XCTAssertEqual(engine.portfolioState.dailyPnl[today] ?? 0, 0.0, accuracy: 0.001,
                       "Two trades on the same day should net to a single value")
    }

    func testDailyPnl_separateDays_separateKeys() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.startOfDay(for: Date().addingTimeInterval(-86400))
        let t1 = makeLong("DD1", buys: [(100, 10)], sells: [(110, 10)], status: .closed) // +100 today
        let t2 = makeLong("DD2", buys: [(100, 10)], sells: [(90, 10)],  status: .closed) // -100 yesterday
        t1.dateClosed = today
        t2.dateClosed = yesterday
        engine.update(trades: [t1, t2], startingBalance: 10_000)
        await settle()
        let daily = engine.portfolioState.dailyPnl
        XCTAssertEqual(daily[today] ?? 0,     100.0,  accuracy: 0.001)
        XCTAssertEqual(daily[yesterday] ?? 0, -100.0, accuracy: 0.001)
        XCTAssertEqual(daily.count, 2)
    }

    func testDailyPnl_openTrades_excluded() async {
        let today = Calendar.current.startOfDay(for: Date())
        let open   = makeLong("OPEN", buys: [(100, 10)])                                 // open — should not appear
        let closed = makeLong("CLSD", buys: [(100, 10)], sells: [(120, 10)], status: .closed) // +200
        closed.dateClosed = today
        engine.update(trades: [open, closed], startingBalance: 10_000)
        await settle()
        let daily = engine.portfolioState.dailyPnl
        XCTAssertEqual(daily.count, 1, "Open trades must not appear in dailyPnl")
        XCTAssertEqual(daily[today] ?? 0, 200.0, accuracy: 0.001)
    }
}
