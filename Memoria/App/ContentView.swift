//
//  ContentView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var portfolios: [Portfolio]
    @AppStorage("selectedPortfolioID", store: .app) private var selectedIDString: String = ""

    private var activePortfolio: Portfolio? {
        guard let id = UUID(uuidString: selectedIDString) else { return portfolios.first }
        return portfolios.first { $0.id == id } ?? portfolios.first
    }

    var body: some View {
        Group {
            if let portfolio = activePortfolio {
                MainTabView(portfolio: portfolio)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activePortfolio?.id)
        .onAppear { installMouseBackButtonMonitor() }
    }
}

// MARK: - Main Tab Container

private struct MainTabView: View {
    let portfolio: Portfolio

    @Query private var openTrades: [Trade]

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _openTrades = Query(filter: #Predicate<Trade> {
            $0.portfolio?.id == id && $0.statusRaw == "Open"
        })
    }

    var body: some View {
        TabView {
            DashboardView(portfolio: portfolio)
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            TradesListView(portfolio: portfolio)
                .tabItem { Label("Trades", systemImage: "chart.bar.doc.horizontal") }

            CalendarView(portfolio: portfolio)
                .tabItem { Label("Calendar", systemImage: "calendar.badge.clock") }

            AnalyticsView(portfolio: portfolio)
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis.ascending") }

            #if os(macOS)
            WatchlistView(portfolio: portfolio)
                .tabItem { Label("Watchlist", systemImage: "list.star") }
            #endif

            SettingsView(portfolio: portfolio)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onChange(of: portfolio.id) { AccountingEngine.shared.reset() }
        #if os(iOS)
        .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.06), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        #endif
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
