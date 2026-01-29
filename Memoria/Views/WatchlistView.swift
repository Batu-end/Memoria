//
//  WatchlistView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/29/26.
//

import SwiftUI

// Visualization
struct WatchlistView: View {
    @State private var showAddTrade = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                // Static List for UI check
                List {
                    TradeRowView(ticker: "AAPL", price: 153.20, status: "Watchlist")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    
                    TradeRowView(ticker: "TSLA", price: 67.67, status: "Watchlist") // Example with no price
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showAddTrade = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
                    .presentationDetents([.medium])
            }
        }
    }
}

// Minimal Row Component for visualization
struct TradeRowView: View {
    let ticker: String
    let price: Double?
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticker)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let price = price {
                    Text(price, format: .currency(code: "USD"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("--")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    WatchlistView()
}
