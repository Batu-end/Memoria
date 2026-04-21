//
//  WatchlistRowView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.

import SwiftUI

struct WatchlistRowView: View {
    let item: WatchlistItem
    let deleteItem: () -> Void

    @State private var isHovered = false

    private var changeColor: Color {
        guard let pct = item.priceChangePercent else { return .purple }
        return pct >= 0 ? .green : .red
    }

    var body: some View {
        HStack(spacing: 12) {
            TickerLogoView(ticker: item.ticker, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.ticker)
                    .font(.system(size: 15, weight: .bold))

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Added \(item.dateAdded, format: .dateTime.month(.abbreviated).day())")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let price = item.currentPrice {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price, format: .currency(code: "USD"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    if let change = item.priceChange, let pct = item.priceChangePercent {
                        HStack(spacing: 3) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f") (\(pct, specifier: "%.2f")%)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(changeColor)
                    }
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("—")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Loading…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if let changeSince = item.changeSinceAdded {
                Divider().frame(height: 28).padding(.horizontal, 2)

                VStack(spacing: 2) {
                    Text("All-Time")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text("\(changeSince >= 0 ? "+" : "")\(changeSince, specifier: "%.1f")%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(changeSince >= 0 ? Color.green : Color.red)
                }
            }

            Button(action: deleteItem) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(isHovered ? 0.15 : 0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(changeColor.opacity(0.18), lineWidth: 1)
        )
    }
}
