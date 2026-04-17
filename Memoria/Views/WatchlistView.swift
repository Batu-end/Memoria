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
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.12, blue: 0.13),
                        Color(red: 0.07, green: 0.07, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
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
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                // Refresh button
                ToolbarItem(placement: .automatic) {
                    Button(action: { Task { await refreshQuotes() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                }
                
                // Add button
                ToolbarItem(placement: .automatic) {
                    Button(action: { showAddItem = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddWatchlistItemView()
                    .onDisappear {
                        // Refresh quotes after adding a new item
                        Task { await refreshQuotes() }
                    }
            }
            .task {
                // Fetch quotes when view first appears
                await refreshQuotes()
            }
            .onReceive(refreshTimer) { _ in
                // Auto-refresh only during market hours
                let status = MarketService.shared.currentStatus()
                if status == .open {
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
