//
//  TradeDetailView.swift
//  Memoria

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

    var math: TradeAccounting? { engine.tradeAccounting[trade.id] }

    @AppStorage("mathEngineInspector") private var mathEngineInspectorEnabled: Bool = false

    @State private var showManageSheet = false
@State private var showEnlargeSheet = false
    @State private var livePrice: Double?

    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 16) {
                        detailsAndPnLSection

                        if trade.stopLoss != nil || trade.takeProfit != nil {
                            rmulGaugeSection
                            targetsSection
                        }

                        executionChecklistSection

                        if mathEngineInspectorEnabled { debugMathSection }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    VStack(spacing: 16) {
                        attachmentAndNotesSection
                        executionHistorySection
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.12, blue: 0.13), Color(red: 0.07, green: 0.07, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear { if trade.status == .open { Task { await fetchCurrentPrice() } } }
        .onReceive(refreshTimer) { _ in if trade.status == .open { Task { await fetchCurrentPrice() } } }
        .navigationTitle(trade.ticker)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if trade.status == .open {
                    Button(action: { showManageSheet = true }) {
                        Label("Manage Position", systemImage: "slider.horizontal.3")
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .sheet(isPresented: $showManageSheet) { ScalePositionSheet(trade: trade, livePrice: livePrice) }
        .sheet(isPresented: $showEnlargeSheet) { FullScreenImageView(attachmentId: trade.attachmentId) }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            TickerLogoView(ticker: trade.ticker, size: 48).padding(.trailing, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(trade.ticker)
                        .font(.system(size: 28, weight: .bold))

                    Text(trade.side.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(trade.side == .long ? Color.green : Color.red)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((trade.side == .long ? Color.green : Color.red).opacity(0.15), in: Capsule())

                    Text(trade.assetType.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                HStack(spacing: 8) {
                    Text(trade.status.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(trade.status == .open ? Color.blue : Color.gray)

                    if let strategy = trade.strategy, !strategy.isEmpty {
                        Text("• \(strategy)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Opened").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(trade.dateAdded, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption).foregroundStyle(.secondary)
                if let days = trade.holdingDays {
                    Text("\(days)d held")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Details + P&L

    private var detailsAndPnLSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("TRADE DETAILS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        DetailItem(label: "Avg Entry", value: math?.vwap != nil ? String(format: "$%.2f", math!.vwap!) : "—")
                        DetailItem(label: "Active Qty", value: "\(Int(math?.effectiveQuantity ?? 0))")
                    }
                    GridRow {
                        DetailItem(label: "Size", value: math != nil ? String(format: "$%.0f", math!.positionSize) : "—")
                        if trade.status == .closed {
                            DetailItem(label: "Exit", value: trade.exitPrice != nil ? String(format: "$%.2f", trade.exitPrice!) : "—")
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

            if let pnl = math?.totalPnl {
                let pnlColor: Color = pnl >= 0 ? .green : .red

                Divider().background(Color.white.opacity(0.1))

                VStack(spacing: 6) {
                    Text(trade.status == .closed ? "REALIZED" : "UNREALIZED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)

                    Text(pnl >= 0 ? "+\(pnl, format: .currency(code: "USD"))" : "\(pnl, format: .currency(code: "USD"))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(pnlColor)
                        .shadow(color: pnlColor.opacity(0.4), radius: 10, x: 0, y: 0)

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
                .background(pnlColor.opacity(0.1))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Risk Gauge

    private var rmulGaugeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RISK VS REWARD GAUGE")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
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
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 8)
                    Rectangle()
                        .fill(LinearGradient(colors: [.red.opacity(0.6), .red.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, entryPos), height: 8).clipShape(RoundedRectangle(cornerRadius: 4))
                    Rectangle()
                        .fill(LinearGradient(colors: [.green.opacity(0.1), .green.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, width - entryPos), height: 8)
                        .offset(x: entryPos).clipShape(RoundedRectangle(cornerRadius: 4))
                    Rectangle().fill(.white).frame(width: 2, height: 16).offset(x: entryPos - 1, y: -4)
                    Circle().fill(.white).frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .overlay(Circle().stroke(current >= entry ? Color.green : Color.red, lineWidth: 2))
                        .offset(x: min(max(0, currentPos - 6), width - 12), y: -2)
                }
            }
            .frame(height: 20)

            HStack {
                Text("Stop Loss").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Entry").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Take Profit").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Targets

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TARGETS").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                if let sl = trade.stopLoss { DetailItem(label: "Stop Loss", value: String(format: "$%.2f", sl), color: .red) }
                if let tp = trade.takeProfit { DetailItem(label: "Take Profit", value: String(format: "$%.2f", tp), color: .green) }
                if let rr = trade.riskRewardRatio { DetailItem(label: "R:R", value: String(format: "1:%.1f", rr), color: .orange) }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Checklist

    private let ruleOptions = ["Followed Plan", "Waited for Setup", "Stuck to SL", "Right Size"]

    private var executionChecklistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXECUTION CHECKLIST")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)

            VStack(spacing: 2) {
                ForEach(ruleOptions, id: \.self) { rule in
                    let checked = trade.rulesFollowed.contains(rule)
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            if checked { trade.rulesFollowed.removeAll { $0 == rule } }
                            else { trade.rulesFollowed.append(rule) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: checked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(checked ? .green : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                            Text(rule)
                                .font(.system(size: 13))
                                .foregroundStyle(checked ? .primary : .secondary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(checked ? Color.green.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Attachment + Notes

    private var attachmentAndNotesSection: some View {
        VStack(spacing: 0) {
            // Section header — same style as all other cards
            HStack {
                Text("TECHNICAL SETUP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Hero Image
            ZStack(alignment: .bottomTrailing) {
                LocalImageView(attachmentId: trade.attachmentId)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 140, maxHeight: 240)
                    .clipped()
                    .onTapGesture { if trade.attachmentId != nil { showEnlargeSheet = true } }
                    .dropDestination(for: Data.self) { items, _ in
                        guard let imageData = items.first else { return false }
                        if let newId = LocalAttachmentService.shared.saveImage(from: imageData) {
                            if let old = trade.attachmentId { LocalAttachmentService.shared.deleteImage(id: old) }
                            trade.attachmentId = newId
                            return true
                        }
                        return false
                    }
                    .dropDestination(for: URL.self) { items, _ in
                        guard let url = items.first else { return false }
                        if let newId = LocalAttachmentService.shared.saveImage(from: url) {
                            if let old = trade.attachmentId { LocalAttachmentService.shared.deleteImage(id: old) }
                            trade.attachmentId = newId
                            return true
                        }
                        return false
                    }

                if trade.attachmentId != nil {
                    Button(action: { showEnlargeSheet = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.08)).padding(.vertical, 12)

            // Notes
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ANALYSIS & CONVICTION")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding([.horizontal, .bottom], 16)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Execution Timeline

    private var executionHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXECUTION HISTORY")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)

            if trade.executions.isEmpty {
                Text("No executions recorded.")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                let sorted = trade.executions.sorted { $0.date < $1.date }

                ZStack(alignment: .topLeading) {
                    // Connecting line
                    if sorted.count > 1 {
                        Capsule()
                            .fill(.white.opacity(0.08))
                            .frame(width: 1.5)
                            .padding(.leading, 3.25)
                            .padding(.top, 6)
                            .padding(.bottom, 6)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sorted) { exec in
                            let isBuy = exec.type == .buy
                            HStack(alignment: .top, spacing: 14) {
                                Circle()
                                    .fill(isBuy ? Color.blue : Color.orange)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(isBuy ? "Buy" : "Sell")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(isBuy ? .blue : .orange)

                                        Spacer()

                                        Text("\(exec.price, format: .currency(code: "USD"))")
                                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                                    }

                                    HStack {
                                        Text(exec.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.system(size: 10)).foregroundStyle(.tertiary)

                                        Spacer()

                                        Text("\(Int(exec.quantity)) shares")
                                            .font(.system(size: 11).monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.bottom, exec.id == sorted.last?.id ? 0 : 16)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05), lineWidth: 0.5))
    }

    // MARK: - Fetch

    private func fetchCurrentPrice() async {
        if let quote = await StockQuoteService.shared.fetchQuote(for: trade.ticker) {
            withAnimation { self.livePrice = quote.currentPrice }
        }
    }

    // MARK: - Debug

    private var debugMathSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                Text("Math Engine Inspector").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.orange).padding(.bottom, 4)

            if let m = math {
                let vwap = m.vwap ?? 0
                let realized = m.realizedPnl ?? 0
                let unrealized = m.unrealizedPnl
                let totalPnl = m.totalPnl ?? 0
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    GridRow {
                        debugItem(label: "VWAP", value: String(format: "%.2f", vwap))
                        debugItem(label: "EFF. QTY", value: String(format: "%.2f", m.effectiveQuantity))
                    }
                    GridRow {
                        debugItem(label: "REALIZED", value: String(format: "%.2f", realized))
                        debugItem(label: "UNREALIZED", value: String(format: "%.2f", unrealized))
                    }
                    GridRow {
                        debugItem(label: "TOTAL PNL", value: String(format: "%.2f", totalPnl))
                        debugItem(label: "WIN STATUS", value: m.winStatus ? "WIN (>=0)" : "LOSE")
                    }
                }
            } else {
                Text("No math snapshot available for this trade.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }

    private func debugItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced))
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
                ZoomableScrollView(attachmentId: attachmentId, resetTrigger: $resetTrigger).ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { resetTrigger = true }) {
                        Label("Reset Zoom", systemImage: "gobackward")
                    }
                }
            }
        }
        .frame(minWidth: 940, minHeight: 640)
        .onMouseBackButton()
    }
}

struct DetailItem: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
    }
}

#Preview {
    TradeDetailView(trade: Trade(ticker: "AAPL"))
        .modelContainer(for: Trade.self, inMemory: true)
        .preferredColorScheme(.dark)
}
