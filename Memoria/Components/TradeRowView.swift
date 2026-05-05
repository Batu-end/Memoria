//
//  TradeRowView.swift
//  Memoria

import SwiftUI

struct TradeRowView: View {
    var engine = AccountingEngine.shared
    let trade: Trade

    @AppStorage("showTickerLogos", store: .app) private var showTickerLogos: Bool = true
    @State private var dotOpacity: Double = 0.2
    @State private var shimmerX: CGFloat = -1000
    @State private var rowWidth: CGFloat = 0
    @State private var isHovered: Bool = false

    var math: TradeAccounting? {
        engine.tradeAccounting[trade.id]
    }

    private var accentColor: Color {
        if trade.status == .closed {
            if let pnl = math?.totalPnl { return pnl >= 0 ? .green : .red }
            return .purple
        }
        let unrealized = math?.unrealizedPnl ?? 0
        if unrealized > 0 { return .green }
        if unrealized < 0 { return .red }
        return Color.white.opacity(0.25)
    }

    private var dotColor: Color {
        let unrealized = math?.unrealizedPnl ?? 0
        if unrealized > 0 { return .green }
        if unrealized < 0 { return .red }
        return Color.white.opacity(0.35)
    }

    var body: some View {
        HStack(spacing: 10) {

            if showTickerLogos {
                TickerLogoView(ticker: trade.ticker, size: 32)
            }

            // Left: Ticker + entry
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(trade.ticker)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    if trade.status == .open {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 5, height: 5)
                            .opacity(dotOpacity)
                    }
                }

                if let entry = math?.vwap {
                    Text(entry, format: .currency(code: "USD"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .stealthable()
                }
            }

            Spacer(minLength: 4)

            // Middle: Shares + date
            let qty = math?.effectiveQuantity ?? 0
            VStack(alignment: .leading, spacing: 1) {
                if qty > 0 {
                    Text(qty.truncatingRemainder(dividingBy: 1) == 0
                         ? String(format: "%.0f Sh", qty)
                         : String(format: "%.2f Sh", qty))
                        .stealthable()
                }
                Text(trade.dateAdded, format: .dateTime.month(.abbreviated).day())
                if trade.assetType == .etf {
                    Text("ETF").foregroundStyle(.blue)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            // Side pill
            Text(trade.side == .long ? "LONG" : "SHORT")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(trade.side == .long ? .green : .red)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((trade.side == .long ? Color.green : Color.red).opacity(0.12))
                .clipShape(Capsule())

            // Right: P&L
            VStack(alignment: .trailing, spacing: 2) {
                pnlView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(isHovered ? 0.04 : 0))
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
        }
        .overlay {
            if trade.status == .open {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.12), location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: rowWidth + 200)
                    .rotationEffect(.degrees(15))
                    .offset(x: shimmerX)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(GeometryReader { geo in
            Color.clear.onAppear { rowWidth = geo.size.width }
        })
        .onAppear {
            guard trade.status == .open else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                dotOpacity = 1.0
            }
        }
        .onChange(of: rowWidth) { _, width in
            guard trade.status == .open, width > 0 else { return }
            shimmerX = -(width + 200)
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                shimmerX = width + 200
            }
        }
    }

    @ViewBuilder
    private var pnlView: some View {
        if trade.status == .closed, let pnl = math?.totalPnl {
            Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(unrealized >= 0 ? Color.green : Color.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .stealthable()
                    }
                }
            } else {
                Text("OPEN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
    }
}
