//
//  ContentView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Tab? = .dashboard
    
    // Lifted States for Global Actions
    @State private var showAddTrade = false
    @State private var showAddWatchlistItem = false
    @State private var triggerWatchlistRefresh = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Shared Global Background
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        DashboardView()
                            .id(Tab.dashboard)
                            .containerRelativeFrame(.horizontal)
                        
                        AnalyticsView()
                            .id(Tab.analytics)
                            .containerRelativeFrame(.horizontal)
                        
                        TradesListView()
                            .id(Tab.trades)
                            .containerRelativeFrame(.horizontal)
                        
                        WatchlistView()
                            .id(Tab.watchlist)
                            .containerRelativeFrame(.horizontal)
                        
                        SettingsView()
                            .id(Tab.settings)
                            .containerRelativeFrame(.horizontal)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selectedTab)
                .scrollIndicators(.hidden)
                
                // Custom Floating Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 24)
            }
            .navigationTitle(selectedTab?.rawValue ?? "Memoria")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if selectedTab == .trades {
                        Button(action: { showAddTrade = true }) {
                            Label("Add Trade", systemImage: "plus")
                        }
                    }
                    
                    if selectedTab == .watchlist {
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshWatchlist"), object: nil)
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showAddWatchlistItem = true }) {
                            Label("Add to Watchlist", systemImage: "plus")
                        }
                    }
                }
            }
            // Global Sheets
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
            }
            .sheet(isPresented: $showAddWatchlistItem) {
                AddWatchlistItemView()
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
