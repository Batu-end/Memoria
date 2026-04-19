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
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse)
    private var watchlistItems: [WatchlistItem]
    
    @State private var showAddItem = false
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    
    // Auto-refresh timer (fires every 30 seconds)
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private func deleteItem(_ item: WatchlistItem) {
        modelContext.delete(item)
    }
    
    var body: some View {
        ZStack {
            if watchlistItems.isEmpty {
                ContentUnavailableView(
                    "No items in Watchlist",
                    systemImage: "eye.slash",
                    description: Text("Add a stock to start tracking live prices.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
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
                            .padding(.top, 4)
                        }
                        
                        ForEach(watchlistItems) { item in
                            WatchlistRowView(item: item, deleteItem: { deleteItem(item) })
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .task {
            // Fetch quotes when view first appears
            await refreshQuotes()
        }
        .onReceive(refreshTimer) { _ in
            // Auto-refresh only during active hours
            let status = MarketService.shared.currentStatus()
            if status == .open || status == .preMarket || status == .postMarket {
                Task { await refreshQuotes() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshWatchlist"))) { _ in
            Task { await refreshQuotes() }
        }
    }
    
    // MARK: - Data Fetching
    
    private func refreshQuotes() async {
        guard !watchlistItems.isEmpty else { return }
        
        isRefreshing = true
        
        let symbols = watchlistItems.map { $0.ticker }
        let quotes = await StockQuoteService.shared.fetchQuotes(for: symbols)
        
        // Apply quotes to watchlist items
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
