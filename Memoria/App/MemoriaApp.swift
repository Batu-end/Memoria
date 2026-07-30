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
    /// How well the on-disk store opened at launch.
    private enum StoreStatus {
        case healthy
        /// The old store was unreadable and was set aside; this one started empty.
        case recovered(backup: URL?)
        /// Running in memory. Nothing entered will survive quitting.
        case unavailable(String)
    }

    private let container: ModelContainer
    private let status: StoreStatus
    @State private var recoveryNoticeDismissed = false

    init() {
        (container, status) = Self.loadStore()
        // Seed before any view queries the store, rather than from a view's .task —
        // ContentView renders nothing until a Portfolio exists, so driving the seed
        // from its lifecycle is a race it can lose.
        Self.bootstrapPortfolios(in: container)
    }

    var body: some Scene {
        // `.modelContainer` must stay a *Scene* modifier — attaching it to ContentView
        // leaves @Query without a context and the app renders an empty window. That
        // also rules out branching here, since SceneBuilder has no buildEither, so the
        // content branches instead.
        WindowGroup {
            Group {
                if case let .unavailable(message) = status {
                    StoreFailureView(message: message)
                } else {
                    ContentView()
                }
            }
            .preferredColorScheme(.dark)
            .tint(Color(red: 0.92, green: 0.81, blue: 0.42))
            .alert("Previous data couldn't be opened", isPresented: Binding(
                get: {
                    guard case .recovered = status else { return false }
                    return !recoveryNoticeDismissed
                },
                set: { if !$0 { recoveryNoticeDismissed = true } }
            )) {
                Button("OK", role: .cancel) { recoveryNoticeDismissed = true }
            } message: {
                if case let .recovered(backup) = status {
                    Text("Memoria started with an empty journal. Your old data was not deleted — it was set aside as \(backup?.lastPathComponent ?? "a backup file") in the app's Application Support folder.")
                }
            }
        }
        .modelContainer(container)
    }

    // MARK: - Store Loading

    /// Opens the store without ever crashing the app.
    ///
    /// The common failure is an incompatible model change between releases: SwiftData
    /// refuses to open the existing file, and a `fatalError` here would brick the app on
    /// every launch with no way for the user to reach an export or recover anything.
    /// Instead the unreadable store is moved aside — never deleted — and a fresh one is
    /// created so the app still opens.
    private static func loadStore() -> (ModelContainer, StoreStatus) {
        let schema = Schema([
            Portfolio.self,
            Trade.self,
            Execution.self,
            AccountSnapshot.self,
            ActivityLog.self,
            WatchlistItem.self,
            CapitalEvent.self,
        ])

        #if DEBUG
        let supportDir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let storeURL = supportDir.appending(path: "Memoria_Debug.sqlite")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        #else
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #endif

        if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
            return (container, .healthy)
        }

        // Unreadable. Set the old file aside and try again with a clean one.
        let backup = archiveStore(at: modelConfiguration.url)
        if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
            return (container, .recovered(backup: backup))
        }

        // Disk-level problem rather than a schema one. Run in memory so the app can
        // still open and say what happened, instead of dying at launch.
        let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [inMemory]) {
            return (container, .unavailable("Your journal file could not be opened or recreated."))
        }

        // Unreachable in practice: the schema is fixed at compile time, so if an
        // in-memory container cannot be built from it, nothing in the app can run.
        fatalError("Could not create an in-memory ModelContainer from a static schema")
    }

    /// Moves an unreadable store aside so a clean one can take its place, keeping the
    /// original on disk for manual recovery. Returns where it went, if it moved at all.
    private static func archiveStore(at url: URL) -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let base = url.deletingPathExtension().lastPathComponent
        let destination = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(base)-unreadable-\(stamp)")
            .appendingPathExtension(url.pathExtension)

        // SwiftData writes -shm and -wal siblings; leaving them behind would let the
        // fresh store inherit the old journal.
        var moved = false
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(fileURLWithPath: url.path + suffix)
            let to = URL(fileURLWithPath: destination.path + suffix)
            guard fileManager.fileExists(atPath: from.path) else { continue }
            if (try? fileManager.moveItem(at: from, to: to)) != nil { moved = true }
        }
        return moved ? destination : nil
    }

    // MARK: - Bootstrap

    @MainActor
    private static func bootstrapPortfolios(in container: ModelContainer) {
        let context = ModelContext(container)

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

// MARK: - Failure Screen

/// Shown only when even a fresh store cannot be created. Replaces a launch crash with
/// something the user can read and act on.
private struct StoreFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Memoria can't open your journal")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Your data has not been deleted. Reinstalling the app would erase it, so try restarting your device first.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
