//
//  TradeDetailView.swift
//  Memoria
//
//  Full detail view for a single trade. View, edit notes, close trade.
//

import SwiftUI
import SwiftData

struct TradeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var trade: Trade
    
    @State private var showCloseSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                headerSection
                
                // Entry / Exit Details
                detailsSection
                
                // Targets
                if trade.stopLoss != nil || trade.takeProfit != nil {
                    targetsSection
                }
                
                // P&L Section (Closed trades)
                if trade.status == .closed {
                    pnlSection
                }
                
                // Notes
                notesSection
                
                // Close Trade Button (Open trades only)
                if trade.status == .open {
                    closeButton
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.13),
                    Color(red: 0.07, green: 0.07, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(trade.ticker)
        .sheet(isPresented: $showCloseSheet) {
            CloseTradeSheet(trade: trade)
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(trade.ticker)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(trade.side.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(trade.side == .long ? Color.green : Color.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((trade.side == .long ? Color.green : Color.red).opacity(0.15))
                        .clipShape(Capsule())
                    
                    Text(trade.assetType.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                
                HStack(spacing: 8) {
                    Text(trade.status.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(trade.status == .open ? Color.blue : Color.gray)
                    
                    if let strategy = trade.strategy, !strategy.isEmpty {
                        Text("• \(strategy)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Date
            VStack(alignment: .trailing, spacing: 4) {
                Text("Opened")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(trade.dateAdded, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let days = trade.holdingDays {
                    Text("\(days)d held")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRADE DETAILS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                DetailItem(label: "Entry", value: trade.entryPrice.map { String(format: "$%.2f", $0) } ?? "—")
                DetailItem(label: "Quantity", value: trade.quantity.map { "\(Int($0))" } ?? "—")
                DetailItem(label: "Position Size", value: trade.positionSize.map { String(format: "$%.0f", $0) } ?? "—")
            }
            
            if trade.status == .closed {
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 20) {
                    DetailItem(label: "Exit", value: trade.exitPrice.map { String(format: "$%.2f", $0) } ?? "—")
                    DetailItem(label: "Closed", value: trade.dateClosed.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                    DetailItem(label: "Holding", value: trade.holdingDays.map { "\($0) days" } ?? "—")
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TARGETS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                if let sl = trade.stopLoss {
                    DetailItem(label: "Stop Loss", value: String(format: "$%.2f", sl), color: .red)
                }
                if let tp = trade.takeProfit {
                    DetailItem(label: "Take Profit", value: String(format: "$%.2f", tp), color: .green)
                }
                if let rr = trade.riskRewardRatio {
                    DetailItem(label: "R:R", value: String(format: "1:%.1f", rr), color: .orange)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var pnlSection: some View {
        VStack(spacing: 8) {
            if let pnl = trade.pnl {
                Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
            }
            
            HStack(spacing: 16) {
                if let pct = trade.percentReturn {
                    Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                if let r = trade.rMultiple {
                    Text("\(r >= 0 ? "+" : "")\(r, specifier: "%.1f")R")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            (trade.isWin ? Color.green : Color.red).opacity(0.1)
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((trade.isWin ? Color.green : Color.red).opacity(0.2), lineWidth: 1)
        )
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            TextEditor(text: Binding(
                get: { trade.notes ?? "" },
                set: { trade.notes = $0.isEmpty ? nil : $0 }
            ))
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(minHeight: 100)
            .background(Color(red: 0.15, green: 0.15, blue: 0.16))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    private var closeButton: some View {
        Button(action: { showCloseSheet = true }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Close Trade")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

struct DetailItem: View {
    let label: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
