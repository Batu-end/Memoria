//
//  MemoriaApp.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI
import SwiftData

@main
struct MemoriaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Portfolio.self,
            Trade.self,
            Execution.self,
            AccountSnapshot.self,
            ActivityLog.self,
            WatchlistItem.self,
        ])

        #if DEBUG
        let supportDir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let storeURL = supportDir.appending(path: "Memoria_Debug.sqlite")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        #else
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #endif

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.92, green: 0.81, blue: 0.42))
                .task { bootstrapPortfolios() }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrapPortfolios() {
        let context = ModelContext(sharedModelContainer)

        let existing = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []
        guard existing.isEmpty else { return }

        // Carry forward the legacy per-app starting balance into the first portfolio
        let legacyBalance = UserDefaults.app.double(forKey: "startingBalance")
        let main = Portfolio(name: "Main", startingBalance: legacyBalance, sortOrder: 0)
        context.insert(main)

        // Assign orphan trades — both directions for SwiftData relationship safety
        let orphanTrades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        for trade in orphanTrades { trade.portfolio = main }
        main.trades.append(contentsOf: orphanTrades)

        // Assign orphan watchlist items
        let orphanWatchlist = (try? context.fetch(FetchDescriptor<WatchlistItem>())) ?? []
        for item in orphanWatchlist { item.portfolio = main }
        main.watchlistItems.append(contentsOf: orphanWatchlist)

        // Assign orphan snapshots
        let orphanSnapshots = (try? context.fetch(FetchDescriptor<AccountSnapshot>())) ?? []
        for snapshot in orphanSnapshots { snapshot.portfolio = main }
        main.snapshots.append(contentsOf: orphanSnapshots)

        try? context.save()
    }
}
