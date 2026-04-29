//
//  AddTradeView.swift
//  Memoria

import SwiftUI
import SwiftData

struct AddTradeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // All state lives here — no @Observable binding layer
    @State private var ticker = ""
    @State private var priceString = ""
    @State private var capitalString = ""
    @State private var sharesString = ""
    @State private var useSharesMode = false
    @State private var side: TradeSide = .long
    @State private var assetType: AssetType = .stock
    @State private var selectedStrategy: TradeStrategy? = nil
    @State private var customStrategy = ""
    @State private var stopLossString = ""
    @State private var takeProfitString = ""
    @State private var confidenceScore = 0
    @State private var notes = ""
    @State private var isPastTrade = false
    @State private var openDate = Date()
    @State private var exitPriceString = ""
    @State private var closeDate = Date()

    // MARK: - Computed
    private var price: Double? { Double(priceString) }
    private var capital: Double? { Double(capitalString) }
    private var shares: Double? { Double(sharesString) }
    private var stopLoss: Double? { Double(stopLossString) }
    private var takeProfit: Double? { Double(takeProfitString) }
    private var exitPrice: Double? { Double(exitPriceString) }

    private var effectiveCapital: Double? {
        if useSharesMode, let s = shares, let p = price, p > 0 { return s * p }
        return capital
    }

    private var effectiveShares: Double? {
        if let p = price, p > 0 {
            if useSharesMode { return shares }
            if let c = capital { return c / p }
        }
        return nil
    }

    private var riskReward: Double? {
        guard let entry = price, let sl = stopLoss, let tp = takeProfit else { return nil }
        let risk = abs(entry - sl)
        let reward = abs(tp - entry)
        guard risk > 0 else { return nil }
        return reward / risk
    }

    private var estimatedPnl: Double? {
        guard let entry = price, let exit = exitPrice,
              let c = effectiveCapital, entry > 0 else { return nil }
        return (exit - entry) * (c / entry) * (side == .long ? 1.0 : -1.0)
    }

    private var isValid: Bool {
        guard !ticker.isEmpty, price != nil else { return false }
        let hasSize = effectiveCapital != nil
        if isPastTrade { return hasSize && exitPrice != nil }
        return hasSize
    }

    var body: some View {
        NavigationStack {
            Form {

                // ── Essentials ───────────────────────────
                Section {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            ZStack(alignment: .leading) {
                                if ticker.isEmpty {
                                    Text("Ticker")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                        .allowsHitTesting(false)
                                        // .padding(.leading, 48)
                                }
                                TextField("", text:$ticker)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: 100)
                                    .onChange(of: ticker) { _, v in ticker = v.uppercased() }
                            }
                        }

                        Divider()

                        Picker("", selection: $side) {
                            ForEach(TradeSide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented).frame(width: 120)

                        Picker("", selection: $assetType) {
                            ForEach(AssetType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented).frame(width: 130)
                    }

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry Price").font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$").foregroundStyle(.secondary)
                                ZStack(alignment: .leading) {
                                    if priceString.isEmpty {
                                        Text("0.00").foregroundStyle(.tertiary)
                                            .font(.system(.title3, design: .monospaced))
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text:$priceString)
                                        .font(.system(.title3, design: .monospaced))
                                        .textFieldStyle(.plain)
                                }
                                Spacer()
                            }
                        }

                        Divider().frame(height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(useSharesMode ? "Shares" : "Capital")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Button(useSharesMode ? "Switch to $" : "Switch to shares") {
                                    useSharesMode.toggle()
                                }
                                .font(.system(size: 10)).foregroundStyle(.blue).buttonStyle(.plain)
                            }
                            HStack(spacing: 4) {
                                Text(useSharesMode ? "×" : "$").foregroundStyle(.secondary)
                                ZStack(alignment: .leading) {
                                    let activeString = useSharesMode ? sharesString : capitalString
                                    if activeString.isEmpty {
                                        Text("0.00").foregroundStyle(.tertiary)
                                            .font(.system(.title3, design: .monospaced))
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text:useSharesMode ? $sharesString : $capitalString)
                                        .font(.system(.title3, design: .monospaced))
                                        .textFieldStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                    }

                    if let shares = effectiveShares, let capital = effectiveCapital, shares > 0 {
                        LabeledContent(useSharesMode ? "Capital Required" : "Estimated Shares") {
                            Text(useSharesMode
                                 ? capital.formatted(.currency(code: "USD"))
                                 : String(format: "%.4f shares", shares))
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // ── Optional ─────────────────────────────
                Section {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stop Loss").font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$").foregroundStyle(.red.opacity(0.7))
                                ZStack(alignment: .leading) {
                                    if stopLossString.isEmpty { Text("—").foregroundStyle(.tertiary).font(.system(.body, design: .monospaced)).allowsHitTesting(false) }
                                    TextField("", text:$stopLossString).font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                                }
                            }
                        }

                        Divider().frame(height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take Profit").font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$").foregroundStyle(.green.opacity(0.7))
                                ZStack(alignment: .leading) {
                                    if takeProfitString.isEmpty { Text("—").foregroundStyle(.tertiary).font(.system(.body, design: .monospaced)).allowsHitTesting(false) }
                                    TextField("", text:$takeProfitString).font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                                }
                            }
                        }
                    }

                    if let rr = riskReward {
                        let color: Color = rr >= 2 ? .green : rr >= 1 ? .orange : .red
                        LabeledContent("Risk : Reward") {
                            Text("1 : \(rr, specifier: "%.1f")")
                                .font(.system(.body, design: .rounded).weight(.bold))
                                .foregroundStyle(color)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(color.opacity(0.1), in: Capsule())
                        }
                    }

                    Picker("Strategy", selection: $selectedStrategy) {
                        Text("None").tag(TradeStrategy?.none)
                        ForEach(TradeStrategy.allCases.filter { $0 != .other }, id: \.self) { strat in
                            Text(strat.rawValue).tag(TradeStrategy?.some(strat))
                        }
                        Text("Other").tag(TradeStrategy?.some(.other))
                    }
                    .pickerStyle(.menu)

                    if selectedStrategy == .other {
                        TextField("Custom strategy name", text: $customStrategy)
                    }

                    LabeledContent("Confidence") {
                        StarRatingView(rating: $confidenceScore)
                    }

                    TextEditor(text: $notes)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(3)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Tap to add your notes...")
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 1)
                                    .padding(.leading, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Optional").foregroundStyle(.tertiary).font(.footnote)
                }

                // ── Past Trade ───────────────────────────
                if isPastTrade {
                    Section {
                        DatePicker("Open Date", selection: $openDate, displayedComponents: .date)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exit Price").font(.subheadline).foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text("$").foregroundStyle(.secondary)
                                ZStack(alignment: .leading) {
                                    if exitPriceString.isEmpty { Text("0.00").foregroundStyle(.tertiary).font(.system(.title3, design: .monospaced)).allowsHitTesting(false) }
                                    TextField("", text:$exitPriceString).font(.system(.title3, design: .monospaced)).textFieldStyle(.plain)
                                }
                                }
                            }
                            Divider().frame(height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Close Date").font(.subheadline).foregroundStyle(.secondary)
                                DatePicker("", selection: $closeDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }

                        if let pnl = estimatedPnl {
                            LabeledContent("Realized P&L") {
                                Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(pnl >= 0 ? .green : .red)
                            }
                        }
                    } header: {
                        Text("Trade History").foregroundStyle(.tertiary).font(.footnote)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .navigationTitle(isPastTrade ? "Log Past Trade" : "New Trade")
            .darkNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isPastTrade.toggle() }
                    } label: {
                        Label(
                            isPastTrade ? "Live Trade" : "Log Past Trade",
                            systemImage: isPastTrade ? "bolt.fill" : "clock.arrow.circlepath"
                        )
                        .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isPastTrade ? .orange : .secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPastTrade ? "Log Trade" : "Open Trade") {
                        saveTrade()
                        dismiss()
                    }
                    .disabled(!isValid)
                    .tint(isValid ? .green : nil)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .onMouseBackButton()
    }

    // MARK: - Save
    private func saveTrade() {
        guard let p = price else { return }
        let status: TradeStatus = isPastTrade ? .closed : .open
        let trade = Trade(ticker: ticker.uppercased(), status: status, side: side, assetType: assetType)

        trade.entryPrice = p
        trade.dateAdded = isPastTrade ? openDate : Date()
        if let qty = effectiveShares { trade.quantity = qty }
        trade.stopLoss = stopLoss
        trade.takeProfit = takeProfit
        trade.strategy = resolvedStrategy
        trade.notes = notes.isEmpty ? nil : notes
        trade.confidenceScore = confidenceScore

        let openExecType: ExecutionType = side == .long ? .buy : .sell
        if let qty = effectiveShares {
            trade.executions.append(Execution(price: p, quantity: qty, type: openExecType, date: isPastTrade ? openDate : Date()))
        }

        if isPastTrade, let exit = exitPrice, let qty = effectiveShares {
            let closeExecType: ExecutionType = side == .long ? .sell : .buy
            trade.executions.append(Execution(price: exit, quantity: qty, type: closeExecType, date: closeDate))
            trade.exitPrice = exit
            trade.dateClosed = closeDate
        }

        modelContext.insert(trade)
        AnalyticsService.shared.log(
            isPastTrade ? .tradeClosed : .tradeOpened,
            details: "Ticker: \(ticker), Side: \(side.rawValue)",
            context: modelContext
        )
    }

    private var resolvedStrategy: String? {
        guard let strat = selectedStrategy else { return nil }
        return strat == .other ? (customStrategy.isEmpty ? nil : customStrategy) : strat.rawValue
    }
}

#Preview {
    AddTradeView().preferredColorScheme(.dark)
}
