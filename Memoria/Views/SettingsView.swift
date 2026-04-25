//
//  SettingsView.swift
//  Memoria
//
//  Created by Batu Demirtas on 4/17/26.
//

import SwiftUI
import SwiftData
import Combine

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trades: [Trade]
    @Query private var watchlistItems: [WatchlistItem]
    @Query private var accountSnapshots: [AccountSnapshot]
    @Query private var activityLogs: [ActivityLog]
    
    @AppStorage("startingBalance", store: .app) private var startingBalance: Double = 0.0
    @AppStorage("traderName", store: .app) private var traderName: String = ""
    @AppStorage("traderPersonality", store: .app) private var personalityRaw: String = TraderPersonality.human.rawValue
    private var personality: TraderPersonality { TraderPersonality(rawValue: personalityRaw) ?? .human }
    
    @AppStorage("mathEngineInspector", store: .app) private var mathEngineInspectorEnabled: Bool = false
    @AppStorage("unreadableDate", store: .app) private var unreadableDate: Bool = false
    @AppStorage("monochromeLogos", store: .app) private var monochromeLogos: Bool = false

    @State private var showingResetAlert = false
    @State private var confirmationText = ""

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
                    HStack {
                        Label("Name", systemImage: "person.crop.circle.fill")
                        TextField("", text: $traderName, prompt: Text("Enter your name"))
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.blue)
                    }

                    HStack {
                        Label("I am a...", systemImage: "theatermasks.fill")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { personality },
                            set: { personalityRaw = $0.rawValue }
                        )) {
                            ForEach(TraderPersonality.allCases, id: \.self) { p in
                                Text("\(p.emoji) \(p.rawValue)").tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
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
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 30)
                            
                            // Net Deposits (In vs Out)
                            VStack(spacing: 4) {
                                Text(startingBalance >= 0 ? "NET CONTRIBUTION" : "HOUSE MONEY")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                
                                Text(abs(startingBalance), format: .currency(code: "USD"))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(startingBalance >= 0 ? Color.primary : Color.orange)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Nearly unreadable date", systemImage: "character.cursor.ibeam")
                            Text("Calligraphic font on the date header. Looks cool, barely readable.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                    Toggle(isOn: $monochromeLogos) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Monochrome logos", systemImage: "circle.lefthalf.filled")
                            Text("Strips color from all ticker logos.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle(isOn: $mathEngineInspectorEnabled) {
                        Label("Math Engine Inspector", systemImage: "function")
                    }
                } header: {
                    Text("Developer Tools")
                } footer: {
                    Text("Shows live accounting engine state in the Dashboard for debugging.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmationText = ""
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Label("Erase All Data", systemImage: "trash")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account Data")
                        .foregroundStyle(.red)
                } footer: {
                    Text("This will permanently delete all your trades and watchlist history. This action cannot be undone.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()
                )
                .navigationTitle("Settings")
                .task {
                    await fetchLiveQuotes()
                }
                .onReceive(refreshTimer) { _ in
                    Task { await fetchLiveQuotes() }
                }
                .sheet(item: $capitalAction) { action in
                    CapitalAdjustmentSheet(isDepositing: action == .deposit, currentBalance: currentBalance) { amount in
                        if action == .deposit {
                            startingBalance += amount
                        } else {
                            startingBalance -= amount
                        }
                    }
                }
            .alert("Erase All Data?", isPresented: $showingResetAlert) {
                TextField("Type \"DELETE\" to confirm", text: $confirmationText)
                
                Button("Cancel", role: .cancel) { }
                
                Button("Erase Data", role: .destructive) {
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
        let totalPnl = trades.filter { $0.status == .closed }.compactMap { trade -> Double? in
            trade.math?.totalPnl
        }.reduce(0, +)
        return startingBalance + totalPnl + totalFloatingPnl
    }
    
    private func fetchLiveQuotes() async {
        let openTrades = trades.filter { $0.status == .open }
        guard !openTrades.isEmpty else { return }
        let symbols = openTrades.map { $0.ticker }
        let newQuotes = await StockQuoteService.shared.fetchQuotes(for: symbols)
        liveQuotes.merge(newQuotes) { (_, new) in new }
    }
    
    private func eraseAllData() {
        for trade in trades { modelContext.delete(trade) }
        for item in watchlistItems { modelContext.delete(item) }
        for snapshot in accountSnapshots { modelContext.delete(snapshot) }
        for log in activityLogs { modelContext.delete(log) }
        try? modelContext.save()

        startingBalance = 0.0
        traderName = ""
        personalityRaw = TraderPersonality.human.rawValue
        unreadableDate = false
        mathEngineInspectorEnabled = false
        monochromeLogos = false

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
        .frame(width: 400, height: 450)
        .onMouseBackButton()
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
