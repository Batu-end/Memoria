//
//  AddWatchlistItemView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.

import SwiftUI
import SwiftData

struct AddWatchlistItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var ticker = ""
    @State private var isLookingUp = false
    @State private var lookedUpPrice: Double?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Ticker symbol", text: $ticker)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .onSubmit {
                                Task { await lookupPrice() }
                            }
                    }
                } header: {
                    Label("Stock", systemImage: "chart.line.uptrend.xyaxis")
                } footer: {
                    if isLookingUp {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                            Text("Looking up \(ticker.uppercased())...")
                        }
                    } else if let price = lookedUpPrice {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Current price: \(price, format: .currency(code: "USD"))")
                        }
                    } else if !ticker.isEmpty {
                        Text("Press Return to look up the current price")
                    }
                }

            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Add to Watchlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Track") {
                        addItem()
                    }
                    .disabled(ticker.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 180)
        .onMouseBackButton()
        .onAppear {
            ticker = ""
            isLookingUp = false
            lookedUpPrice = nil
        }
    }
    
    private func addItem() {
        let item = WatchlistItem(ticker: ticker.uppercased())
        
        if let looked = lookedUpPrice {
            item.priceAtAdd = looked
        }
        
        modelContext.insert(item)
        AnalyticsService.shared.log(.watchlistItemAdded, details: "Ticker: \(ticker)", context: modelContext)
        dismiss()
    }
    
    private func lookupPrice() async {
        let symbol = ticker.trimmingCharacters(in: .whitespaces).uppercased()
        guard !symbol.isEmpty else { return }
        
        isLookingUp = true
        lookedUpPrice = nil
        
        if let quote = await StockQuoteService.shared.fetchQuote(for: symbol) {
            lookedUpPrice = quote.currentPrice
        }
        
        isLookingUp = false
    }
}

#Preview {
    AddWatchlistItemView()
        .preferredColorScheme(.dark)
}
