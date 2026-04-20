//
//  TradeDetailView.swift
//  Memoria
//
//  Full detail view for a single trade. View, edit notes, close trade.
//

import SwiftUI
import SwiftData
import Combine

struct TradeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var engine = AccountingEngine.shared
    @Bindable var trade: Trade
    
    init(trade: Trade) {
        self.trade = trade
    }
    
    var math: TradeAccounting? {
        engine.tradeAccounting[trade.id]
    }
    
    @State private var showManageSheet = false
    @State private var showDeleteAlert = false
    @State private var showEnlargeSheet = false
    
    // Live Data for Gauge
    @State private var livePrice: Double?
    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
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
                            rmulGaugeSection
                            targetsSection
                        }
                        
                        executionChecklistSection
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    
                    // Right Column: The Media & Notes
                    VStack(spacing: 20) {
                        attachmentAndNotesSection
                        executionHistorySection
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                
                // Manage Position Button (Open trades only)
                if trade.status == .open {
                    manageButton
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
        .onAppear {
            if trade.status == .open { Task { await fetchCurrentPrice() } }
        }
        .onReceive(refreshTimer) { _ in
            if trade.status == .open { Task { await fetchCurrentPrice() } }
        }
        .navigationTitle(trade.ticker)
        .sheet(isPresented: $showManageSheet) {
            ScalePositionSheet(trade: trade, livePrice: livePrice)
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
    
    private var rmulGaugeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RISK VS REWARD GAUGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let r = math?.rMultiple {
                    Text("\(r >= 0 ? "+" : "")\(r, specifier: "%.2f")R")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(r >= 0 ? .green : .red)
                }
            }
            
            GeometryReader { geo in
                let width = geo.size.width
                let entry = trade.entryPrice ?? 0
                let sl = trade.stopLoss ?? (entry * 0.9)
                let tp = trade.takeProfit ?? (entry * 1.1)
                let current = trade.status == .closed ? (trade.exitPrice ?? entry) : (livePrice ?? entry)
                
                let range = tp - sl
                let entryPos = range > 0 ? CGFloat((entry - sl) / range) * width : width / 2
                let currentPos = range > 0 ? CGFloat((current - sl) / range) * width : width / 2
                
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 8)
                    
                    // Risk Zone (SL to Entry)
                    Rectangle()
                        .fill(LinearGradient(colors: [.red.opacity(0.6), .red.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, entryPos), height: 8)
                        .cornerRadius(4)
                    
                    // Reward Zone (Entry to TP)
                    Rectangle()
                        .fill(LinearGradient(colors: [.green.opacity(0.1), .green.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, width - entryPos), height: 8)
                        .offset(x: entryPos)
                        .cornerRadius(4)
                    
                    // Entry Marker
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2, height: 16)
                        .offset(x: entryPos - 1, y: -4)
                    
                    // Current Price Marker
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .overlay(Circle().stroke(current >= entry ? Color.green : Color.red, lineWidth: 2))
                        .offset(x: min(max(0, currentPos - 6), width - 12), y: -2)
                }
            }
            .frame(height: 20)
            
            HStack {
                Text("Stop Loss")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Entry")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Take Profit")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    
    private let ruleOptions = ["Followed Plan", "Waited for Setup", "Stuck to SL", "Right Size"]
    
    private var executionChecklistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXECUTION CHECKLIST")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                ForEach(ruleOptions, id: \.self) { rule in
                    Button {
                        if trade.rulesFollowed.contains(rule) {
                            trade.rulesFollowed.removeAll { $0 == rule }
                        } else {
                            trade.rulesFollowed.append(rule)
                        }
                    } label: {
                        HStack {
                            Image(systemName: trade.rulesFollowed.contains(rule) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(trade.rulesFollowed.contains(rule) ? .green : .secondary)
                            Text(rule)
                                .font(.system(size: 13))
                                .foregroundStyle(trade.rulesFollowed.contains(rule) ? .primary : .secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
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
                        DetailItem(label: "Avg Entry", value: math?.vwap.map { String(format: "$%.2f", $0) } ?? "—")
                        DetailItem(label: "Active Qty", value: "\(Int(math?.effectiveQuantity ?? 0))")
                    }
                    GridRow {
                        DetailItem(label: "Size", value: math?.positionSize.map { String(format: "$%.0f", $0) } ?? "—")
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
            
            // P&L Header (Realized or Floating)
            if let displayPnl = math?.totalPnl {
                Divider().background(Color.white.opacity(0.1))
                
                VStack(spacing: 4) {
                    Text(displayPnl >= 0 ? "+\(displayPnl, format: .currency(code: "USD"))" : "\(displayPnl, format: .currency(code: "USD"))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(displayPnl >= 0 ? Color.green : Color.red)
                    
                    HStack(spacing: 4) {
                        Text(trade.status == .closed ? "REALIZED" : "UNREALIZED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 4)
                    
                    HStack(spacing: 12) {
                        if let pct = math?.percentReturn {
                            Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        if let r = math?.rMultiple {
                            Text("\(r >= 0 ? "+" : "")\(r, specifier: "%.1f")R")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background((displayPnl >= 0 ? Color.green : Color.red).opacity(0.1))
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
            .dropDestination(for: Data.self) { items, location in
                guard let imageData = items.first else { return false }
                
                if let newId = LocalAttachmentService.shared.saveImage(from: imageData) {
                    if let oldId = trade.attachmentId {
                        LocalAttachmentService.shared.deleteImage(id: oldId)
                    }
                    trade.attachmentId = newId
                    return true
                }
                return false
            }
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ANALYSIS & CONVICTION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    StarRatingView(rating: Binding(
                        get: { trade.confidenceScore },
                        set: { trade.confidenceScore = $0 }
                    ), fontSize: 16)
                }
                
                TextEditor(text: Binding(
                    get: { trade.notes ?? "" },
                    set: { trade.notes = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(.body, design: .serif))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
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
    
    private var manageButton: some View {
        Button(action: { showManageSheet = true }) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("Manage Position")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
    
    private var executionHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXECUTION HISTORY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            if trade.executions.isEmpty {
                Text("No executions recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(trade.executions.sorted(by: { $0.date > $1.date })) { exec in
                        HStack(spacing: 12) {
                            // Indicator
                            Circle()
                                .fill(exec.type == .buy ? Color.blue : Color.orange)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exec.type == .buy ? "Bought" : "Sold")
                                    .font(.system(size: 12, weight: .bold))
                                Text(exec.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(exec.quantity)) shares")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("@ \(exec.price, format: .currency(code: "USD"))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if exec.id != trade.executions.sorted(by: { $0.date > $1.date }).last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
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
    
    // MARK: - Logic (Now Handled by AccountingEngine)
    // Legacy properties like currentR, openPnl, etc. have been removed.

    private func fetchCurrentPrice() async {
        if let quote = await StockQuoteService.shared.fetchQuote(for: trade.ticker) {
            withAnimation {
                self.livePrice = quote.currentPrice
            }
        }
    }
}

// MARK: - Supporting Views

struct FullScreenImageView: View {
    let attachmentId: String?
    @Environment(\.dismiss) private var dismiss
    
    @State private var resetTrigger = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZoomableScrollView(attachmentId: attachmentId, resetTrigger: $resetTrigger)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        resetTrigger = true
                    }) {
                        Label("Reset Zoom", systemImage: "gobackward")
                    }
                }
            }
        }
        .frame(minWidth: 940, minHeight: 640)
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
