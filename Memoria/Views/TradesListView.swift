//
//  TradesListView.swift
//  Memoria
//
//  Main trade journal view — filterable list with op.gg-style history stats.
//

import SwiftUI
import SwiftData

struct TradesListView: View {
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @Query private var allTrades: [Trade]

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _allTrades = Query(filter: #Predicate<Trade> { $0.portfolio?.id == id }, sort: \Trade.dateAdded, order: .reverse)
    }
    
    var accountingEngine = AccountingEngine.shared
    
    @State private var selectedFilter: String = "All"
    @State private var selectedTypeFilter: String = "All"
    @State private var showAddTrade = false
    @State private var tradeToClose: Trade?
    @State private var tradeToScale: Trade?
    @State private var tradeToDelete: Trade?

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
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                #if os(iOS)
                List {
                    filterBar
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if selectedFilter != "Open" && !closedTrades.isEmpty {
                        statsHeader
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if filteredTrades.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredTrades) { trade in
                            NavigationLink(destination: TradeDetailView(trade: trade)) {
                                TradeRowView(trade: trade)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    tradeToDelete = trade
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                if trade.status == .open {
                                    Button {
                                        tradeToClose = trade
                                    } label: {
                                        Label("Close", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                #else
                ScrollView {
                    VStack(spacing: 16) {
                        filterBar

                        if selectedFilter != "Open" && !closedTrades.isEmpty {
                            statsHeader
                        }

                        if filteredTrades.isEmpty {
                            emptyState
                        } else {
                            tradesList
                        }
                    }
                    .padding(.top, 8)
                }
                #endif
            }
            .navigationTitle("Trades")
            .darkNavigationBar()
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
                AddTradeView(portfolio: portfolio)
            }
            .sheet(item: $tradeToClose) { trade in
                CloseTradeSheet(trade: trade, marketPrice: accountingEngine.currentPrice(for: trade.ticker))
            }
            .sheet(item: $tradeToScale) { trade in
                ScalePositionSheet(trade: trade, livePrice: accountingEngine.currentPrice(for: trade.ticker))
            }
            .alert("Delete Trade?", isPresented: Binding(
                get: { tradeToDelete != nil },
                set: { if !$0 { tradeToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let trade = tradeToDelete {
                        withAnimation { modelContext.delete(trade) }
                    }
                    tradeToDelete = nil
                }
                Button("Cancel", role: .cancel) { tradeToDelete = nil }
            } message: {
                if let trade = tradeToDelete {
                    Text("\"\(trade.ticker)\" will be permanently removed.")
                }
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
                    .stealthable()
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
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        tradeToDelete = trade
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
    let portfolio = Portfolio(name: "Main")
    TradesListView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
