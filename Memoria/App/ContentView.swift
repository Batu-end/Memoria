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
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        DashboardView(activeTab: selectedTab)
                            .equatable()
                            .id(Tab.dashboard)
                            .containerRelativeFrame(.horizontal)
                        
                        AnalyticsView(activeTab: selectedTab)
                            .equatable()
                            .id(Tab.analytics)
                            .containerRelativeFrame(.horizontal)
                        
                        TradesListView(activeTab: selectedTab)
                            .equatable()
                            .id(Tab.trades)
                            .containerRelativeFrame(.horizontal)
                        
                        WatchlistView(activeTab: selectedTab)
                            .equatable()
                            .id(Tab.watchlist)
                            .containerRelativeFrame(.horizontal)
                        
                        SettingsView(activeTab: selectedTab)
                            .equatable()
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
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
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
