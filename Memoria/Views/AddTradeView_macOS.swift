//
//  AddTradeView_macOS.swift
//  Memoria

#if os(macOS)
import SwiftUI
import SwiftData

struct AddTradeView_macOS: View {
    @Bindable var viewModel: AddTradeViewModel
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {

                // ── Essentials ───────────────────────────
                Section {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            ZStack(alignment: .leading) {
                                if vm.ticker.isEmpty {
                                    Text("Ticker")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                        .allowsHitTesting(false)
                                }
                                TextField("", text: $vm.ticker)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: 100)
                                    .onChange(of: vm.ticker) { _, v in vm.ticker = v.uppercased() }
                            }
                        }

                        Divider()

                        Picker("", selection: $vm.side) {
                            ForEach(TradeSide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented).frame(width: 120)

                        Picker("", selection: $vm.assetType) {
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
                                    if vm.priceString.isEmpty {
                                        Text("0.00").foregroundStyle(.tertiary)
                                            .font(.system(.title3, design: .monospaced))
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text: $vm.priceString)
                                        .font(.system(.title3, design: .monospaced))
                                        .textFieldStyle(.plain)
                                }
                                Spacer()
                            }
                        }

                        Divider().frame(height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(vm.useSharesMode ? "Shares" : "Capital")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Button(vm.useSharesMode ? "Switch to $" : "Switch to shares") {
                                    vm.useSharesMode.toggle()
                                }
                                .font(.system(size: 10)).foregroundStyle(.blue).buttonStyle(.plain)
                            }
                            HStack(spacing: 4) {
                                Text(vm.useSharesMode ? "×" : "$").foregroundStyle(.secondary)
                                ZStack(alignment: .leading) {
                                    let activeString = vm.useSharesMode ? vm.sharesString : vm.capitalString
                                    if activeString.isEmpty {
                                        Text("0.00").foregroundStyle(.tertiary)
                                            .font(.system(.title3, design: .monospaced))
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text: vm.useSharesMode ? $vm.sharesString : $vm.capitalString)
                                        .font(.system(.title3, design: .monospaced))
                                        .textFieldStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                    }

                    if let shares = vm.effectiveShares, let capital = vm.effectiveCapital, shares > 0 {
                        LabeledContent(vm.useSharesMode ? "Capital Required" : "Estimated Shares") {
                            Text(vm.useSharesMode
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
                                    if vm.stopLossString.isEmpty { Text("—").foregroundStyle(.tertiary).font(.system(.body, design: .monospaced)).allowsHitTesting(false) }
                                    TextField("", text: $vm.stopLossString).font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                                }
                            }
                        }

                        Divider().frame(height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take Profit").font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$").foregroundStyle(.green.opacity(0.7))
                                ZStack(alignment: .leading) {
                                    if vm.takeProfitString.isEmpty { Text("—").foregroundStyle(.tertiary).font(.system(.body, design: .monospaced)).allowsHitTesting(false) }
                                    TextField("", text: $vm.takeProfitString).font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                                }
                            }
                        }
                    }

                    if let rr = vm.riskReward {
                        let color: Color = rr >= 2 ? .green : rr >= 1 ? .orange : .red
                        LabeledContent("Risk : Reward") {
                            Text("1 : \(rr, specifier: "%.1f")")
                                .font(.system(.body, design: .rounded).weight(.bold))
                                .foregroundStyle(color)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(color.opacity(0.1), in: Capsule())
                        }
                    }

                    Picker("Strategy", selection: $vm.selectedStrategy) {
                        Text("None").tag(TradeStrategy?.none)
                        ForEach(TradeStrategy.allCases.filter { $0 != .other }, id: \.self) { strat in
                            Text(strat.rawValue).tag(TradeStrategy?.some(strat))
                        }
                        Text("Other").tag(TradeStrategy?.some(.other))
                    }
                    .pickerStyle(.menu)

                    if vm.selectedStrategy == .other {
                        TextField("Custom strategy name", text: $vm.customStrategy)
                    }

                    LabeledContent("Confidence") {
                        StarRatingView(rating: $vm.confidenceScore)
                    }

                    TextEditor(text: $vm.notes)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(3)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if vm.notes.isEmpty {
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
                if vm.isPastTrade {
                    Section {
                        DatePicker("Open Date", selection: $vm.openDate, displayedComponents: .date)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exit Price").font(.subheadline).foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text("$").foregroundStyle(.secondary)
                                    ZStack(alignment: .leading) {
                                        if vm.exitPriceString.isEmpty { Text("0.00").foregroundStyle(.tertiary).font(.system(.title3, design: .monospaced)).allowsHitTesting(false) }
                                        TextField("", text: $vm.exitPriceString).font(.system(.title3, design: .monospaced)).textFieldStyle(.plain)
                                    }
                                }
                            }
                            Divider().frame(height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Close Date").font(.subheadline).foregroundStyle(.secondary)
                                DatePicker("", selection: $vm.closeDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }

                        if let pnl = vm.estimatedPnl {
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
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(vm.isPastTrade ? "Log Past Trade" : "New Trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.isPastTrade.toggle() }
                    } label: {
                        Label(
                            vm.isPastTrade ? "Live Trade" : "Log Past Trade",
                            systemImage: vm.isPastTrade ? "bolt.fill" : "clock.arrow.circlepath"
                        )
                        .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(vm.isPastTrade ? .orange : .secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isPastTrade ? "Log Trade" : "Open Trade") {
                        viewModel.saveTrade(context: modelContext, portfolio: portfolio)
                        dismiss()
                    }
                    .disabled(!vm.isValid)
                    .tint(vm.isValid ? .green : nil)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .onMouseBackButton()
    }
}
#endif
