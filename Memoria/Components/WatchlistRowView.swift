//
//  WatchlistRowView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/30/26.

import SwiftUI
import Charts

struct WatchlistRowView: View {
    let item: WatchlistItem
    let sparkline: [Double]
    let timeframe: String
    let deleteItem: () -> Void

    @AppStorage("watchlistMoverAlert", store: .app) private var watchlistMoverAlert: Bool = true
    @AppStorage("watchlistMoverThreshold", store: .app) private var watchlistMoverThreshold: Double = 5.0

    @State private var isHovered = false
    @State private var isRowHovered = false

    private var displayPercent: Double? {
        switch timeframe {
        case "1W": return item.weeklyChangePercent
        case "1M": return item.monthlyChangePercent
        case "ALL": return item.changeSinceAdded
        default: return item.priceChangePercent
        }
    }

    private var isUp: Bool { (displayPercent ?? 0) >= 0 }
    private var accentColor: Color { isUp ? .green : .red }
    private var isBigMover: Bool {
        guard watchlistMoverAlert, let pct = displayPercent else { return false }
        return abs(pct) >= watchlistMoverThreshold
    }

    private func compact(_ value: Double) -> String {
        switch value {
        case 1_000_000_000_000...: return String(format: "%.1fT", value / 1_000_000_000_000)
        case 1_000_000_000...:     return String(format: "%.1fB", value / 1_000_000_000)
        case 1_000_000...:         return String(format: "%.1fM", value / 1_000_000)
        case 1_000...:             return String(format: "%.1fK", value / 1_000)
        default:                   return String(format: "%.0f", value)
        }
    }

    var body: some View {
        HStack(spacing: 0) {

            // MARK: Ticker
            HStack(spacing: 10) {
                TickerLogoView(ticker: item.ticker, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ticker)
                        .font(.system(size: 14, weight: .bold))
                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        if let mc = item.marketCap {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("MCap")
                                Text(compact(mc))
                            }
                        }
                        if let vol = item.volume {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Vol")
                                Text(compact(Double(vol)))
                            }
                        }
                    }
                    .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.quaternary)
                }
            }
            #if os(iOS)
            .frame(minWidth: 70, maxWidth: 90, alignment: .leading)
            #else
            .frame(width: 120, alignment: .leading)
            #endif

            // MARK: Sparkline
            Group {
                if sparkline.count > 2 {
                    let minVal = sparkline.min() ?? 0
                    let maxVal = sparkline.max() ?? 1
                    Chart {
                        ForEach(Array(sparkline.enumerated()), id: \.offset) { i, val in
                            LineMark(
                                x: .value("t", i),
                                y: .value("p", val)
                            )
                            .foregroundStyle(accentColor.opacity(0.8))
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("t", i),
                                yStart: .value("min", minVal),
                                yEnd: .value("p", val)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.3), accentColor.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: minVal...maxVal)
                    .frame(height: 35)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 35)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 12)

            // MARK: Price + Performance
            VStack(alignment: .trailing, spacing: 4) {
                if let price = item.currentPrice {
                    Text(price, format: .currency(code: "USD"))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                } else {
                    Text("—")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let pct = displayPercent {
                    Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12), in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                Color(red: 0.92, green: 0.81, blue: 0.42).opacity(isBigMover ? 0.8 : 0),
                                lineWidth: 1
                            )
                        )
                }

            }
            #if os(iOS)
            .frame(width: 75, alignment: .trailing)
            #else
            .frame(width: 90, alignment: .trailing)
            #endif

            // MARK: Delete
            Button(action: deleteItem) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(isHovered ? 0.14 : 0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .padding(.leading, 10)
            #endif
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(isRowHovered ? 0.04 : 0))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.05), lineWidth: 0.5)
                .allowsHitTesting(false)
        )
        .onHover { isRowHovered = $0 }
    }
}
