//
//  WatchlistView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.

import SwiftUI
import SwiftData
import Combine

struct WatchlistView: View {
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @Query private var watchlistItems: [WatchlistItem]

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _watchlistItems = Query(
            filter: #Predicate<WatchlistItem> { $0.portfolio?.id == id },
            sort: [SortDescriptor(\WatchlistItem.sortOrder), SortDescriptor(\WatchlistItem.dateAdded, order: .reverse)]
        )
    }

    @AppStorage("watchlistTimeframe", store: .app) private var timeframe: String = "1D"

    @State private var showAddItem = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    @State private var sparklines: [String: [Double]] = [:]

    @State private var showiOSAlert = false
    @State private var iosTickerInput = ""

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private func deleteItem(_ item: WatchlistItem) {
        withAnimation {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = watchlistItems
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item.sortOrder = index
        }
    }

    var body: some View {
        ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                if watchlistItems.isEmpty {
                    ContentUnavailableView(
                        "No items in Watchlist",
                        systemImage: "eye.slash",
                        description: Text("Add a stock to start tracking live prices.")
                    )
                } else {
                    VStack(spacing: 0) {
                        timeframePicker
                        List {
                            ForEach(watchlistItems) { item in
                                WatchlistRowView(item: item, sparkline: sparklines[item.ticker] ?? [], timeframe: timeframe, deleteItem: { deleteItem(item) })
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteItem(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }
                            .onMove(perform: moveItems)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .goldTitle("Watchlist")
            .darkNavigationBar()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshQuotes() }
                    } label: {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .tint(.white)
                    .disabled(isRefreshing)
                }
                #else
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task { await refreshQuotes() }
                    } label: {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .tint(.white)
                    .disabled(isRefreshing)
                    .help("Refresh prices")
                }
                #endif

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        #if os(iOS)
                        showiOSAlert = true
                        #else
                        showAddItem = true
                        #endif
                    }) {
                        Label("Add Symbol", systemImage: "plus")
                    }
                    .labelStyle(.titleAndIcon)
                    .tint(.white)
                    .help("Add to Watchlist")
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddWatchlistItemView(portfolio: portfolio)
                    .onDisappear {
                        Task { await refreshQuotes() }
                    }
            }
            .alert("Add Watchlist Symbol", isPresented: $showiOSAlert) {
                TextField("Ticker (e.g. AAPL)", text: $iosTickerInput)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    #endif
                
                Button("Cancel", role: .cancel) {
                    iosTickerInput = ""
                }
                
                Button("Add") {
                    let symbol = iosTickerInput.trimmingCharacters(in: .whitespaces).uppercased()
                    if !symbol.isEmpty {
                        let item = WatchlistItem(ticker: symbol)
                        item.portfolio = portfolio
                        modelContext.insert(item)
                        try? modelContext.save()
                        AnalyticsService.shared.log(.watchlistItemAdded, details: "Ticker: \(symbol)", context: modelContext)
                        iosTickerInput = ""
                        Task {
                            // Give SwiftData 200ms to inject the new item into the @Query array before fetching
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            await refreshQuotes()
                        }
                    }
                }
            } message: {
                Text("Enter the stock ticker symbol you want to track.")
            }
            .task {
                await refreshQuotes()
            }
            .onReceive(refreshTimer) { _ in
                let status = MarketService.shared.currentStatus()
                if status == .open || status == .preMarket || status == .postMarket {
                    Task { await refreshQuotes() }
                }
            }
    }

    // MARK: - Timeframe Picker

    private var timeframePicker: some View {
        HStack(spacing: 0) {
            ForEach(["1D", "1W", "1M", "ALL"], id: \.self) { tf in
                Button(tf) { timeframe = tf }
                    .font(.system(size: 12, weight: timeframe == tf ? .bold : .regular))
                    .foregroundStyle(
                        timeframe == tf
                            ? Color(red: 0.92, green: 0.81, blue: 0.42)
                            : Color.white.opacity(0.35)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .background(Color.white.opacity(0.04))
        .overlay(
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Data Fetching

    private func fetchBatchedSparklines(for symbols: [String]) async -> [String: [Double]] {
        var result: [String: [Double]] = [:]
        let batchSize = 8
        let batches = stride(from: 0, to: symbols.count, by: batchSize)
            .map { Array(symbols[$0..<min($0 + batchSize, symbols.count)]) }
        for batch in batches {
            await withTaskGroup(of: (String, [Double]).self) { group in
                for symbol in batch {
                    group.addTask {
                        let data = await StockQuoteService.shared.fetchSparkline(symbol: symbol)
                        return (symbol.uppercased(), data)
                    }
                }
                for await (symbol, data) in group { result[symbol] = data }
            }
        }
        return result
    }

    private func refreshQuotes() async {
        guard !watchlistItems.isEmpty else { return }

        isRefreshing = true

        let symbols = watchlistItems.map { $0.ticker }

        async let quotesTask = StockQuoteService.shared.fetchQuotes(for: symbols)
        async let sparklinesTask: [String: [Double]] = fetchBatchedSparklines(for: symbols)
        async let periodClosesTask = StockQuoteService.shared.fetchPeriodCloses(for: symbols)

        let (quotes, newSparklines, periodCloses) = await (quotesTask, sparklinesTask, periodClosesTask)

        for item in watchlistItems {
            if let quote = quotes[item.ticker.uppercased()] {
                item.updateQuote(quote)
            }
        }

        for item in watchlistItems {
            if let closes = periodCloses[item.ticker.uppercased()],
               let current = item.currentPrice, current > 0 {
                item.weeklyChangePercent = closes.weeklyClose.map { ((current - $0) / $0) * 100 }
                item.monthlyChangePercent = closes.monthlyClose.map { ((current - $0) / $0) * 100 }
            }
        }

        sparklines.merge(newSparklines) { _, new in new }

        lastRefreshTime = Date()
        isRefreshing = false
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    WatchlistView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
