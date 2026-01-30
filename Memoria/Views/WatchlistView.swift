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
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse)
    private var watchlistItems: [WatchlistItem]
    
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
                if watchlistItems.isEmpty {
                    ContentUnavailableView(
                        "No items in Watchlist",
                        systemImage: "eye.slash",
                        description: Text("Add a stock manually to track it.")
                    )
                } else {
                    List {
                        ForEach(watchlistItems) { item in
                            WatchlistRowView(item: item)
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
            // This tells SwiftUI: "When 'showAddTrade' is true, popup the AddWatchlistItemView"
            .sheet(isPresented: $showAddTrade) {
                AddWatchlistItemView()
                    .presentationDetents([.medium]) // Makes it take up half the screen
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(watchlistItems[index])
            }
        }
    }
}

// Renamed from TradeRowView to avoid confusion


#Preview {
    WatchlistView()
}
