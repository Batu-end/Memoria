//
//  WatchlistRowView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//

import SwiftUI

// Renamed from TradeRowView to avoid confusion
struct WatchlistRowView: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.ticker)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Status badge not really needed for pure watchlist items anymore,
                // but we can keep a "Watching" badge or remove it. Let's keep it simple.
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let price = item.priceAtAdd {
                    HStack(spacing: 4) {
                        Image(systemName: "target") // Target icon
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(price, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("--")
                        .font(.caption)
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
