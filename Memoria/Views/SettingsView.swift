//
//  SettingsView.swift
//  Memoria
//
//  Created by Batu Demirtas on 4/17/26.
//

import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

struct SettingsView: View {
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @Query private var trades: [Trade]
    @Query private var watchlistItems: [WatchlistItem]
    @Query private var accountSnapshots: [AccountSnapshot]
    @Query private var activityLogs: [ActivityLog]
    @Query private var capitalEvents: [CapitalEvent]

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _trades = Query(filter: #Predicate<Trade> { $0.portfolio?.id == id })
        _watchlistItems = Query(filter: #Predicate<WatchlistItem> { $0.portfolio?.id == id })
        _accountSnapshots = Query(filter: #Predicate<AccountSnapshot> { $0.portfolio?.id == id })
        _capitalEvents = Query(filter: #Predicate<CapitalEvent> { $0.portfolio?.id == id })
    }

    @AppStorage("traderName", store: .app) private var traderName: String = ""
    @AppStorage("traderPersonality", store: .app) private var personalityRaw: String = TraderPersonality.human.rawValue
    private var personality: TraderPersonality { TraderPersonality(rawValue: personalityRaw) ?? .human }
    
    @AppStorage("mathEngineInspector", store: .app) private var mathEngineInspectorEnabled: Bool = false
    @AppStorage("unreadableDate", store: .app) private var unreadableDate: Bool = false
    @AppStorage("showTickerLogos", store: .app) private var showTickerLogos: Bool = true
    @AppStorage("monochromeLogos", store: .app) private var monochromeLogos: Bool = false
    @AppStorage("stealthMode", store: .app) private var stealthMode: Bool = false
    @AppStorage("watchlistMoverAlert", store: .app) private var watchlistMoverAlert: Bool = true
    @AppStorage("watchlistMoverThreshold", store: .app) private var watchlistMoverThreshold: Double = 5.0

    @State private var showingResetAlert = false
    @State private var confirmationText = ""
    #if DEBUG
    @State private var sandboxSeeded = false
    #endif

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument = CSVDocument(text: "")
    @State private var importResult: ImportResult?

    private struct ImportResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @State private var capitalAction: CapitalAction?
    @State private var liveQuotes: [String: StockQuote] = [:]

    private enum CapitalAction: Identifiable {
        case deposit, withdraw
        var id: Self { self }
    }
    
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        WatchlistView(portfolio: portfolio)
                    } label: {
                        Label {
                            Text("Watchlist")
                        } icon: {
                            Image(systemName: "list.star").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Market")
                }

                Section {
                    HStack {
                        Label {
                            Text("Name")
                        } icon: {
                            Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                        }
                        TextField("", text: $traderName, prompt: Text("Enter your name"))
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.blue)
                            .submitLabel(.done)
                    }

                    Picker(selection: Binding(
                        get: { personality },
                        set: { personalityRaw = $0.rawValue }
                    )) {
                        ForEach(TraderPersonality.allCases, id: \.self) { p in
                            Text("\(p.emoji) \(p.rawValue)")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .tag(p)
                        }
                    } label: {
                        Label {
                            Text("I am a...")
                        } icon: {
                            Image(systemName: "theatermasks.fill").foregroundStyle(.secondary)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                } header: {
                    Text("Profile")
                }
                
                Section {
                    VStack(spacing: 24) {
                        HStack(spacing: 20) {
                            // Current Balance (What you actually have)
                            VStack(spacing: 4) {
                                Text("ACCOUNT BALANCE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                
                                Text(currentBalance, format: .currency(code: "USD"))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .stealthable()
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 30)
                            
                            // Net Deposits (In vs Out)
                            VStack(spacing: 4) {
                                Text(portfolio.startingBalance >= 0 ? "NET CONTRIBUTION" : "HOUSE MONEY")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)

                                Text(abs(portfolio.startingBalance), format: .currency(code: "USD"))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(portfolio.startingBalance >= 0 ? Color.primary : Color.orange)
                                    .stealthable()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 10)
                        
                        HStack(spacing: 15) {
                            Button {
                                capitalAction = .deposit
                            } label: {
                                Label("Deposit", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                capitalAction = .withdraw
                            } label: {
                                Label("Withdraw", systemImage: "minus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 10)
                } header: {
                    Label("Financial Management", systemImage: "briefcase.fill")
                } footer: {
                    Text("Account Balance = Contributions + Trading Profits. If your contribution is negative, you are playing with 'House Money' (withdrawn more than you deposited).")
                }
                
                Section {
                    Toggle(isOn: $unreadableDate) {
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Nearly unreadable date", systemImage: "character.cursor.ibeam")
                            Text("Calligraphic font on the date header. Looks cool, barely readable.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                        #else
                        HStack(spacing: 14) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nearly unreadable date")
                                    .font(.system(size: 16))
                                Text("Calligraphic font on the date header.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        #endif
                    }
                    .padding(.vertical, 4)
                    
                    Toggle(isOn: $monochromeLogos) {
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Monochrome logos", systemImage: "circle.lefthalf.filled")
                            Text("Strips color from all ticker logos.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                        #else
                        HStack(spacing: 14) {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Monochrome logos")
                                    .font(.system(size: 16))
                                Text("Strips color from all ticker logos.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        #endif
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $showTickerLogos) {
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Ticker logos", systemImage: "photo.on.rectangle.angled")
                            Text("Shows company logos next to trade rows.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                        #else
                        HStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ticker logos")
                                    .font(.system(size: 16))
                                Text("Shows company logos next to trade rows.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        #endif
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $stealthMode) {
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Stealth Mode", systemImage: "eye.slash")
                            Text("Hides absolute dollar values across the app.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                        #else
                        HStack(spacing: 14) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stealth Mode")
                                    .font(.system(size: 16))
                                Text("Hides absolute dollar values across the app.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        #endif
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle(isOn: $watchlistMoverAlert) {
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Big mover badge", systemImage: "exclamationmark.circle")
                            Text("Flags watchlist items that moved more than the threshold today.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                        #else
                        HStack(spacing: 14) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Big mover badge")
                                    .font(.system(size: 16))
                                Text("Flags watchlist items that moved more than the threshold today.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        #endif
                    }
                    .padding(.vertical, 4)

                    if watchlistMoverAlert {
                        Stepper(value: $watchlistMoverThreshold, in: 1...25, step: 0.5) {
                            #if os(macOS)
                            Text("Threshold: \(watchlistMoverThreshold, specifier: "%.1f")%")
                            #else
                            HStack(spacing: 14) {
                                Image(systemName: "percent")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)
                                Text("Threshold: \(watchlistMoverThreshold, specifier: "%.1f")%")
                                    .font(.system(size: 16))
                            }
                            #endif
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Watchlist")
                }

                Section {
                    Toggle(isOn: $mathEngineInspectorEnabled) {
                        Label {
                            Text("Math Engine Inspector")
                        } icon: {
                            Image(systemName: "function")
                                .foregroundStyle(.secondary)
                        }
                    }
                    #if DEBUG
                    Button {
                        seedDemoPortfolio(into: modelContext)
                        sandboxSeeded = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sandboxSeeded ? "Demo Portfolio Created" : "Seed Demo Portfolio")
                                Text("Adds \"Demo — 45 Trades\" for UI testing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: sandboxSeeded ? "checkmark.circle.fill" : "wand.and.stars")
                                .foregroundStyle(sandboxSeeded ? .green : .secondary)
                        }
                    }
                    .disabled(sandboxSeeded)
                    #endif
                } header: {
                    Text("Developer Tools")
                } footer: {
                    Text("Shows live accounting engine state in the Dashboard for debugging.")
                }

                Section {
                    Button {
                        exportDocument = CSVDocument(text: TradeCSVService.export(trades))
                        showingExporter = true
                    } label: {
                        Label {
                            Text("Export Trades")
                        } icon: {
                            Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
                        }
                    }
                    .disabled(trades.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label {
                            Text("Import Trades")
                        } icon: {
                            Image(systemName: "square.and.arrow.down").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Exports every trade and its individual fills to CSV. Importing adds those trades to \"\(portfolio.name)\" without touching what's already there. Screenshots and deposits are not included.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmationText = ""
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Label {
                                Text("Reset Portfolio")
                            } icon: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Text("Portfolio Data")
                        .foregroundStyle(.red)
                } footer: {
                    Text("Permanently deletes all trades, watchlist items, and history in \"\(portfolio.name)\". The portfolio itself is kept. This cannot be undone.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
                .background(
                    LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()
                )
                .goldTitle("Settings")
                .darkNavigationBar()
                .task(id: portfolio.id) {
                    liveQuotes = [:]
                    await fetchLiveQuotes()
                }
                .onReceive(refreshTimer) { _ in
                    Task { await fetchLiveQuotes() }
                }
                .sheet(item: $capitalAction) { action in
                    CapitalAdjustmentSheet(isDepositing: action == .deposit, currentBalance: currentBalance) { amount in
                        if action == .deposit {
                            portfolio.startingBalance += amount
                        } else {
                            portfolio.startingBalance -= amount
                        }
                        let event = CapitalEvent(amount: action == .deposit ? amount : -amount)
                        event.portfolio = portfolio
                        modelContext.insert(event)
                    }
                }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: exportFilename
            ) { result in
                if case let .failure(error) = result {
                    importResult = ImportResult(title: "Export Failed", message: error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                importTrades(from: result)
            }
            .alert(item: $importResult) { result in
                Alert(title: Text(result.title), message: Text(result.message), dismissButton: .default(Text("OK")))
            }
            .alert("Reset \"\(portfolio.name)\"?", isPresented: $showingResetAlert) {
                TextField("Type \"DELETE\" to confirm", text: $confirmationText)

                Button("Cancel", role: .cancel) { }

                Button("Reset Portfolio", role: .destructive) {
                    if confirmationText == "DELETE" {
                        eraseAllData()
                    }
                }
                // While SwiftUI alerts sometimes don't dynamically disable buttons based on text fields,
                // we strictly check the string upon submission as the primary safeguard.
            } message: {
                Text("This action is permanent and cannot be undone. Please type DELETE to confirm.")
            }
        }
    }
    
    private var totalFloatingPnl: Double {
        var sum: Double = 0
        let openTrades = trades.filter { $0.status == .open }
        for trade in openTrades {
            if let entry = trade.entryPrice, let math = trade.math, let quote = liveQuotes[trade.ticker.uppercased()] {
                let pnl = (quote.currentPrice - entry) * math.effectiveQuantity * (trade.side == .long ? 1.0 : -1.0)
                sum += pnl
            }
        }
        return sum
    }
    
    private var currentBalance: Double {
        let totalPnl = trades.filter { $0.status == .closed }.compactMap { $0.math?.totalPnl }.reduce(0, +)
        return portfolio.startingBalance + totalPnl + totalFloatingPnl
    }
    
    private func fetchLiveQuotes() async {
        let openTrades = trades.filter { $0.status == .open }
        guard !openTrades.isEmpty else { return }
        let symbols = openTrades.map { $0.ticker }
        let newQuotes = await StockQuoteService.shared.fetchQuotes(for: symbols)
        liveQuotes.merge(newQuotes) { (_, new) in new }
    }
    
    private var exportFilename: String {
        let stamp = Date().formatted(.iso8601.year().month().day())
        let safeName = portfolio.name.replacingOccurrences(of: "/", with: "-")
        return "Memoria-\(safeName)-\(stamp)"
    }

    private func importTrades(from result: Result<URL, Error>) {
        do {
            let url = try result.get()

            // Files chosen through the picker live outside the sandbox.
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let imported = try TradeCSVService.makeTrades(from: try String(contentsOf: url, encoding: .utf8))
            guard !imported.isEmpty else {
                importResult = ImportResult(title: "Nothing Imported", message: "No trades were found in that file.")
                return
            }

            for trade in imported {
                trade.portfolio = portfolio
                modelContext.insert(trade)
            }
            try modelContext.save()

            AccountingEngine.shared.update(
                trades: trades,
                startingBalance: portfolio.startingBalance,
                capitalEvents: capitalEvents
            )

            importResult = ImportResult(
                title: "Import Complete",
                message: "Added \(imported.count) trade\(imported.count == 1 ? "" : "s") to \"\(portfolio.name)\"."
            )
        } catch {
            importResult = ImportResult(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func eraseAllData() {
        LocalAttachmentService.shared.deleteImages(for: trades)
        for trade in trades { modelContext.delete(trade) }
        for item in watchlistItems { modelContext.delete(item) }
        for snapshot in accountSnapshots { modelContext.delete(snapshot) }
        for log in activityLogs { modelContext.delete(log) }
        for event in capitalEvents { modelContext.delete(event) }
        try? modelContext.save()

        portfolio.startingBalance = 0.0
        traderName = ""
        personalityRaw = TraderPersonality.human.rawValue
        unreadableDate = false
        mathEngineInspectorEnabled = false
        monochromeLogos = false
        watchlistMoverAlert = true
        watchlistMoverThreshold = 5.0

        AccountingEngine.shared.reset()
    }
}

struct CapitalAdjustmentSheet: View {
    let isDepositing: Bool
    let currentBalance: Double
    var onConfirm: (Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double?
    @FocusState private var isFocused: Bool
    
    private var isOverDrawing: Bool {
        !isDepositing && (amount ?? 0) > currentBalance
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Image(systemName: isDepositing ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(isDepositing ? .green : .red)
                        .padding(.top, 20)
                    
                    Text(isDepositing ? "Deposit Funds" : "Withdraw Funds")
                        .font(.title2.bold())
                    
                    Text(isDepositing ? "Increase your baseline trading capital" : "Record a withdrawal from your trading account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                HStack {
                    Text("$")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    TextField("0.00", value: $amount, format: .number)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .focused($isFocused)
                        .multilineTextAlignment(.leading)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 250)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                if isOverDrawing {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Insufficient Funds")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.top, -20)
                }
                
                Spacer()
                
                Button {
                    if let val = amount {
                        onConfirm(val)
                    }
                    dismiss()
                } label: {
                    Text(isOverDrawing ? "Cannot Withdraw" : "Confirm \(isDepositing ? "Deposit" : "Withdrawal")")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isOverDrawing ? Color.gray : (isDepositing ? Color.green : Color.red))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                .disabled(amount == nil || amount == 0 || isOverDrawing)
                .opacity(amount == nil || amount == 0 || isOverDrawing ? 0.5 : 1.0)
                .padding(.bottom, 30)
            }
            .background(
                LinearGradient(
                    colors: [
                        (isDepositing ? Color.green : Color.red).opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 450)
        #endif
        .onMouseBackButton()
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    SettingsView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
