//
//  WatchlistView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.

import SwiftUI
import SwiftData
import Combine

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WatchlistItem.sortOrder), SortDescriptor(\WatchlistItem.dateAdded, order: .reverse)])
    private var watchlistItems: [WatchlistItem]

    @State private var showAddItem = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    @State private var sparklines: [String: [Double]] = [:]

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
        NavigationStack {
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
                    List {
                        ForEach(watchlistItems) { item in
                            WatchlistRowView(item: item, sparkline: sparklines[item.ticker] ?? [], deleteItem: { deleteItem(item) })
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onMove(perform: moveItems)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Watchlist")
            .darkNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    if let lastRefresh = lastRefreshTime {
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                if isRefreshing {
                                    ProgressView().scaleEffect(0.6).frame(width: 10, height: 10)
                                }
                                Text(isRefreshing ? "Refreshing…" : "Updated \(lastRefresh, format: .dateTime.hour().minute())")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddItem = true }) {
                        Label("Add Symbol", systemImage: "plus")
                    }
                    .labelStyle(.titleAndIcon)
                    .help("Add to Watchlist")
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddWatchlistItemView()
                    .onDisappear {
                        Task { await refreshQuotes() }
                    }
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

        let (quotes, newSparklines) = await (quotesTask, sparklinesTask)

        for item in watchlistItems {
            if let quote = quotes[item.ticker.uppercased()] {
                item.updateQuote(quote)
            }
        }
        sparklines.merge(newSparklines) { _, new in new }

        lastRefreshTime = Date()
        isRefreshing = false
    }
}

#Preview {
    WatchlistView()
        .preferredColorScheme(.dark)
}
