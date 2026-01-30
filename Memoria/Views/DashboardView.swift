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
                HStack {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .bold()
                    
                    Spacer()
                    
                    // MARKET STATUS INDICATOR
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
                    
                    // WATCHLIST COUNT (Moved to Header)
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text("\(watchlistCount)")
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
                
                // Summary Cards (New Layout)
                HStack(spacing: 15) {
                    // Total Equity (Placeholder)
                    SummaryCard(title: "Total Equity", value: "$0.00", color: .blue)
                    
                    // Unrealized P/L (Placeholder)
                    SummaryCard(title: "Unrealized P/L", value: "$0.00", color: .green)
                }
                .padding(.horizontal)
                
                // Row 2: Performance Metrics (Restored)
                HStack(spacing: 15) {
                    SummaryCard(title: "Active Trades", value: "\(activeTradesCount)", color: .purple)
                    SummaryCard(title: "Win Rate", value: "N/A", color: .orange)
                }
                .padding(.horizontal)
                
                // Recent Activity or other sections could go here
                Text("Recent Activity")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                if trades.isEmpty {
                    ContentUnavailableView("No activity yet", systemImage: "chart.bar.xaxis")
                } else {
                    ForEach(trades.prefix(5)) { trade in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(trade.ticker)
                                    .font(.headline)
                                Text(trade.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(trade.dateAdded, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(
            LinearGradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Computed Properties
    
    private var activeTradesCount: Int {
        trades.filter { $0.status == .open }.count
    }
    
    private var watchlistCount: Int {
        watchlistItems.count
    }
    
    private var closedTradesCount: Int {
        trades.filter { $0.status == .closed }.count
    }
}



#Preview {
    DashboardView()
}
