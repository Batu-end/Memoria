//
//  AddTradeView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//  Redesigned for a premium native macOS feel.

import SwiftUI
import SwiftData

struct AddTradeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = AddTradeViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                // ── Core Trade Info ──────────────────────
                Section {
                    // Ticker — the most important field, make it feel prominent
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Ticker symbol", text: $viewModel.ticker)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    
                    // Side + Type in a compact row
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Side")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $viewModel.side) {
                                ForEach(TradeSide.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Type")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $viewModel.assetType) {
                                ForEach(AssetType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                    }
                } header: {
                    Label("Trade", systemImage: "arrow.up.arrow.down")
                }
                
                // ── Pricing ─────────────────────────────
                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry Price")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $viewModel.priceString)
                                    .font(.system(.title3, design: .monospaced))
                            }
                        }
                        
                        Divider().frame(height: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Capital Spent")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $viewModel.capitalString)
                                    .font(.system(.title3, design: .monospaced))
                            }
                        }
                    }
                    
                    // Estimated Shares Preview
                    if let price = Double(viewModel.priceString),
                       let capital = Double(viewModel.capitalString),
                       price > 0 && capital > 0 {
                        HStack {
                            Text("Estimated Shares")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(capital / price, specifier: "%.4f") shares")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Label("Pricing", systemImage: "dollarsign.circle")
                }
                
                // ── Strategy & Risk ─────────────────────
                Section {
                    Picker("Strategy", selection: $viewModel.selectedStrategy) {
                        Text("None").tag(Optional<TradeStrategy>.none)
                        ForEach(TradeStrategy.allCases, id: \.self) { strat in
                            Text(strat.rawValue).tag(Optional(strat))
                        }
                    }
                    
                    if viewModel.selectedStrategy == .other {
                        TextField("Custom strategy name", text: $viewModel.customStrategy)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stop Loss")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundStyle(.red.opacity(0.7))
                                TextField("—", text: $viewModel.stopLossString)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        
                        Divider().frame(height: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take Profit")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundStyle(.green.opacity(0.7))
                                TextField("—", text: $viewModel.takeProfitString)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    
                    // R:R Preview
                    if let entry = Double(viewModel.priceString),
                       let sl = Double(viewModel.stopLossString),
                       let tp = Double(viewModel.takeProfitString) {
                        let risk = abs(entry - sl)
                        let reward = abs(tp - entry)
                        if risk > 0 {
                            HStack {
                                Text("Risk : Reward")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("1 : \(reward / risk, specifier: "%.1f")")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Label("Strategy & Risk", systemImage: "shield.lefthalf.filled")
                }
                
                // ── Conviction ──────────────────────────
                Section {
                    HStack {
                        Text("Confidence")
                            .foregroundStyle(.secondary)
                        Spacer()
                        StarRatingView(rating: $viewModel.confidenceScore)
                    }
                } header: {
                    Label("Conviction", systemImage: "brain.head.profile")
                }
                
                // ── Past Trade Dates ────────────────────
                if viewModel.isPastTrade {
                    Section {
                        DatePicker("Open Date", selection: $viewModel.openDate, displayedComponents: .date)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exit Price")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text("$").foregroundStyle(.secondary)
                                    TextField("0.00", text: $viewModel.exitPriceString)
                                        .font(.system(.title3, design: .monospaced))
                                }
                            }

                            Divider().frame(height: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Close Date")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                DatePicker("", selection: $viewModel.closeDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }

                        if let entry = Double(viewModel.priceString),
                           let exit = Double(viewModel.exitPriceString),
                           let capital = Double(viewModel.capitalString),
                           entry > 0, capital > 0 {
                            let qty = capital / entry
                            let direction: Double = viewModel.side == .long ? 1 : -1
                            let pnl = (exit - entry) * qty * direction
                            HStack {
                                Text("Realized P&L")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(pnl >= 0 ? .green : .red)
                            }
                        }
                    } header: {
                        Label("Trade History", systemImage: "clock.arrow.circlepath")
                    }
                }

                // ── Notes ───────────────────────────────
                Section {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 60)
                } header: {
                    Label("Notes", systemImage: "note.text")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(
                Color(nsColor: .windowBackgroundColor)
            )
            .navigationTitle(viewModel.isPastTrade ? "Log Past Trade" : "New Trade")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isPastTrade.toggle()
                        }
                    } label: {
                        Label(
                            viewModel.isPastTrade ? "Live Trade" : "Log Past Trade",
                            systemImage: viewModel.isPastTrade ? "bolt.fill" : "clock.arrow.circlepath"
                        )
                        .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(viewModel.isPastTrade ? .orange : .secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isPastTrade ? "Log Trade" : "Open Trade") {
                        viewModel.addTrade(context: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isValidForm)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 520)
        .onMouseBackButton()
    }
}

#Preview {
    AddTradeView()
        .preferredColorScheme(.dark)
}
