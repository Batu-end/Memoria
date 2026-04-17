//
//  DashboardView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/28/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    // Live Data Source
    @Query(sort: \Trade.dateAdded, order: .reverse) private var trades: [Trade]
    @Query private var watchlistItems: [WatchlistItem]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                summaryCards
                recentActivitySection
            }
            .padding(.vertical)
        }
        .background(
            LinearGradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Text("Dashboard")
                .font(.largeTitle)
                .bold()
            
            Spacer()
            
            // Market Status Indicator
            let status = MarketService.shared.currentStatus()
            HStack(spacing: 6) {
                Circle()
                    .fill(status == .open ? Color.green : (status == .weekend ? Color.orange : Color.gray))
                    .frame(width: 8, height: 8)
                    .shadow(color: (status == .open ? Color.green : Color.clear).opacity(0.5), radius: 5)
                
                Text(status.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Watchlist Count
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                Text("\(watchlistItems.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Summary Cards (Live Data)
    
    private var summaryCards: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Total P&L",
                    value: formatPnl(totalPnl),
                    color: totalPnl >= 0 ? .green : .red
                )
                SummaryCard(
                    title: "Win Rate",
                    value: closedTradesCount > 0 ? String(format: "%.0f%%", winRate) : "N/A",
                    color: winRate >= 50 ? .green : .orange
                )
            }
            
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Open Trades",
                    value: "\(openTradesCount)",
                    color: .blue
                )
                SummaryCard(
                    title: "Closed Trades",
                    value: "\(closedTradesCount)",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            if trades.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "chart.bar.xaxis")
            } else {
                ForEach(trades.prefix(5)) { trade in
                    recentActivityRow(trade)
                }
            }
        }
    }
    
    private func recentActivityRow(_ trade: Trade) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.headline)
                    
                    Text(trade.status.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trade.status == .open ? Color.blue : Color.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((trade.status == .open ? Color.blue : Color.gray).opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(trade.dateAdded, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Show P&L for closed trades
            if trade.status == .closed, let pnl = trade.pnl {
                Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
            } else if let entry = trade.entryPrice {
                Text(entry, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties (Live Stats)
    
    private var openTradesCount: Int {
        trades.filter { $0.status == .open }.count
    }
    
    private var closedTradesCount: Int {
        trades.filter { $0.status == .closed }.count
    }
    
    private var totalPnl: Double {
        trades.filter { $0.status == .closed }.compactMap { $0.pnl }.reduce(0, +)
    }
    
    private var winRate: Double {
        let closed = trades.filter { $0.status == .closed && $0.pnl != nil }
        guard !closed.isEmpty else { return 0 }
        let wins = closed.filter { $0.isWin }.count
        return Double(wins) / Double(closed.count) * 100
    }
    
    private func formatPnl(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))"
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
