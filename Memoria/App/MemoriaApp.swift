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
            Trade.self,
            Execution.self,
            AccountSnapshot.self,
            ActivityLog.self,
            WatchlistItem.self,
        ])

        #if DEBUG
        let storeURL = URL.applicationSupportDirectory.appending(path: "Memoria_Debug.sqlite")
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
        }
        .modelContainer(sharedModelContainer)
    }
}
