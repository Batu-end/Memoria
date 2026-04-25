//
//  TradeRowView.swift
//  Memoria
//
//  Reusable row component for displaying a trade in a list.
//

import SwiftUI

struct TradeRowView: View {
    var engine = AccountingEngine.shared
    let trade: Trade
    
    init(trade: Trade) {
        self.trade = trade
    }
    var math: TradeAccounting? {
        engine.tradeAccounting[trade.id]
    }
    
    private var strokeColor: Color {
        if trade.status == .closed {
            if let pnl = math?.totalPnl {
                return pnl >= 0 ? .green : .red
            }
            return .purple
        }
        return .blue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            TickerLogoView(ticker: trade.ticker, size: 40)
            
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
                
                // Confidence Stars
                if trade.confidenceScore > 0 {
                    HStack(spacing: 4) {
                        Text("Confidence")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            ForEach(0..<trade.confidenceScore, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.0))
                            }
                        }
                    }
                    .padding(.top, -2)
                }
                
                // Entry info
                HStack(spacing: 8) {
                    if let entry = math?.vwap {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Entry")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.tertiary)
                            Text(entry, format: .currency(code: "USD"))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    let qty = math?.effectiveQuantity ?? 0
                    if qty > 0 {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Shares")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.tertiary)
                            Text(qty.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", qty) : String(format: "%.2f", qty))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Date")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(trade.dateAdded, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            
            // Right: P&L or live unrealized
            VStack(alignment: .trailing, spacing: 4) {
                if trade.status == .closed, let pnl = math?.totalPnl {
                    Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(pnl >= 0 ? Color.green : Color.red)

                    if let pct = math?.percentReturn {
                        Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle((pct >= 0 ? Color.green : Color.red).opacity(0.8))
                    }
                } else {
                    let unrealized = math?.unrealizedPnl ?? 0
                    let realized = math?.realizedPnl ?? 0
                    if unrealized != 0 || realized != 0 {
                        if unrealized != 0 {
                            Text(unrealized >= 0 ? "+\(unrealized, specifier: "%.2f")" : "\(unrealized, specifier: "%.2f")")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(unrealized >= 0 ? Color.green : Color.red)
                        }

                        if realized != 0 {
                            HStack(spacing: 3) {
                                Text("LOCK")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .tracking(0.5)
                                Text(realized >= 0 ? "+\(realized, specifier: "%.2f")" : "\(realized, specifier: "%.2f")")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle((realized >= 0 ? Color.green : Color.red).opacity(0.65))
                            }
                        }

                        if let vwap = math?.vwap, let sl = trade.stopLoss, vwap > 0 {
                            let dist = ((sl - vwap) / vwap) * 100 * (trade.side == .short ? -1 : 1)
                            Text("SL \(dist >= 0 ? "+" : "")\(dist, specifier: "%.1f")%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(dist < -5 ? Color.red : Color.secondary)
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
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: strokeColor.opacity(0.1), radius: 5, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(strokeColor.opacity(0.2), lineWidth: 1)
        )
    }
}
