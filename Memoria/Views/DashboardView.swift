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
    @AppStorage("traderName") private var traderName: String = ""
    
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
    @State private var spyHistoricalData: [HistoricalQuote] = []
    
    @State private var marketStatus: MarketStatus = MarketService.shared.currentStatus()
    
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Personalized Greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back\(traderName.isEmpty ? "" : ", \(traderName)")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text(Date(), format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                balanceHeroSection
                activePortfolioSection
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
            let newStatus = MarketService.shared.currentStatus()
            if marketStatus != newStatus {
                marketStatus = newStatus
            }
            
            if marketStatus == .open || marketStatus == .preMarket || marketStatus == .postMarket {
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
            HStack(spacing: 6) {
                Circle()
                    .fill(marketStatus == .open ? Color.green : (marketStatus == .preMarket || marketStatus == .postMarket ? Color.yellow : (marketStatus == .weekend ? Color.orange : Color.gray)))
                    .frame(width: 8, height: 8)
                    .shadow(color: (marketStatus == .open ? Color.green : (marketStatus == .preMarket || marketStatus == .postMarket ? Color.yellow : Color.clear)).opacity(0.5), radius: 5)
                
                Text(marketStatus.title)
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
    
    // MARK: - Active Portfolio Hub
    
    private var activePortfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Portfolio")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 15) {
                // Floating P&L
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNREALIZED P&L")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(totalFloatingPnl >= 0 ? "+" : "")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(totalFloatingPnl >= 0 ? .green : .red)
                        Text(totalFloatingPnl, format: .currency(code: "USD"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(totalFloatingPnl >= 0 ? .green : .red)
                    }
                    
                    Text("\(totalFloatingReturn >= 0 ? "+" : "")\(totalFloatingReturn, specifier: "%.2f")%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                // Open Exposure
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPEN EXPOSURE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Text(totalExposure, format: .currency(code: "USD"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    
                    Text("\(openTradesCount) Active Positions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal)
        }
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
            
            // Third Row of Advanced Metrics
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Avg Hold Time",
                    value: avgHoldTimeFormatted,
                    color: .cyan
                )
                
                SummaryCard(
                    title: "Max Drawdown",
                    value: String(format: "%.1f%%", maxDrawdownPercent),
                    color: maxDrawdownPercent < 5.0 ? .green : .red
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Equity Curve
    
    private var isEquityPositive: Bool {
        totalPnl >= 0
    }
    
    private var yDomain: ClosedRange<Double> {
        let profits = equityCurveData.map { $0.balance }
        let minP = (profits.min() ?? 0) - 100
        let maxP = (profits.max() ?? 0) + 100
        guard maxP > minP else { return -100...100 }
        return minP...maxP
    }
    
    private var equityCurveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cumulative Profit ($)")
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
                                y: .value("Profit", point.balance)
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
                        Text("\(totalPnl >= 0 ? "+" : "")\(totalPnl, format: .currency(code: "USD"))")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(totalPnl >= 0 ? Color.green : Color.red)
                    
                    // VS
                    Text("vs")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    // SPY Comparison
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                        if let sr = spyReturn {
                            let spyProfit = (sr / 100.0) * startingBalance
                            Text("SPY \(spyProfit >= 0 ? "+" : "")\(spyProfit, format: .currency(code: "USD"))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(spyProfit >= 0 ? Color.green : Color.red)
                        } else {
                            Text("SPY --")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Picker("", selection: $benchmarkTimeframe) {
                    ForEach(BenchmarkTimeframe.allCases, id: \.self) { frame in
                        Text(frame.rawValue).tag(frame)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                
                if portfolioRelativeCurve.count >= 2 {
                    Chart {
                        ForEach(portfolioRelativeCurve) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Profit", point.balance),
                                series: .value("Type", "Portfolio")
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(isTimeframePortfolioPositive ? Color.green : Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                        
                        if let firstSpy = spyHistoricalData.first?.close, firstSpy > 0 {
                            ForEach(spyHistoricalData) { point in
                                let spyProfit = ((point.close - firstSpy) / firstSpy) * startingBalance
                                LineMark(
                                    x: .value("Time", point.date),
                                    y: .value("Profit", spyProfit),
                                    series: .value("Type", "SPY")
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Color.purple)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            }
                        }
                    }
                    .chartYScale(domain: relativeYDomain)
                    .chartXAxis { AxisMarks(preset: .aligned, position: .bottom) }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text("\(d >= 0 ? "+" : "")\(Int(d))")
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .frame(height: 180)
                    .padding(.top, 8)
                    
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle().fill(isTimeframePortfolioPositive ? Color.green : Color.red).frame(width: 8, height: 8)
                            Text("Portfolio").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Rectangle().fill(Color.purple).frame(width: 12, height: 2)
                            Text("S&P 500").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
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
        
        if let series = await StockQuoteService.shared.fetchHistoricalSeries(symbol: "SPY", startDate: startDate) {
            spyHistoricalData = series
        }
    }
    
    // MARK: - Computed Properties (Live Stats)
    
    private var equityCurveData: [EquityDataPoint] {
        var points: [EquityDataPoint] = []
        var runningPnl = 0.0
        
        // 1. Starting point is always 0 (True Skill Baseline)
        if let firstTrade = trades.last {
            points.append(EquityDataPoint(date: firstTrade.dateAdded, balance: 0))
        } else {
            points.append(EquityDataPoint(date: Date(), balance: 0))
        }
        
        // 2. Plot closed trades as profit increments
        let closedTradesReversed = trades.filter { $0.status == .closed && $0.pnl != nil }.sorted {
            ($0.dateClosed ?? $0.dateAdded) < ($1.dateClosed ?? $1.dateAdded)
        }
        
        for trade in closedTradesReversed {
            if let pnl = trade.pnl {
                runningPnl += pnl
                let date = trade.dateClosed ?? trade.dateAdded
                points.append(EquityDataPoint(date: date, balance: runningPnl))
            }
        }
        
        // 3. Include current floating P&L
        points.append(EquityDataPoint(date: Date(), balance: runningPnl + totalFloatingPnl))
        
        return points
    }
    
    // MARK: - Relative Performance Graph Logic
    
    private var isTimeframePortfolioPositive: Bool {
        totalPnl >= 0
    }
    
    private func getBalance(on date: Date) -> Double {
        var runningBalance = startingBalance
        let closedBeforeDate = trades.filter { $0.status == .closed && $0.pnl != nil }.filter { 
            ($0.dateClosed ?? $0.dateAdded) < date 
        }
        for trade in closedBeforeDate {
            runningBalance += trade.pnl ?? 0
        }
        return runningBalance
    }
    
    private var portfolioRelativeCurve: [EquityDataPoint] {
        let startDate: Date
        if benchmarkTimeframe == .ytd {
            startDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
        } else {
            startDate = trades.last?.dateAdded ?? Date()
        }
        
        var points: [EquityDataPoint] = [EquityDataPoint(date: startDate, balance: 0)]
        let timeframeTrades = trades.filter { $0.status == .closed && $0.pnl != nil }.sorted {
            ($0.dateClosed ?? $0.dateAdded) < ($1.dateClosed ?? $1.dateAdded)
        }.filter { ($0.dateClosed ?? $0.dateAdded) >= startDate }
        
        var accumProfit = 0.0
        for trade in timeframeTrades {
            accumProfit += trade.pnl ?? 0
            let date = trade.dateClosed ?? trade.dateAdded
            points.append(EquityDataPoint(date: date, balance: accumProfit))
        }
        
        points.append(EquityDataPoint(date: Date(), balance: accumProfit + totalFloatingPnl))
        return points
    }
    
    private var relativeYDomain: ClosedRange<Double> {
        let curve = portfolioRelativeCurve.map { $0.balance }
        let firstSpy = spyHistoricalData.first?.close ?? 1.0
        let spyProfits = spyHistoricalData.map { (($0.close - firstSpy) / firstSpy) * startingBalance }
        
        let allValues = curve + spyProfits
        guard !allValues.isEmpty else { return -100...100 }
        let minV = (allValues.min() ?? 0) - 100
        let maxV = (allValues.max() ?? 0) + 100
        return minV...maxV
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
    
    private var totalFloatingReturn: Double {
        guard totalExposure > 0 else { return 0 }
        return (totalFloatingPnl / totalExposure) * 100
    }
    
    private var totalExposure: Double {
        openTrades.reduce(0) { sum, trade in
            sum + (trade.positionSize ?? 0)
        }
    }
    
    private var currentBalance: Double {
        startingBalance + totalPnl + totalFloatingPnl
    }
    
    private var portfolioReturn: Double {
        // We use the sum of every trade's % return to show "Performance Skill"
        // This prevents massive deposits from diluting your historical success.
        let tradeReturns = trades.compactMap { $0.percentReturn }
        guard !tradeReturns.isEmpty else { return 0 }
        return tradeReturns.reduce(0, +)
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
    
    private var avgHoldTimeFormatted: String {
        let closed = trades.filter { $0.status == .closed && $0.dateClosed != nil }
        guard !closed.isEmpty else { return "0d 0h" }
        
        let totalTimeInterval = closed.reduce(0.0) { result, trade in
            result + (trade.dateClosed!.timeIntervalSince(trade.dateAdded))
        }
        
        let avgSeconds = totalTimeInterval / Double(closed.count)
        return formatTimeInterval(avgSeconds)
    }
    
    private func formatTimeInterval(_ seconds: Double) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var maxDrawdownPercent: Double {
        let curve = equityCurveData
        guard !curve.isEmpty else { return 0 }
        var peak = curve.first!.balance
        var maxDD = 0.0
        
        for point in curve {
            if point.balance > peak {
                peak = point.balance
            }
            let dd = (peak - point.balance) / peak * 100
            if dd > maxDD {
                maxDD = dd
            }
        }
        return maxDD
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
