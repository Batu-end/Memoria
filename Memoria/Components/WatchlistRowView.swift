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
            
            // Change since added (if meaningful)
            if let changeSince = item.changeSinceAdded {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Since add")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text("\(changeSince >= 0 ? "+" : "")\(changeSince, specifier: "%.1f")%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(changeSince >= 0 ? Color.green : Color.red)
                }
                .padding(.leading, 4)
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
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
