//
//  AddWatchlistItemView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import SwiftUI
import SwiftData

struct AddWatchlistItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var ticker = ""
    @State private var priceString = ""
    
    // Validation Logic
    private var isValidPrice: Bool {
        return priceString.isEmpty || Double(priceString) != nil // Optional, so empty is valid
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark Background
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Ticker Field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TICKER")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            
                            TextField("e.g. AAPL", text: $ticker)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                )
                        }
                        
                        // Target Price Field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TARGET PRICE (Optional)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                            
                            TextField("0.00", text: $priceString)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            (!isValidPrice)
                                                ? AnyShapeStyle(.red)
                                                : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                                            lineWidth: 1
                                        )
                                )
                            
                            if !isValidPrice {
                                Text("Please enter a valid number")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(24)
                    
                    Spacer()
                    
                    // --- "ADD" BUTTON ---
                    Button(action: {
                        let item = WatchlistItem(ticker: ticker.isEmpty ? "UNKNOWN" : ticker)
                        if let price = Double(priceString) {
                            item.priceAtAdd = price
                        }
                        modelContext.insert(item)
                        dismiss()
                    }) {
                        Text("Track Stock")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: (ticker.isEmpty || !isValidPrice) ? [.gray, .gray] : [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                            .opacity((ticker.isEmpty || !isValidPrice) ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(ticker.isEmpty || !isValidPrice)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Add to Watchlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
