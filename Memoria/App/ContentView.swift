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
            
            TradesListView()
                .tabItem {
                    Label("Trades", systemImage: "chart.bar.doc.horizontal")
                }
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "list.bullet")
                }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
