//
//  DashboardView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/28/26.
//

import SwiftUI
import SwiftData
import Combine
import Charts

struct EquityDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double
}

enum BenchmarkTimeframe: String, CaseIterable {
    case ytd = "YTD"
    case allTime = "All Time"
}

struct DashboardView: View {
    @AppStorage("startingBalance") private var startingBalance: Double = 1600.0
    
    // Live Data Source
    @Query(sort: \Trade.dateAdded, order: .reverse) private var trades: [Trade]
    @Query private var watchlistItems: [WatchlistItem]
    @Query(filter: #Predicate<Trade> { $0.statusRaw == "Open" }) private var openTrades: [Trade]
    
    // Live State
    @State private var liveQuotes: [String: StockQuote] = [:]
    @State private var isSpyRefreshing = false
    
    // Benchmarking
    @State private var benchmarkTimeframe: BenchmarkTimeframe = .ytd
    @State private var spyBaseline: Double?
    @State private var spyCurrent: Double?
    
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                balanceHeroSection
                summaryCards
                equityCurveSection
                spyPerformanceSection
            }
            .padding(.vertical)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .task {
            await fetchLiveQuotes()
            await fetchSpyData()
        }
        .onReceive(refreshTimer) { _ in
            if MarketService.shared.currentStatus() == .open {
                Task {
                    await fetchLiveQuotes()
                    await fetchSpyData()
                }
            }
        }
        .onChange(of: benchmarkTimeframe) { _, _ in
            Task { await fetchSpyData() }
        }
    }
    
    // MARK: - Hero Section (Net Liq)
    
    private var balanceHeroSection: some View {
        VStack(spacing: 8) {
            Text("NET LIQUIDATING VALUE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(2)
            
            Text(currentBalance, format: .currency(code: "USD"))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .padding(.bottom, 4)
                
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
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Summary Cards (Metrics)
    
    private var summaryCards: some View {
        VStack(spacing: 15) {
            Text("Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Standard Cards (Retained Original)
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
            
            // New Advanced Metrics Cards using exactly the same aesthetic
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Profit Factor",
                    value: profitFactor > 0 ? String(format: "%.2f", profitFactor) : "0.00",
                    color: profitFactor >= 1.5 ? .green : .orange
                )
                
                SummaryCard(
                    title: "Avg Win / Loss",
                    value: "\(Int(avgWin)) / \(Int(abs(avgLoss)))",
                    color: avgWin > abs(avgLoss) ? .green : .red
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Equity Curve
    
    private var isEquityPositive: Bool {
        currentBalance >= startingBalance
    }
    
    private var yDomain: ClosedRange<Double> {
        let balances = equityCurveData.map { $0.balance }
        let minBalance = (balances.min() ?? startingBalance) * 0.98
        let maxBalance = (balances.max() ?? startingBalance) * 1.02
        guard maxBalance > minBalance else { return (minBalance - 10)...(maxBalance + 10) }
        return minBalance...maxBalance
    }
    
    private var equityCurveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Equity Curve")
                .font(.headline)
                .padding(.horizontal)
            
            VStack {
                if equityCurveData.count < 2 {
                    ContentUnavailableView("Not Enough Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Close at least one trade to automatically generate your equity curve."))
                        .frame(height: 200)
                } else {
                    Chart {
                        ForEach(equityCurveData) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(isEquityPositive ? Color.green : Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Time", point.date),
                                yStart: .value("Min Balance", yDomain.lowerBound),
                                yEnd: .value("Balance", point.balance)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        (isEquityPositive ? Color.green : Color.red).opacity(0.3),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .chartYScale(domain: yDomain)
                    .chartXAxis {
                        AxisMarks(preset: .aligned, position: .bottom)
                    }
                    .frame(height: 200)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - SPY Performance
    
    private var spyPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Relative Performance")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Portfolio Return
                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie.fill")
                        Text("\(portfolioReturn >= 0 ? "+" : "")\(portfolioReturn, specifier: "%.2f")%")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(portfolioReturn >= 0 ? Color.green : Color.red)
                    
                    // VS
                    Text("vs")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    // SPY Comparison
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                        if let sr = spyReturn {
                            Text("SPY \(sr >= 0 ? "+" : "")\(sr, specifier: "%.2f")%")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(sr >= 0 ? Color.green : Color.red)
                        } else {
                            // Empty placeholder until fetched
                            Text("SPY --")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Picker("Benchmark Timeframe", selection: $benchmarkTimeframe) {
                    ForEach(BenchmarkTimeframe.allCases, id: \.self) { frame in
                        Text(frame.rawValue).tag(frame)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchLiveQuotes() async {
        guard !openTrades.isEmpty else { return }
        let symbols = openTrades.map { $0.ticker }
        let newQuotes = await StockQuoteService.shared.fetchQuotes(for: symbols)
        liveQuotes.merge(newQuotes) { (_, new) in new }
    }
    
    private func fetchSpyData() async {
        if let current = await StockQuoteService.shared.fetchQuote(for: "SPY") {
            spyCurrent = current.currentPrice
        }
        
        let startDate: Date
        if benchmarkTimeframe == .ytd {
            startDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
        } else {
            if let oldest = trades.last?.dateAdded {
                startDate = oldest
            } else {
                startDate = Date()
            }
        }
        
        if let baseline = await StockQuoteService.shared.fetchBaselinePrice(symbol: "SPY", startDate: startDate) {
            spyBaseline = baseline
        }
    }
    
    // MARK: - Computed Properties (Live Stats)
    
    private var equityCurveData: [EquityDataPoint] {
        var points: [EquityDataPoint] = []
        var runningBalance = startingBalance
        
        // 1. Initial point
        if let firstTrade = trades.last {
            points.append(EquityDataPoint(date: firstTrade.dateAdded, balance: runningBalance))
        } else {
            points.append(EquityDataPoint(date: Date(), balance: runningBalance))
        }
        
        // 2. Sort closed trades sequentially from oldest to newest
        let closedTradesReversed = trades.filter { $0.status == .closed && $0.pnl != nil }.sorted {
            ($0.dateClosed ?? $0.dateAdded) < ($1.dateClosed ?? $1.dateAdded)
        }
        
        for trade in closedTradesReversed {
            if let pnl = trade.pnl {
                runningBalance += pnl
                let date = trade.dateClosed ?? trade.dateAdded
                points.append(EquityDataPoint(date: date, balance: runningBalance))
            }
        }
        
        // 3. Current Live Point (includes floating P&L)
        points.append(EquityDataPoint(date: Date(), balance: currentBalance))
        
        return points
    }
    
    private var totalFloatingPnl: Double {
        var sum: Double = 0
        for trade in openTrades {
            if let entry = trade.entryPrice, let qty = trade.quantity, let quote = liveQuotes[trade.ticker.uppercased()] {
                let pnl = (quote.currentPrice - entry) * qty * (trade.side == .long ? 1.0 : -1.0)
                sum += pnl
            }
        }
        return sum
    }
    
    private var currentBalance: Double {
        startingBalance + totalPnl + totalFloatingPnl
    }
    
    private var portfolioReturn: Double {
        guard startingBalance > 0 else { return 0 }
        return ((currentBalance - startingBalance) / startingBalance) * 100
    }
    
    private var spyReturn: Double? {
        guard let current = spyCurrent, let baseline = spyBaseline, baseline > 0 else { return nil }
        return ((current - baseline) / baseline) * 100
    }
    
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
    
    private var profitFactor: Double {
        let closed = trades.filter { $0.status == .closed && $0.pnl != nil }
        let grossWin = closed.compactMap { $0.pnl }.filter { $0 > 0 }.reduce(0, +)
        let grossLoss = abs(closed.compactMap { $0.pnl }.filter { $0 < 0 }.reduce(0, +))
        guard grossLoss > 0 else { return grossWin > 0 ? .infinity : 0 }
        return grossWin / grossLoss
    }
    
    private var avgWin: Double {
        let closed = trades.filter { $0.status == .closed && $0.pnl != nil }
        let wins = closed.compactMap { $0.pnl }.filter { $0 > 0 }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0, +) / Double(wins.count)
    }
    
    private var avgLoss: Double {
        let closed = trades.filter { $0.status == .closed && $0.pnl != nil }
        let losses = closed.compactMap { $0.pnl }.filter { $0 < 0 }
        guard !losses.isEmpty else { return 0 }
        return losses.reduce(0, +) / Double(losses.count)
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
