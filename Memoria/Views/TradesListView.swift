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
    
    var accountingEngine = AccountingEngine.shared
    
    @State private var selectedFilter: String = "All"
    @State private var selectedTypeFilter: String = "All"
    @State private var showAddTrade = false
    @State private var tradeToClose: Trade?
    @State private var tradeToScale: Trade?

    private let filters = ["All", "Open", "Closed"]
    private let typeFilters = ["All", "Stock", "ETF"]

    private var filteredTrades: [Trade] {
        var trades: [Trade]
        switch selectedFilter {
        case "Open":   trades = allTrades.filter { $0.status == .open }
        case "Closed": trades = allTrades.filter { $0.status == .closed }
        default:       trades = Array(allTrades)
        }
        switch selectedTypeFilter {
        case "Stock": return trades.filter { $0.assetType == .stock }
        case "ETF":   return trades.filter { $0.assetType == .etf }
        default:      return trades
        }
    }
    
    // Stats are now pulled directly from the AccountingEngine
    private var closedTrades: [Trade] {
        allTrades.filter { $0.status == .closed }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                // Background
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                
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
                }
            }
            .navigationTitle("Trades")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddTrade = true }) {
                        Label("New Trade", systemImage: "plus")
                    }
                    .labelStyle(.titleAndIcon)
                    .help("Add Trade")
                }
            }
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
            }
            .sheet(item: $tradeToClose) { trade in
                CloseTradeSheet(trade: trade, marketPrice: accountingEngine.currentPrice(for: trade.ticker))
            }
            .sheet(item: $tradeToScale) { trade in
                ScalePositionSheet(trade: trade, livePrice: accountingEngine.currentPrice(for: trade.ticker))
            }
        }
    }
    
    // MARK: - Sub-views
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Status", selection: $selectedFilter) {
                ForEach(filters, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 200)

            Picker("Type", selection: $selectedTypeFilter) {
                ForEach(typeFilters, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 160)
        }
        .padding(.horizontal)
    }
    
    private var statsHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REALIZED P&L")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Text(accountingEngine.portfolioState.totalPnl >= 0 ? "+\(accountingEngine.portfolioState.totalPnl, specifier: "%.2f")" : "\(accountingEngine.portfolioState.totalPnl, specifier: "%.2f")")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(accountingEngine.portfolioState.totalPnl >= 0 ? Color.green : Color.red)
            }

            Spacer()

            StatPill(label: "W", value: "\(accountingEngine.portfolioState.winCount)", color: .green)
            StatPill(label: "L", value: "\(accountingEngine.portfolioState.lossCount)", color: .red)

            VStack(alignment: .trailing, spacing: 2) {
                Text("WIN RATE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Text("\(accountingEngine.portfolioState.winRate, specifier: "%.0f")%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(accountingEngine.portfolioState.winRate >= 50 ? Color.green : Color.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
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
                            Label("Close Position", systemImage: "checkmark.circle.fill")
                        }
                        Button {
                            tradeToScale = trade
                        } label: {
                            Label("Scale Position", systemImage: "slider.horizontal.3")
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
