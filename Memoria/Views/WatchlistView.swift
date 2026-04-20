//
//  WatchlistView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//  Updated with live price refresh.

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

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private func deleteItem(_ item: WatchlistItem) {
        modelContext.delete(item)
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
                LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.11), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                if watchlistItems.isEmpty {
                    ContentUnavailableView(
                        "No items in Watchlist",
                        systemImage: "eye.slash",
                        description: Text("Add a stock to start tracking live prices.")
                    )
                } else {
                    VStack(spacing: 0) {
                        // Refresh status bar
                        if let lastRefresh = lastRefreshTime {
                            HStack {
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 12, height: 12)
                                    Text("Refreshing...")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "clock")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                    Text("Updated \(lastRefresh, format: .dateTime.hour().minute())")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }

                        List {
                            ForEach(watchlistItems) { item in
                                WatchlistRowView(item: item, deleteItem: { deleteItem(item) })
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onMove(perform: moveItems)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
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

    private func refreshQuotes() async {
        guard !watchlistItems.isEmpty else { return }

        isRefreshing = true

        let symbols = watchlistItems.map { $0.ticker }
        let quotes = await StockQuoteService.shared.fetchQuotes(for: symbols)

        for item in watchlistItems {
            if let quote = quotes[item.ticker.uppercased()] {
                item.updateQuote(quote)
            }
        }

        lastRefreshTime = Date()
        isRefreshing = false
    }
}

#Preview {
    WatchlistView()
        .preferredColorScheme(.dark)
}
