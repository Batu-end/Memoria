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
    @State private var showDeleteAlert = false
    @State private var showEnlargeSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                headerSection
                
                HStack(alignment: .top, spacing: 20) {
                    // Left Column: The Math & Stats
                    VStack(spacing: 20) {
                        detailsAndPnLSection
                        
                        if trade.stopLoss != nil || trade.takeProfit != nil {
                            targetsSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    
                    // Right Column: The Media & Notes
                    VStack(spacing: 20) {
                        attachmentAndNotesSection
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                
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
        .sheet(isPresented: $showEnlargeSheet) {
            FullScreenImageView(attachmentId: trade.attachmentId)
        }
        .alert("Delete Attachment?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = trade.attachmentId {
                    LocalAttachmentService.shared.deleteImage(id: id)
                    trade.attachmentId = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the screenshot from this trade.")
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            TickerLogoView(ticker: trade.ticker, size: 48)
                .padding(.trailing, 4)
                
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
    
    private var detailsAndPnLSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("TRADE DETAILS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        DetailItem(label: "Entry", value: trade.entryPrice.map { String(format: "$%.2f", $0) } ?? "—")
                        DetailItem(label: "Quantity", value: trade.quantity.map { "\(Int($0))" } ?? "—")
                    }
                    GridRow {
                        DetailItem(label: "Size", value: trade.positionSize.map { String(format: "$%.0f", $0) } ?? "—")
                        if trade.status == .closed {
                            DetailItem(label: "Exit", value: trade.exitPrice.map { String(format: "$%.2f", $0) } ?? "—")
                        }
                    }
                    if trade.status == .closed {
                        GridRow {
                            DetailItem(label: "Closed", value: trade.dateClosed.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                            DetailItem(label: "Held", value: trade.holdingDays.map { "\($0) days" } ?? "—")
                        }
                    }
                }
            }
            .padding(16)
            
            // P&L Header (if closed)
            if trade.status == .closed {
                Divider().background(Color.white.opacity(0.1))
                
                VStack(spacing: 4) {
                    if let pnl = trade.pnl {
                        Text(pnl >= 0 ? "+\(pnl, format: .currency(code: "USD"))" : "\(pnl, format: .currency(code: "USD"))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
                    }
                    
                    HStack(spacing: 12) {
                        if let pct = trade.percentReturn {
                            Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        if let r = trade.rMultiple {
                            Text("\(r >= 0 ? "+" : "")\(r, specifier: "%.1f")R")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background((trade.isWin ? Color.green : Color.red).opacity(0.1))
            }
        }
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
    
    private var attachmentAndNotesSection: some View {
        VStack(spacing: 0) {
            // Media Header
            HStack {
                Text("TECHNICAL SETUP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if trade.attachmentId != nil {
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 8)
            
            // Image Box
            ZStack(alignment: .bottomTrailing) {
                LocalImageView(attachmentId: trade.attachmentId)
                    .frame(minHeight: 120, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        if trade.attachmentId != nil {
                            showEnlargeSheet = true
                        }
                    }
                
                if trade.attachmentId != nil {
                    Button(action: { showEnlargeSheet = true }) {
                        ZStack(alignment: .bottomTrailing) {
                            Path { path in
                                let size: CGFloat = 12
                                path.move(to: CGPoint(x: 0, y: size))
                                path.addLine(to: CGPoint(x: size, y: size))
                                path.addLine(to: CGPoint(x: size, y: 0))
                            }
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .padding(8)
                            
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .dropDestination(for: URL.self) { items, location in
                guard let itemURL = items.first else { return false }
                if let newId = LocalAttachmentService.shared.saveImage(from: itemURL) {
                    if let oldId = trade.attachmentId { LocalAttachmentService.shared.deleteImage(id: oldId) }
                    trade.attachmentId = newId
                    return true
                }
                return false
            }
            
            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 12)
            
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("ANALYSIS NOTES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                TextEditor(text: Binding(
                    get: { trade.notes ?? "" },
                    set: { trade.notes = $0.isEmpty ? nil : $0 }
                ))
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
            .padding([.horizontal, .bottom], 16)
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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

struct FullScreenImageView: View {
    let attachmentId: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                LocalImageView(attachmentId: attachmentId)
                    .interactiveDismissDisabled(false)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

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

#Preview {
    TradeDetailView(trade: Trade(ticker: "AAPL"))
        .modelContainer(for: Trade.self, inMemory: true)
        .preferredColorScheme(.dark)
}
