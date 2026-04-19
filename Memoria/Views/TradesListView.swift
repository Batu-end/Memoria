//
//  TradesListView.swift
//  Memoria
//
//  Main trade journal view — filterable list with op.gg-style history stats.
//

import SwiftUI
import SwiftData

struct TradesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trade.dateAdded, order: .reverse) private var allTrades: [Trade]
    
    @State private var selectedFilter: String = "All"
    @State private var showAddTrade = false
    @State private var tradeToClose: Trade?
    
    private let filters = ["All", "Open", "Closed"]
    
    private var filteredTrades: [Trade] {
        switch selectedFilter {
        case "Open":
            return allTrades.filter { $0.status == .open }
        case "Closed":
            return allTrades.filter { $0.status == .closed }
        default:
            return Array(allTrades)
        }
    }
    
    // MARK: - Stats for Closed Trades (op.gg-style header)
    
    private var closedTrades: [Trade] {
        allTrades.filter { $0.status == .closed }
    }
    
    private var totalPnl: Double {
        closedTrades.compactMap { $0.pnl }.reduce(0, +)
    }
    
    private var winCount: Int {
        closedTrades.filter { $0.isWin }.count
    }
    
    private var lossCount: Int {
        closedTrades.filter { !$0.isWin && $0.pnl != nil }.count
    }
    
    private var winRate: Double {
        let total = winCount + lossCount
        guard total > 0 else { return 0 }
        return Double(winCount) / Double(total) * 100
    }
    
    private var avgWin: Double {
        let wins = closedTrades.compactMap { $0.pnl }.filter { $0 > 0 }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0, +) / Double(wins.count)
    }
    
    private var avgLoss: Double {
        let losses = closedTrades.compactMap { $0.pnl }.filter { $0 < 0 }
        guard !losses.isEmpty else { return 0 }
        return losses.reduce(0, +) / Double(losses.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Filter Segmented Control
                filterBar
                
                // Stats Header (shown when viewing Closed or All)
                if selectedFilter != "Open" && !closedTrades.isEmpty {
                    statsHeader
                }
                
                // Trade List
                if filteredTrades.isEmpty {
                    emptyState
                } else {
                    tradesList
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .sheet(item: $tradeToClose) { trade in
            CloseTradeSheet(trade: trade)
        }
    }
    
    // MARK: - Sub-views
    
    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(filters, id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                }) {
                    Text(filter)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedFilter == filter ? .white : .secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            selectedFilter == filter
                                ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal)
    }
    
    private var statsHeader: some View {
        VStack(spacing: 12) {
            // Top row: Total P&L
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total P&L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalPnl >= 0 ? "+\(totalPnl, specifier: "%.2f")" : "\(totalPnl, specifier: "%.2f")")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(totalPnl >= 0 ? Color.green : Color.red)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Win Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(winRate, specifier: "%.0f")%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(winRate >= 50 ? Color.green : Color.orange)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Bottom row: W/L record + Avg Win/Loss
            HStack(spacing: 20) {
                StatPill(label: "W", value: "\(winCount)", color: .green)
                StatPill(label: "L", value: "\(lossCount)", color: .red)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Avg Win")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("+\(avgWin, specifier: "%.2f")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Avg Loss")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(avgLoss, specifier: "%.2f")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
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
        .padding(.horizontal)
    }
    
    private var tradesList: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredTrades) { trade in
                NavigationLink(destination: TradeDetailView(trade: trade)) {
                    TradeRowView(trade: trade)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if trade.status == .open {
                        Button {
                            tradeToClose = trade
                        } label: {
                            Label("Close Trade", systemImage: "checkmark.circle")
                        }
                    }
                    
                    Button(role: .destructive) {
                        withAnimation {
                            modelContext.delete(trade)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(selectedFilter == "Open" ? "No Open Trades" : (selectedFilter == "Closed" ? "No Trade History" : "No Trades Yet"), systemImage: "chart.bar.xaxis")
        } description: {
            Text("Tap + to log your first trade.")
        }
        .padding(.top, 60)
    }
}

// MARK: - Supporting Views

struct StatPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    TradesListView()
        .preferredColorScheme(.dark)
}
