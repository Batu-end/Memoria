//
//  TradeRowView.swift
//  Memoria
//
//  Reusable row component for displaying a trade in a list.
//

import SwiftUI

struct TradeRowView: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Ticker + Side Badge
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Side Badge
                    Text(trade.side.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trade.side == .long ? Color.green : Color.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (trade.side == .long ? Color.green : Color.red).opacity(0.15)
                        )
                        .clipShape(Capsule())
                    
                    // Asset Type Badge
                    if trade.assetType == .etf {
                        Text("ETF")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                // Entry info
                HStack(spacing: 8) {
                    if let entry = trade.entryPrice {
                        Text(entry, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let qty = trade.quantity {
                        Text("×\(Int(qty))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(trade.dateAdded, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Middle: Strategy tag
            if let strategy = trade.strategy, !strategy.isEmpty {
                Text(strategy)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            
            // Right: P&L or Status
            VStack(alignment: .trailing, spacing: 4) {
                if trade.status == .closed, let pnl = trade.pnl {
                    Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
                    
                    if let pct = trade.percentReturn {
                        Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle((pct >= 0 ? Color.green : Color.red).opacity(0.8))
                    }
                } else {
                    Text("OPEN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
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
