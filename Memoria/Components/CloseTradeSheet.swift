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
    
    @State private var exitPriceString: String = ""
    @State private var dateClosed: Date = Date()
    
    private var exitPrice: Double? {
        Double(exitPriceString)
    }
    
    private var isValid: Bool {
        exitPrice != nil && (exitPrice ?? 0) > 0
    }
    
    /// Preview P&L before confirming
    private var previewPnl: Double? {
        guard let exit = exitPrice, let entry = trade.entryPrice else { return nil }
        let qty = trade.quantity ?? 1.0
        let direction: Double = (trade.side == .short) ? -1.0 : 1.0
        return (exit - entry) * qty * direction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Close Trade")
                    .font(.title2)
                    .bold()
                
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.headline)
                    Text(trade.side.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(trade.side == .long ? Color.green : Color.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((trade.side == .long ? Color.green : Color.red).opacity(0.15))
                        .clipShape(Capsule())
                }
                
                if let entry = trade.entryPrice {
                    Text("Entry: \(entry, format: .currency(code: "USD"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Exit Price Input
            VStack(alignment: .leading, spacing: 10) {
                Text("EXIT PRICE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                
                TextField("0.00", text: $exitPriceString)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                (!exitPriceString.isEmpty && !isValid)
                                    ? AnyShapeStyle(.red)
                                    : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                                lineWidth: 1
                            )
                    )
                
                DatePicker("Date Closed", selection: $dateClosed, displayedComponents: .date)
                    .font(.subheadline)
            }
            
            // P&L Preview
            if let preview = previewPnl {
                VStack(spacing: 4) {
                    Text("Estimated P&L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(preview >= 0 ? "+\(preview, specifier: "%.2f")" : "\(preview, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(preview >= 0 ? Color.green : Color.red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background((preview >= 0 ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Confirm Button
            Button(action: closeTrade) {
                Text("Confirm Close")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: isValid ? [.blue, .purple] : [.gray, .gray],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .opacity(isValid ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 480)
    }
    
    private func closeTrade() {
        trade.exitPrice = exitPrice
        trade.dateClosed = dateClosed
        trade.status = .closed
        
        AnalyticsService.shared.log(.tradeClosed, details: "Ticker: \(trade.ticker), P&L: \(trade.pnl ?? 0)", context: modelContext)
        
        dismiss()
    }
}
