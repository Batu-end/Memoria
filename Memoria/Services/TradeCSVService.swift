//
//  TradeCSVService.swift
//  Memoria
//
//  Round-trippable CSV for trades and their executions, so a journal can survive
//  a reinstall or an incompatible model change.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Wraps exported CSV text for `fileExporter`.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Encodes and decodes trades as CSV.
///
/// One row per execution, with the owning trade's fields repeated on each row.
/// Executions are what the accounting engine derives VWAP and P&L from, so a
/// format that dropped them would re-import to the wrong numbers. Trades that
/// have no executions yet still get a single row with the execution columns empty.
enum TradeCSVService {

    /// Columns, in order. Changing this order breaks older exports, so append only.
    static let headers = [
        "trade_id", "ticker", "side", "status", "asset_type",
        "date_added", "date_closed",
        "entry_price", "exit_price", "quantity",
        "stop_loss", "take_profit",
        "strategy", "confidence_score", "rules_followed", "notes",
        "exec_type", "exec_price", "exec_quantity", "exec_date",
    ]

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// `rulesFollowed` is a list inside a single cell; this separates its entries.
    private static let ruleSeparator = "|"

    // MARK: - Export

    static func export(_ trades: [Trade]) -> String {
        var rows = [headers.joined(separator: ",")]

        for trade in trades.sorted(by: { $0.dateAdded < $1.dateAdded }) {
            if trade.executions.isEmpty {
                rows.append(row(for: trade, execution: nil))
            } else {
                for execution in trade.executions.sorted(by: { $0.date < $1.date }) {
                    rows.append(row(for: trade, execution: execution))
                }
            }
        }

        return rows.joined(separator: "\n")
    }

    private static func row(for trade: Trade, execution: Execution?) -> String {
        let fields = [
            trade.id.uuidString,
            trade.ticker,
            trade.side.rawValue,
            trade.status.rawValue,
            trade.assetType.rawValue,
            dateFormatter.string(from: trade.dateAdded),
            trade.dateClosed.map { dateFormatter.string(from: $0) } ?? "",
            number(trade.entryPrice),
            number(trade.exitPrice),
            number(trade.quantity),
            number(trade.stopLoss),
            number(trade.takeProfit),
            trade.strategy ?? "",
            String(trade.confidenceScore),
            trade.rulesFollowed.joined(separator: ruleSeparator),
            trade.notes ?? "",
            execution?.type.rawValue ?? "",
            execution.map { String($0.price) } ?? "",
            execution.map { String($0.quantity) } ?? "",
            execution.map { dateFormatter.string(from: $0.date) } ?? "",
        ]
        return fields.map(escape).joined(separator: ",")
    }

    private static func number(_ value: Double?) -> String {
        value.map { String($0) } ?? ""
    }

    /// Quotes a field only when it would otherwise break the row.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - Import

    enum ImportError: LocalizedError {
        case empty
        case missingColumns([String])

        var errorDescription: String? {
            switch self {
            case .empty:
                return "That file has no rows to import."
            case let .missingColumns(names):
                return "That file is missing required columns: \(names.joined(separator: ", "))."
            }
        }
    }

    /// Rebuilds trades from CSV text. Rows sharing a `trade_id` are folded back into
    /// one trade carrying all of its executions.
    ///
    /// Returned trades are detached — the caller inserts them into a context and
    /// assigns a portfolio. Trade ids are regenerated so importing alongside the
    /// existing journal can never collide with a trade already there.
    static func makeTrades(from csv: String) throws -> [Trade] {
        let rows = parseRows(csv)
        guard let header = rows.first, rows.count > 1 else { throw ImportError.empty }

        var index: [String: Int] = [:]
        for (position, name) in header.enumerated() {
            index[name.trimmingCharacters(in: .whitespaces)] = position
        }

        let required = ["ticker", "side", "status", "date_added"]
        let missing = required.filter { index[$0] == nil }
        guard missing.isEmpty else { throw ImportError.missingColumns(missing) }

        func field(_ row: [String], _ name: String) -> String {
            guard let position = index[name], position < row.count else { return "" }
            return row[position]
        }

        var byKey: [String: Trade] = [:]
        var order: [String] = []

        for row in rows.dropFirst() {
            let ticker = field(row, "ticker").trimmingCharacters(in: .whitespaces)
            guard !ticker.isEmpty else { continue }

            // Group by the file's own id when present, otherwise treat each row as
            // its own trade rather than silently merging unrelated ones.
            let key = field(row, "trade_id").isEmpty ? UUID().uuidString : field(row, "trade_id")

            let trade: Trade
            if let existing = byKey[key] {
                trade = existing
            } else {
                trade = Trade(
                    ticker: ticker.uppercased(),
                    status: TradeStatus(rawValue: field(row, "status")) ?? .open,
                    side: TradeSide(rawValue: field(row, "side")) ?? .long,
                    assetType: AssetType(rawValue: field(row, "asset_type")) ?? .stock
                )
                trade.dateAdded = dateFormatter.date(from: field(row, "date_added")) ?? Date()
                trade.dateClosed = dateFormatter.date(from: field(row, "date_closed"))
                trade.entryPrice = Double(field(row, "entry_price"))
                trade.exitPrice = Double(field(row, "exit_price"))
                trade.quantity = Double(field(row, "quantity"))
                trade.stopLoss = Double(field(row, "stop_loss"))
                trade.takeProfit = Double(field(row, "take_profit"))

                let strategy = field(row, "strategy")
                trade.strategy = strategy.isEmpty ? nil : strategy

                let notes = field(row, "notes")
                trade.notes = notes.isEmpty ? nil : notes

                trade.confidenceScore = Int(field(row, "confidence_score")) ?? 0
                trade.rulesFollowed = field(row, "rules_followed")
                    .split(separator: Character(ruleSeparator))
                    .map(String.init)

                byKey[key] = trade
                order.append(key)
            }

            if let price = Double(field(row, "exec_price")),
               let quantity = Double(field(row, "exec_quantity")) {
                let execution = Execution(
                    price: price,
                    quantity: quantity,
                    type: ExecutionType(rawValue: field(row, "exec_type")) ?? .buy,
                    date: dateFormatter.date(from: field(row, "exec_date")) ?? trade.dateAdded
                )
                trade.executions.append(execution)
            }
        }

        return order.compactMap { byKey[$0] }
    }

    // MARK: - Parsing

    /// Splits CSV into rows of fields, honouring quoted fields that contain commas,
    /// escaped quotes, or newlines.
    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        func endField() {
            fields.append(current)
            current = ""
        }

        func endRow() {
            endField()
            // Skip rows that are entirely empty, e.g. a trailing newline.
            if fields.contains(where: { !$0.isEmpty }) { rows.append(fields) }
            fields = []
        }

        while let character = pending ?? iterator.next() {
            pending = nil

            if inQuotes {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { current.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(character)
                }
                continue
            }

            switch character {
            case "\"": inQuotes = true
            case ",": endField()
            case "\n": endRow()
            case "\r": break // handled by the \n that follows
            default: current.append(character)
            }
        }

        if !current.isEmpty || !fields.isEmpty { endRow() }
        return rows
    }
}
