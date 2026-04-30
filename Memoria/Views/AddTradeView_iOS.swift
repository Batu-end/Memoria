//
//  AddTradeView_iOS.swift
//  Memoria

#if os(iOS)
import SwiftUI
import SwiftData

struct AddTradeView_iOS: View {
    @Bindable var viewModel: AddTradeViewModel
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {

                // ── Asset ─────────────────────────────────
                Section("Asset") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Ticker", text: $vm.ticker)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: vm.ticker) { _, v in vm.ticker = v.uppercased() }
                    }

                    Picker("Asset Type", selection: $vm.assetType) {
                        ForEach(AssetType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                // ── Execution ─────────────────────────────
                Section("Execution") {
                    Picker("Side", selection: $vm.side) {
                        ForEach(TradeSide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Entry Price")
                        Spacer()
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $vm.priceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    HStack {
                        Toggle(isOn: $vm.useSharesMode) {
                            Text(vm.useSharesMode ? "Shares" : "Capital")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.mini)
                        Spacer()
                        Text(vm.useSharesMode ? "×" : "$").foregroundStyle(.secondary)
                        TextField("0.00", text: vm.useSharesMode ? $vm.sharesString : $vm.capitalString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    if let shares = vm.effectiveShares, let capital = vm.effectiveCapital, shares > 0 {
                        LabeledContent(vm.useSharesMode ? "Capital Required" : "Estimated Shares") {
                            Text(vm.useSharesMode
                                 ? capital.formatted(.currency(code: "USD"))
                                 : String(format: "%.4f shares", shares))
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                    }
                }

                // ── Risk ──────────────────────────────────
                Section("Risk") {
                    HStack {
                        Text("Stop Loss")
                        Spacer()
                        Text("$").foregroundStyle(.red.opacity(0.7))
                        TextField("—", text: $vm.stopLossString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    HStack {
                        Text("Take Profit")
                        Spacer()
                        Text("$").foregroundStyle(.green.opacity(0.7))
                        TextField("—", text: $vm.takeProfitString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    if let rr = vm.riskReward {
                        let color: Color = rr >= 2 ? .green : rr >= 1 ? .orange : .red
                        LabeledContent("Risk : Reward") {
                            Text("1 : \(rr, specifier: "%.1f")")
                                .fontWeight(.bold)
                                .foregroundStyle(color)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(color.opacity(0.1), in: Capsule())
                        }
                    }
                }

                // ── Strategy & Notes ──────────────────────
                Section("Strategy & Notes") {
                    Picker("Strategy", selection: $vm.selectedStrategy) {
                        Text("None").tag(TradeStrategy?.none)
                        ForEach(TradeStrategy.allCases.filter { $0 != .other }, id: \.self) { strat in
                            Text(strat.rawValue).tag(TradeStrategy?.some(strat))
                        }
                        Text("Other").tag(TradeStrategy?.some(.other))
                    }

                    if vm.selectedStrategy == .other {
                        TextField("Custom strategy name", text: $vm.customStrategy)
                    }

                    LabeledContent("Confidence") {
                        StarRatingView(rating: $vm.confidenceScore)
                    }

                    TextEditor(text: $vm.notes)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(3)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if vm.notes.isEmpty {
                                Text("Tap to add your notes...")
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.horizontal, 6)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // ── Past Trade ────────────────────────────
                if vm.isPastTrade {
                    Section("Trade History") {
                        DatePicker("Open Date", selection: $vm.openDate, displayedComponents: .date)

                        HStack {
                            Text("Exit Price")
                            Spacer()
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $vm.exitPriceString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }

                        DatePicker("Close Date", selection: $vm.closeDate, displayedComponents: .date)

                        if let pnl = vm.estimatedPnl {
                            LabeledContent("Realized P&L") {
                                Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(pnl >= 0 ? .green : .red)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(vm.isPastTrade ? "Log Past Trade" : "New Trade")
            .darkNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.isPastTrade.toggle() }
                    } label: {
                        Image(systemName: vm.isPastTrade ? "bolt.fill" : "clock.arrow.circlepath")
                    }
                    .foregroundStyle(vm.isPastTrade ? .orange : .secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isPastTrade ? "Log" : "Open") {
                        viewModel.saveTrade(context: modelContext, portfolio: portfolio)
                        dismiss()
                    }
                    .disabled(!vm.isValid)
                    .tint(vm.isValid ? .green : nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
#endif
