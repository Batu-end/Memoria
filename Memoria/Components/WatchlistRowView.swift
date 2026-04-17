//
//  WatchlistRowView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.
//  Redesigned with live price display.

import SwiftUI

struct WatchlistRowView: View {
    let item: WatchlistItem
    let deleteItem: () -> Void
    
    private var strokeColor: Color {
        if let changeSince = item.changeSinceAdded {
            return changeSince >= 0 ? .green : .red
        }
        return .purple
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Ticker + Date Added
            VStack(alignment: .leading, spacing: 4) {
                Text(item.ticker)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Added \(item.dateAdded, format: .dateTime.month(.abbreviated).day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Center: Current Price
            if let price = item.currentPrice {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price, format: .currency(code: "USD"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Daily change
                    if let change = item.priceChange, let pct = item.priceChangePercent {
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            
                            Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f") (\(pct, specifier: "%.2f")%)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(change >= 0 ? Color.green : Color.red)
                    }
                }
            } else {
                // Loading state
                VStack(alignment: .trailing, spacing: 2) {
                    Text("—")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }


            // Delete button
            Button(action: deleteItem) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: strokeColor.opacity(0.1), radius: 5, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(strokeColor.opacity(0.2), lineWidth: 1)
        )
    }
}
