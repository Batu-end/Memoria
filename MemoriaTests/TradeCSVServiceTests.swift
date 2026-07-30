import XCTest
@testable import Memoria

/// The point of the CSV is that a journal survives a reinstall, so these tests care
/// most about round-tripping: export then import must reproduce the same numbers the
/// accounting engine would have produced originally.
@MainActor
final class TradeCSVServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeTrade(
        _ ticker: String,
        side: TradeSide = .long,
        status: TradeStatus = .open,
        executions: [(Double, Double, ExecutionType)] = []
    ) -> Trade {
        let trade = Trade(ticker: ticker, status: status, side: side)
        for (price, quantity, type) in executions {
            trade.executions.append(Execution(price: price, quantity: quantity, type: type))
        }
        return trade
    }

    // MARK: - Export shape

    func testExport_writesHeaderAndOneRowPerExecution() throws {
        let trade = makeTrade("AAPL", executions: [(100, 10, .buy), (120, 10, .sell)])
        let lines = TradeCSVService.export([trade]).split(separator: "\n")

        XCTAssertEqual(lines.first.map(String.init), TradeCSVService.headers.joined(separator: ","))
        XCTAssertEqual(lines.count, 3, "header + one row per execution")
    }

    func testExport_tradeWithoutExecutionsStillGetsARow() throws {
        let lines = TradeCSVService.export([makeTrade("MSFT")]).split(separator: "\n")
        XCTAssertEqual(lines.count, 2, "a trade with no fills must not vanish from the backup")
    }

    // MARK: - Round trip

    func testRoundTrip_preservesExecutionsAndCoreFields() throws {
        let original = makeTrade("NVDA", side: .short, status: .closed,
                                 executions: [(500, 4, .sell), (450, 4, .buy)])
        original.stopLoss = 520
        original.confidenceScore = 4
        original.strategy = "Reversal"

        let restored = try XCTUnwrap(TradeCSVService.makeTrades(from: TradeCSVService.export([original])).first)

        XCTAssertEqual(restored.ticker, "NVDA")
        XCTAssertEqual(restored.side, .short)
        XCTAssertEqual(restored.status, .closed)
        XCTAssertEqual(restored.stopLoss, 520)
        XCTAssertEqual(restored.confidenceScore, 4)
        XCTAssertEqual(restored.strategy, "Reversal")
        XCTAssertEqual(restored.executions.count, 2)
    }

    /// The real contract: the engine must compute the same P&L after a round trip.
    func testRoundTrip_producesIdenticalPnl() async throws {
        let engine = AccountingEngine.shared

        let original = makeTrade("TSLA", status: .closed, executions: [(100, 10, .buy), (130, 10, .sell)])
        engine.reset()
        engine.update(trades: [original], startingBalance: 10_000)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let before = engine.mathForTrade(original.id)?.totalPnl

        let restored = try XCTUnwrap(TradeCSVService.makeTrades(from: TradeCSVService.export([original])).first)
        engine.reset()
        engine.update(trades: [restored], startingBalance: 10_000)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let after = engine.mathForTrade(restored.id)?.totalPnl

        XCTAssertEqual(try XCTUnwrap(before), 300, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(after), try XCTUnwrap(before), accuracy: 0.0001)
    }

    func testRoundTrip_multipleTradesStaySeparate() throws {
        let trades = [
            makeTrade("AAPL", executions: [(100, 5, .buy)]),
            makeTrade("MSFT", executions: [(200, 3, .buy)]),
        ]
        let restored = try TradeCSVService.makeTrades(from: TradeCSVService.export(trades))

        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(Set(restored.map(\.ticker)), ["AAPL", "MSFT"])
    }

    /// Imports must never overwrite a trade already in the journal.
    func testImport_regeneratesIdsSoNothingCollides() throws {
        let original = makeTrade("AMD", executions: [(10, 1, .buy)])
        let restored = try XCTUnwrap(TradeCSVService.makeTrades(from: TradeCSVService.export([original])).first)
        XCTAssertNotEqual(restored.id, original.id)
    }

    // MARK: - Escaping

    func testRoundTrip_survivesCommasQuotesAndNewlinesInNotes() throws {
        let trade = makeTrade("SPY", executions: [(400, 1, .buy)])
        trade.notes = "Broke out, then faded.\nSaid \"wait for retest\" — ignored it."

        let restored = try XCTUnwrap(TradeCSVService.makeTrades(from: TradeCSVService.export([trade])).first)
        XCTAssertEqual(restored.notes, trade.notes)
    }

    func testRoundTrip_preservesRulesList() throws {
        let trade = makeTrade("QQQ", executions: [(300, 2, .buy)])
        trade.rulesFollowed = ["Waited for confirmation", "Sized correctly"]

        let restored = try XCTUnwrap(TradeCSVService.makeTrades(from: TradeCSVService.export([trade])).first)
        XCTAssertEqual(restored.rulesFollowed, trade.rulesFollowed)
    }

    // MARK: - Bad input

    func testImport_rejectsEmptyFile() {
        XCTAssertThrowsError(try TradeCSVService.makeTrades(from: ""))
    }

    func testImport_rejectsFileMissingRequiredColumns() {
        XCTAssertThrowsError(try TradeCSVService.makeTrades(from: "foo,bar\n1,2"))
    }

    /// A blank or malformed line among good ones must be dropped, not imported as a
    /// nameless trade.
    func testImport_skipsRowsWithoutATicker() throws {
        let good = TradeCSVService.export([makeTrade("AAPL", executions: [(100, 5, .buy)])])
        let blankRow = Array(repeating: "", count: TradeCSVService.headers.count).joined(separator: ",")

        let restored = try TradeCSVService.makeTrades(from: good + "\n" + blankRow)

        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.ticker, "AAPL")
    }
}
