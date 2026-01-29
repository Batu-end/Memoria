//
//  DashboardView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/28/26.
//

import SwiftUI

// Mock Models
// Mock Models
struct MockTrade: Identifiable {
    let id = UUID()
    let ticker: String
    let entryPrice: Double
    let status: TradeStatus
    let dateAdded: Date
}



struct DashboardView: View {
    // Mock Data Source
    private let trades: [MockTrade] = [
        MockTrade(ticker: "AAPL", entryPrice: 150.0, status: .watchlist, dateAdded: Date()),
        MockTrade(ticker: "TSLA", entryPrice: 200.0, status: .open, dateAdded: Date().addingTimeInterval(-86400)),
        MockTrade(ticker: "NVDA", entryPrice: 400.0, status: .closed, dateAdded: Date().addingTimeInterval(-172800))
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                
                // Summary Cards
                HStack(spacing: 15) {
                    SummaryCard(title: "Active Trades", value: "\(activeTradesCount)", color: .blue)
                    SummaryCard(title: "Watchlist", value: "\(watchlistCount)", color: .purple)
                }
                .padding(.horizontal)
                
                HStack(spacing: 15) {
                    SummaryCard(title: "Closed", value: "\(closedTradesCount)", color: .gray)
                    // Just a placeholder for Win Rate for now
                    SummaryCard(title: "Win Rate", value: "N/A", color: .green)
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
                    ForEach(trades.sorted(by: { $0.dateAdded > $1.dateAdded }).prefix(5)) { trade in
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
        trades.filter { $0.status == .watchlist }.count
    }
    
    private var closedTradesCount: Int {
        trades.filter { $0.status == .closed }.count
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
                .bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    DashboardView()
}
