//
//  CloseTradeSheet.swift
//  Memoria
//
//  Sheet for closing an open trade — enter exit price and confirm.
//

import SwiftUI
import SwiftData

struct CloseTradeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let trade: Trade
    let initialPrice: Double?
    
    @State private var exitPriceString: String = ""
    @State private var dateClosed: Date = Date()
    
    init(trade: Trade, initialPrice: Double? = nil) {
        self.trade = trade
        self.initialPrice = initialPrice
        // Set initial state from the passed price if available
        if let price = initialPrice {
            _exitPriceString = State(initialValue: String(format: "%.2f", price))
        }
    }
    
    private var exitPrice: Double? {
        Double(exitPriceString)
    }
    
    private var isValid: Bool {
        exitPrice != nil && (exitPrice ?? 0) > 0
    }
    
    /// Instant calculation from executions to ensure UI responsiveness
    private var realTimeEffectiveQuantity: Double {
        let opening = trade.executions.filter { $0.type == (trade.side == .long ? .buy : .sell) }.reduce(0) { $0 + $1.quantity }
        let closing = trade.executions.filter { $0.type == (trade.side == .long ? .sell : .buy) }.reduce(0) { $0 + $1.quantity }
        return opening - closing
    }
    
    /// Preview P&L before confirming
    private var previewPnl: Double? {
        guard let exit = exitPrice else { return nil }
        
        // Calculate dynamic VWAP from executions for accuracy
        let openingExecs = trade.side == .long ? 
            trade.executions.filter { $0.type == .buy } : 
            trade.executions.filter { $0.type == .sell }
        
        let totalOpeningQty = openingExecs.reduce(0) { $0 + $1.quantity }
        let totalOpeningBasis = openingExecs.reduce(0) { $0 + ($1.price * $1.quantity) }
        let vwap = totalOpeningQty > 0 ? totalOpeningBasis / totalOpeningQty : (trade.entryPrice ?? 0)
        
        let direction: Double = (trade.side == .short) ? -1.0 : 1.0
        return (exit - vwap) * realTimeEffectiveQuantity * direction
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Finalize Trade")
                    .font(.system(size: 14, weight: .bold))
                Text("\(trade.ticker) • \(trade.side.rawValue)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(spacing: 16) {
                // Inputs
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXIT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $exitPriceString)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .padding(6)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(4)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DATE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $dateClosed, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                    }
                }
                
                // Result Card
                if let preview = previewPnl {
                    VStack(spacing: 2) {
                        Text(preview >= 0 ? "Potential Profit" : "Potential Loss")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(preview >= 0 ? "+\(preview, specifier: "%.2f")" : "\(preview, specifier: "%.2f")")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(preview >= 0 ? Color.green : Color.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
                
                // Confirm
                Button(action: closeTrade) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm & Close")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isValid ? Color.blue : Color.gray.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }
    
    private func closeTrade() {
        trade.exitPrice = exitPrice
        trade.dateClosed = dateClosed
        trade.status = .closed
        
        AnalyticsService.shared.log(.tradeClosed, details: "Ticker: \(trade.ticker), P&L: \(trade.math?.totalPnl ?? 0)", context: modelContext)
        
        dismiss()
    }
}
