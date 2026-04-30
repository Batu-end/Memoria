//
//  TradeRowView.swift
//  Memoria

import SwiftUI

struct TradeRowView: View {
    var engine = AccountingEngine.shared
    let trade: Trade

    var math: TradeAccounting? {
        engine.tradeAccounting[trade.id]
    }

    private var accentColor: Color {
        if trade.status == .closed {
            if let pnl = math?.totalPnl { return pnl >= 0 ? .green : .red }
            return .purple
        }
        return .blue
    }

    var body: some View {
        HStack(spacing: 12) {

            // Left: Ticker + sub-info
            VStack(alignment: .leading, spacing: 3) {
                Text(trade.ticker)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    if let entry = math?.vwap {
                        Text(entry, format: .currency(code: "USD"))
                            .stealthable()
                    }
                    let qty = math?.effectiveQuantity ?? 0
                    if qty > 0 {
                        Text(qty.truncatingRemainder(dividingBy: 1) == 0
                             ? String(format: "%.0f sh", qty)
                             : String(format: "%.2f sh", qty))
                            .stealthable()
                    }
                    Text(trade.dateAdded, format: .dateTime.month(.abbreviated).day())
                    if trade.assetType == .etf {
                        Text("ETF").foregroundStyle(.blue)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Middle: Side pill
            Text(trade.side == .long ? "LONG" : "SHORT")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(trade.side == .long ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((trade.side == .long ? Color.green : Color.red).opacity(0.12))
                .clipShape(Capsule())

            // Right: P&L
            VStack(alignment: .trailing, spacing: 2) {
                pnlView
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .clipShape(.rect(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                ))
        }
    }

    @ViewBuilder
    private var pnlView: some View {
        if trade.status == .closed, let pnl = math?.totalPnl {
            Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
                .stealthable()
            if let pct = math?.percentReturn {
                Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.1f")%")
                    .font(.caption)
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
                        .stealthable()
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
                            .stealthable()
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
