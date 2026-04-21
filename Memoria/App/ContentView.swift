//
//  ContentView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                
            AnalyticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.xaxis.ascending")
                }
            
            TradesListView()
                .tabItem {
                    Label("Trades", systemImage: "chart.bar.doc.horizontal")
                }

            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "list.bullet")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear { installMouseBackButtonMonitor() }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
