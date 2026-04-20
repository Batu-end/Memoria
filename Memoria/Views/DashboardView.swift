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
    @Environment(\.modelContext) private var modelContext
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
    @State private var isDashboardReady = false
    
    // The Math engine
    @State private var accountingEngine = AccountingEngine.shared
    @State private var updateTask: Task<Void, Never>?
    
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
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
            await initializeDashboard()
        }
        .onReceive(refreshTimer) { _ in
            handleRefresh()
        }
        .onChange(of: trades) { _, newValue in
            // Bulletproof debounce: Cancel previous update and wait for settle
            updateTask?.cancel()
            updateTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                guard !Task.isCancelled else { return }
                accountingEngine.update(trades: newValue, startingBalance: startingBalance)
            }
        }
        .onChange(of: liveQuotes) { _, newValue in
            accountingEngine.update(quotes: newValue)
        }
        .onChange(of: startingBalance) { _, newValue in
            accountingEngine.update(trades: trades, startingBalance: newValue)
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
            
            Text(accountingEngine.portfolioState.netLiquidity, format: .currency(code: "USD"))
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
        .opacity(isDashboardReady ? 1 : 0)
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
                        Text(accountingEngine.portfolioState.unrealizedPnl >= 0 ? "+" : "")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accountingEngine.portfolioState.unrealizedPnl >= 0 ? .green : .red)
                        Text(accountingEngine.portfolioState.unrealizedPnl, format: .currency(code: "USD"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(accountingEngine.portfolioState.unrealizedPnl >= 0 ? .green : .red)
                    }
                    
                    Text("\(accountingEngine.portfolioState.unrealizedReturn >= 0 ? "+" : "")\(accountingEngine.portfolioState.unrealizedReturn, specifier: "%.2f")%")
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
                    
                    Text(accountingEngine.portfolioState.totalExposure, format: .currency(code: "USD"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    
                    Text("\(accountingEngine.portfolioState.openTradesCount) Active Positions")
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
                    value: formatPnl(accountingEngine.portfolioState.totalPnl),
                    color: accountingEngine.portfolioState.totalPnl >= 0 ? .green : .red
                )
                SummaryCard(
                    title: "Win Rate",
                    value: accountingEngine.portfolioState.closedTradesCount > 0 ? String(format: "%.0f%%", accountingEngine.portfolioState.winRate) : "N/A",
                    color: accountingEngine.portfolioState.winRate >= 50 ? .green : .orange
                )
            }
            
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Open Trades",
                    value: "\(accountingEngine.portfolioState.openTradesCount)",
                    color: .blue
                )
                SummaryCard(
                    title: "Closed Trades",
                    value: "\(accountingEngine.portfolioState.closedTradesCount)",
                    color: .purple
                )
            }
            
            // New Advanced Metrics Cards using exactly the same aesthetic
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Profit Factor",
                    value: accountingEngine.portfolioState.profitFactor > 0 ? String(format: "%.2f", accountingEngine.portfolioState.profitFactor) : "0.00",
                    color: accountingEngine.portfolioState.profitFactor >= 1.5 ? .green : .orange
                )
                
                SummaryCard(
                    title: "Avg Win / Loss",
                    value: "\(Int(accountingEngine.portfolioState.avgWin)) / \(Int(abs(accountingEngine.portfolioState.avgLoss)))",
                    color: accountingEngine.portfolioState.avgWin > abs(accountingEngine.portfolioState.avgLoss) ? .green : .red
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
                    value: String(format: "%.1f%%", accountingEngine.portfolioState.maxDrawdown),
                    color: accountingEngine.portfolioState.maxDrawdown < 5.0 ? .green : .red
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Equity Curve
    
    private var isEquityPositive: Bool {
        accountingEngine.portfolioState.totalPnl >= 0
    }
    
    private var yDomain: ClosedRange<Double> {
        let profits = accountingEngine.portfolioState.equityCurve.map { $0.balance }
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
                if accountingEngine.portfolioState.equityCurve.count < 2 {
                    ContentUnavailableView("Not Enough Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Close at least one trade to automatically generate your equity curve."))
                        .frame(height: 200)
                } else {
                    Chart {
                        ForEach(accountingEngine.portfolioState.equityCurve) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Profit", point.balance)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(accountingEngine.portfolioState.totalPnl >= 0 ? Color.green : Color.red)
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
                                        (accountingEngine.portfolioState.totalPnl >= 0 ? Color.green : Color.red).opacity(0.3),
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
                        Text("\(accountingEngine.portfolioState.totalPnl >= 0 ? "+" : "")\(accountingEngine.portfolioState.totalPnl, format: .currency(code: "USD"))")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accountingEngine.portfolioState.totalPnl >= 0 ? Color.green : Color.red)
                    
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
                
                let relativeData = accountingEngine.calculateRelativeCurve(from: benchmarkStartDate)
                if relativeData.count >= 2 {
                    Chart {
                        ForEach(relativeData) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Profit", point.balance),
                                series: .value("Type", "Portfolio")
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(accountingEngine.portfolioState.totalPnl >= 0 ? Color.green : Color.red)
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
                            Circle().fill(accountingEngine.portfolioState.totalPnl >= 0 ? Color.green : Color.red).frame(width: 8, height: 8)
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
    
    // MARK: - Sub-views (Refactored to improve compiler performance)
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(personalizedGreeting)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(Date(), format: .dateTime.month().day().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16) // Increased top padding for the refactored layout
    }
    
    // MARK: - Lifecycle Logic
    
    private func initializeDashboard() async {
        // Reduced logic: Just sync the engine once on startup
        accountingEngine.update(trades: trades, startingBalance: startingBalance)
        
        await fetchLiveQuotes()
        await fetchSpyData()
        
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.2)) {
                isDashboardReady = true
            }
        }
    }
    
    private func handleRefresh() {
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
    
    // MARK: - Legacy Math Cleanup (Now Handled by AccountingEngine)
    // All computed properties from line 495-700 have been replaced by accountingEngine.portfolioState
    
    private var personalizedGreeting: String {
        traderName.isEmpty ? "Welcome back" : "Welcome back, \(traderName)"
    }
    
    private func fetchLiveQuotes() async {
        let tickers = Array(Set(trades.filter { $0.status == .open }.map { $0.ticker } + watchlistItems.map { $0.ticker }))
        guard !tickers.isEmpty else { return }
        
        let quotes = await StockQuoteService.shared.fetchQuotes(for: tickers)
        await MainActor.run {
            withAnimation {
                self.liveQuotes = quotes
            }
        }
    }
    
    private func fetchSpyData() async {
        isSpyRefreshing = true
        let start = benchmarkStartDate
        
        async let baseline = StockQuoteService.shared.fetchBaselinePrice(symbol: "SPY", startDate: start)
        async let current = StockQuoteService.shared.fetchQuote(for: "SPY")
        async let history = StockQuoteService.shared.fetchHistoricalSeries(symbol: "SPY", startDate: start)
        
        let (resolvedBaseline, resolvedCurrent, resolvedHistory) = await (baseline, current, history)
        
        await MainActor.run {
            withAnimation {
                self.spyBaseline = resolvedBaseline
                self.spyCurrent = resolvedCurrent?.currentPrice
                self.spyHistoricalData = resolvedHistory ?? []
                self.isSpyRefreshing = false
            }
        }
    }
    
    private var benchmarkStartDate: Date {
        if benchmarkTimeframe == .ytd {
            return Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
        } else {
            return trades.last?.dateAdded ?? Date()
        }
    }

    private var spyReturn: Double? {
        guard let current = spyCurrent, let baseline = spyBaseline, baseline > 0 else { return nil }
        return ((current - baseline) / baseline) * 100
    }
    
    private func formatPnl(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
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
    
    private var avgHoldTimeFormatted: String {
        let closed = trades.filter { $0.status == .closed && $0.dateClosed != nil }
        guard !closed.isEmpty else { return "0d 0h" }
        
        let totalTimeInterval = closed.reduce(0.0) { result, trade in
            result + (trade.dateClosed!.timeIntervalSince(trade.dateAdded))
        }
        
        let avgSeconds = totalTimeInterval / Double(closed.count)
        return formatTimeInterval(avgSeconds)
    }

    private var relativeYDomain: ClosedRange<Double> {
        let curve = accountingEngine.calculateRelativeCurve(from: benchmarkStartDate).map { $0.balance }
        let firstSpy = spyHistoricalData.first?.close ?? 1.0
        let spyProfits = spyHistoricalData.map { (($0.close - firstSpy) / firstSpy) * startingBalance }
        
        let allValues = curve + spyProfits
        guard !allValues.isEmpty else { return -100...100 }
        let minV = (allValues.min() ?? 0) - 100
        let maxV = (allValues.max() ?? 0) + 100
        return minV...maxV
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
