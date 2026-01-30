//
//  WatchlistView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI
import SwiftData

// Visualization
struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Trade> { $0.statusRaw == "Watchlist" }, sort: \Trade.dateAdded, order: .reverse)
    private var watchlistTrades: [Trade]
    
    @State private var showAddTrade = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Tahoe-style "Glass" Background (Subtle Dark)
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.12, blue: 0.13), // Soft Charcoal
                        Color(red: 0.07, green: 0.07, blue: 0.08)  // Deep Dark Gray
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Live Data List
                if watchlistTrades.isEmpty {
                    ContentUnavailableView(
                        "No items in Watchlist",
                        systemImage: "eye.slash",
                        description: Text("Add a stock manually to track it.")
                    )
                } else {
                    List {
                        ForEach(watchlistTrades) { trade in
                            TradeRowView(trade: trade)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteItems)
                        .listStyle(.plain)
                        .contentMargins(.top, 60, for: .scrollContent) // Push content down
                    }
                    .scrollContentBackground(.hidden)
                } // Crucial for seeing the gradient behind the list
            }
            .navigationTitle("Watchlist")
            // --- TOP BAR BUTTONS ---
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    // This is the "Add Icon" logic
                    Button(action: { showAddTrade = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold)) // Slightly smaller for toolbar
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial) // Glass background
                            .clipShape(RoundedRectangle(cornerRadius: 8)) // Tahoe squaricle
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain) // Crucial for removing system oval
                }
            }
            // --- POPUP SHEET LOGIC ---
            // This tells SwiftUI: "When 'showAddTrade' is true, popup the AddTradeView"
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
                    .presentationDetents([.medium]) // Makes it take up half the screen
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(watchlistTrades[index])
            }
        }
    }
}

// Minimal Row Component - Connected to Real Data
struct TradeRowView: View {
    let trade: Trade
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(trade.status.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let price = trade.entryPrice {
                    Text(price, format: .currency(code: "USD"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("--")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    WatchlistView()
}
