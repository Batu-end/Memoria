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
        // Tab View at the top
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "list.bullet")
                }
            
            // CalendarView()
            //     .tabItem {
            //         Label("Calendar", systemImage: "calendar")
            //     }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
