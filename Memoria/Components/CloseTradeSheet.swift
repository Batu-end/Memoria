//
//  CloseTradeSheet.swift
//  Memoria
//
//  Quick-close confirmation — closes entire position at market price.
//

import SwiftUI
import SwiftData

struct CloseTradeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trade: Trade
    let marketPrice: Double?

    @State private var dateClosed: Date = Date()

    private var effectiveQty: Double {
        let opening = trade.executions.filter { $0.type == (trade.side == .long ? .buy : .sell) }.reduce(0) { $0 + $1.quantity }
        let closing = trade.executions.filter { $0.type == (trade.side == .long ? .sell : .buy) }.reduce(0) { $0 + $1.quantity }
        let qty = opening - closing
        return qty > 0 ? qty : (trade.quantity ?? 0)
    }

    private var exitPrice: Double {
        marketPrice ?? trade.math?.vwap ?? trade.entryPrice ?? 0
    }

    private var vwap: Double {
        let openingExecs = trade.side == .long ?
            trade.executions.filter { $0.type == .buy } :
            trade.executions.filter { $0.type == .sell }
        let totalQty = openingExecs.reduce(0) { $0 + $1.quantity }
        let totalBasis = openingExecs.reduce(0) { $0 + ($1.price * $1.quantity) }
        return totalQty > 0 ? totalBasis / totalQty : (trade.entryPrice ?? 0)
    }

    private var realizedPnl: Double {
        let direction: Double = trade.side == .short ? -1 : 1
        return (exitPrice - vwap) * effectiveQty * direction
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Close Position")
                    .font(.system(size: 14, weight: .bold))
                Text("\(trade.ticker) • \(trade.side.rawValue)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.1))

            VStack(spacing: 16) {
                // P&L card
                VStack(spacing: 6) {
                    Text("REALIZED P&L")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    Text(realizedPnl >= 0 ? "+\(realizedPnl, specifier: "%.2f")" : "\(realizedPnl, specifier: "%.2f")")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(realizedPnl >= 0 ? Color.green : Color.red)
                        .shadow(color: (realizedPnl >= 0 ? Color.green : Color.red).opacity(0.4), radius: 8)

                    Text("Selling \(String(format: "%.4g", effectiveQty)) shares at \(exitPrice, format: .currency(code: "USD"))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background((realizedPnl >= 0 ? Color.green : Color.red).opacity(0.07))
                .cornerRadius(10)

                // Date
                HStack {
                    Text("DATE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $dateClosed, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                // Buttons
                HStack(spacing: 10) {
                    Button("Go Back") { dismiss() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        .buttonStyle(.plain)

                    Button(action: closeTrade) {
                        Text("Confirm Close")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .onMouseBackButton()
        .background(.ultraThinMaterial)
    }

    private func closeTrade() {
        let closeExecType: ExecutionType = trade.side == .long ? .sell : .buy
        trade.executions.append(Execution(price: exitPrice, quantity: effectiveQty, type: closeExecType, date: dateClosed))
        trade.exitPrice = exitPrice
        trade.dateClosed = dateClosed
        trade.status = .closed

        AnalyticsService.shared.log(
            .tradeClosed,
            details: "Ticker: \(trade.ticker), P&L: \(String(format: "%.2f", realizedPnl))",
            context: modelContext
        )
        dismiss()
    }
}
