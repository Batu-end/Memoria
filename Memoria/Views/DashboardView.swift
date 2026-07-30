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

private let goldGradient = LinearGradient(
    colors: [Color(red: 0.92, green: 0.81, blue: 0.42), Color(red: 0.71, green: 0.55, blue: 0.18)],
    startPoint: .top,
    endPoint: .bottom
)

extension View {
    func darkNavigationBar() -> some View {
        #if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.06), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        self
        #endif
    }

    func goldTitle(_ text: String) -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItem(placement: .principal) {
                Text(text)
                    .font(.headline)
                    .foregroundStyle(goldGradient)
            }
        }
        #else
        self.navigationTitle(text)
        #endif
    }
}


enum BenchmarkTimeframe: String, CaseIterable {
    case ytd = "YTD"
    case allTime = "All Time"
}

struct DashboardView: View {
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @AppStorage("traderName", store: .app) private var traderName: String = ""
    @AppStorage("traderPersonality", store: .app) private var personalityRaw: String = TraderPersonality.human.rawValue
    private var personality: TraderPersonality { TraderPersonality(rawValue: personalityRaw) ?? .human }
    @AppStorage("unreadableDate", store: .app) private var unreadableDate: Bool = false
    @AppStorage("stealthMode", store: .app) private var stealthMode = false

    // Live Data Source — scoped to active portfolio
    @Query private var trades: [Trade]
    @Query private var watchlistItems: [WatchlistItem]
    @Query private var openTrades: [Trade]
    @Query private var capitalEvents: [CapitalEvent]

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _trades = Query(filter: #Predicate<Trade> { $0.portfolio?.id == id }, sort: \Trade.dateAdded, order: .reverse)
        _watchlistItems = Query(filter: #Predicate<WatchlistItem> { $0.portfolio?.id == id })
        _openTrades = Query(filter: #Predicate<Trade> { $0.portfolio?.id == id && $0.statusRaw == "Open" })
        _capitalEvents = Query(filter: #Predicate<CapitalEvent> { $0.portfolio?.id == id })
    }
    
    // Live State
    @State private var liveQuotes: [String: StockQuote] = [:]
    @State private var isSpyRefreshing = false
    
    // Benchmarking
    @State private var benchmarkTimeframe: BenchmarkTimeframe = .ytd
    @State private var spyBaseline: Double?
    @State private var spyCurrent: Double?
    @State private var spyHistoricalData: [HistoricalQuote] = []
    
    @State private var marketStatus: MarketStatus = MarketService.shared.currentStatus()
    @State private var quotesAreStale = false
    @State private var isDashboardReady = false
    @State private var showPortfolioSwitcher = false
    
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
            LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.11), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .task(id: portfolio.id) {
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
                accountingEngine.update(trades: newValue, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
            }
        }
        .onChange(of: liveQuotes) { _, newValue in
            accountingEngine.update(quotes: newValue)
        }
        .onChange(of: portfolio.startingBalance) { _, newValue in
            accountingEngine.update(trades: trades, startingBalance: newValue, capitalEvents: capitalEvents)
        }
        .onChange(of: capitalEvents) { _, newValue in
            accountingEngine.update(trades: trades, startingBalance: portfolio.startingBalance, capitalEvents: newValue)
        }
        .onChange(of: benchmarkTimeframe) { _, _ in
            Task { await fetchSpyData() }
        }
        .sheet(isPresented: $showPortfolioSwitcher) {
            PortfolioSwitcherView()
        }
    }
    
    // MARK: - Hero Section (Net Liq)
    
    private var balanceHeroSection: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("NET LIQUIDATING VALUE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(2)

            ZStack {
                Text(accountingEngine.portfolioState.netLiquidity, format: .currency(code: "USD"))
                    .opacity(stealthMode ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: stealthMode)

                Text("Stealth.")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.81, blue: 0.42), // Light Gold
                                Color(red: 0.71, green: 0.55, blue: 0.18)  // Dark Gold
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.25).opacity(0.3), radius: 6, x: 0, y: 2)
                    .opacity(stealthMode ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: stealthMode)
            }
            .font(.custom("Bodoni 72", size: 64))

            // TWR — always visible (intentionally not stealthed)
            let twr = accountingEngine.portfolioState.twr
            if twr != 0 {
                Text(twr >= 0 ? String(format: "+%.2f%%", twr * 100) : String(format: "%.2f%%", twr * 100))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(twr >= 0 ? Color.green : Color.red)
            }

            // Market Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(quotesAreStale ? Color.red : (marketStatus == .open ? Color.green : (marketStatus == .preMarket || marketStatus == .postMarket ? Color.yellow : (marketStatus == .weekend ? Color.orange : Color.gray))))
                    .frame(width: 8, height: 8)
                    .shadow(color: quotesAreStale ? Color.red.opacity(0.5) : (marketStatus == .open ? Color.green : (marketStatus == .preMarket || marketStatus == .postMarket ? Color.yellow : Color.clear)).opacity(0.5), radius: 5)

                Text(quotesAreStale ? "Prices Unavailable" : marketStatus.title)
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
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .opacity(isDashboardReady ? 1 : 0)
    }
    
    // MARK: - Active Portfolio Hub

    private var activePortfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Portfolio")
                .font(.headline)
                .padding(.horizontal)

            // Summary cards
            HStack(spacing: 15) {
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
                    .stealthable()

                    Text("\(accountingEngine.portfolioState.unrealizedReturn >= 0 ? "+" : "")\(accountingEngine.portfolioState.unrealizedReturn, specifier: "%.2f")%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text("OPEN EXPOSURE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(accountingEngine.portfolioState.totalExposure, format: .currency(code: "USD"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                        .stealthable()

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

            // Mini position list
            if !openTrades.isEmpty {
                VStack(spacing: 8) {
                    ForEach(openTrades) { trade in
                        miniPositionRow(trade)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func miniPositionRow(_ trade: Trade) -> some View {
        let math = accountingEngine.tradeAccounting[trade.id]
        let unrealized = math?.unrealizedPnl ?? 0
        let exposure = accountingEngine.portfolioState.totalExposure
        let posSize = math?.positionSize ?? 0
        let exposurePct = exposure > 0 ? (posSize / exposure) * 100 : 0

        return HStack(spacing: 10) {
            // Ticker + side
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(trade.ticker.uppercased())
                        .font(.system(size: 13, weight: .bold))
                    Text(trade.side == .long ? "L" : "S")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(trade.side == .long ? .green : .red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((trade.side == .long ? Color.green : Color.red).opacity(0.15))
                        .clipShape(Capsule())
                }
                if let vwap = math?.vwap {
                    Text(vwap, format: .currency(code: "USD"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .stealthable()
                }
            }

            Spacer()

            // Exposure bar
            if exposurePct > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 3) {
                        if exposurePct > 70 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.red)
                        }
                        Text(String(format: "%.0f%%", exposurePct))
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                            .foregroundStyle(exposurePct > 70 ? .red : exposurePct > 40 ? .orange : .secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .blue, location: 0),
                                            .init(color: .orange, location: 0.5),
                                            .init(color: .red, location: 1)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(exposurePct / 100, 1))
                        }
                    }
                    .frame(width: 60, height: 4)
                }
            }

            // Unrealized P&L
            Text(unrealized >= 0 ? "+\(unrealized, specifier: "%.2f")" : "\(unrealized, specifier: "%.2f")")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(unrealized >= 0 ? .green : .red)
                .frame(minWidth: 70, alignment: .trailing)
                .stealthable()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
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
                    color: accountingEngine.portfolioState.totalPnl >= 0 ? .green : .red,
                    hideable: true
                )
                SummaryCard(
                    title: "Win Rate",
                    value: accountingEngine.portfolioState.closedTradesCount > 0 ? String(format: "%.0f%%", accountingEngine.portfolioState.winRate) : "N/A",
                    color: accountingEngine.portfolioState.winRate >= 50 ? .green : .orange,
                    hideable: false
                )
            }
            
            HStack(spacing: 15) {
                SummaryCard(
                    title: "Profit Factor",
                    value: accountingEngine.portfolioState.profitFactor.isInfinite ? "Perfect" : (accountingEngine.portfolioState.profitFactor > 0 ? String(format: "%.2f", accountingEngine.portfolioState.profitFactor) : "0.00"),
                    color: accountingEngine.portfolioState.profitFactor >= 1.5 ? .green : .orange,
                    hideable: false
                )
                SummaryCard(
                    title: "Avg Win / Loss",
                    value: "\(Int(accountingEngine.portfolioState.avgWin)) / \(Int(abs(accountingEngine.portfolioState.avgLoss)))",
                    color: accountingEngine.portfolioState.avgWin > abs(accountingEngine.portfolioState.avgLoss) ? .green : .red,
                    hideable: true
                )
            }

            HStack(spacing: 15) {
                SummaryCard(
                    title: "Avg Hold Time",
                    value: avgHoldTimeFormatted,
                    color: .cyan,
                    hideable: false
                )
                SummaryCard(
                    title: "Max Drawdown",
                    value: String(format: "%.1f%%", accountingEngine.portfolioState.maxDrawdown),
                    color: accountingEngine.portfolioState.maxDrawdown < 5.0 ? .green : .red,
                    hideable: false
                )
            }

            HStack(spacing: 15) {
                SummaryCard(
                    title: "Open Trades",
                    value: "\(accountingEngine.portfolioState.openTradesCount)",
                    color: .blue,
                    hideable: false
                )
                SummaryCard(
                    title: "Closed Trades",
                    value: "\(accountingEngine.portfolioState.closedTradesCount)",
                    color: .purple,
                    hideable: false
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Equity Curve

    @State private var scrubbedPoint: EquityDataPoint? = nil

    private var yDomain: ClosedRange<Double> {
        let profits = accountingEngine.portfolioState.equityCurve.map { $0.balance }
        let range = (profits.max() ?? 0) - (profits.min() ?? 0)
        let padding = max(range * 0.1, 50.0)
        let minP = (profits.min() ?? 0) - padding
        let maxP = (profits.max() ?? 0) + padding
        guard maxP > minP else { return -100...100 }
        return minP...maxP
    }

    private var equityCurveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Account Equity ($)")
                    .font(.headline)
                Spacer()
                if let pt = scrubbedPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(pt.balance, format: .currency(code: "USD"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(pt.balance >= (accountingEngine.portfolioState.equityCurve.first?.balance ?? 0) ? .green : .red)
                        Text(pt.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let ticker = pt.ticker {
                            Text(ticker)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal)

            VStack {
                if accountingEngine.portfolioState.equityCurve.count < 2 {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Close at least one trade to automatically generate your equity curve.")
                    )
                    .frame(height: 220)
                } else {
                    let curve = accountingEngine.portfolioState.equityCurve
                    let lineColor: Color = (curve.last?.balance ?? 0) >= (curve.first?.balance ?? 0) ? .green : .red

                    Chart {
                        // Base fill gradient
                        ForEach(curve) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                yStart: .value("Floor", yDomain.lowerBound),
                                yEnd: .value("Balance", point.balance)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [lineColor.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }

                        // Main equity line
                        ForEach(curve) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(lineColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        }

                        // Trade markers
                        ForEach(curve.filter { $0.isTrade }) { point in
                            PointMark(
                                x: .value("Time", point.date),
                                y: .value("Balance", point.balance)
                            )
                            .symbolSize(50)
                            .foregroundStyle(point.isWin == true ? Color.green : Color.red)
                        }

                        // Scrub rule + dot
                        if let pt = scrubbedPoint {
                            RuleMark(x: .value("Scrub", pt.date))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Color.white.opacity(0.4))
                            PointMark(
                                x: .value("Time", pt.date),
                                y: .value("Balance", pt.balance)
                            )
                            .symbolSize(120)
                            .foregroundStyle(Color.white)
                        }
                    }
                    .chartYScale(domain: yDomain)
                    .chartXAxis {
                        AxisMarks(preset: .aligned, position: .bottom)
                    }
                    .frame(height: 220)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let frame = proxy.plotFrame else { return }
                                            let x = value.location.x - geo[frame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                scrubbedPoint = curve.min(by: {
                                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                                })
                                            }
                                        }
                                        .onEnded { _ in
                                            withAnimation(.easeOut(duration: 0.2)) { scrubbedPoint = nil }
                                        }
                                )
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                            let spyProfit = (sr / 100.0) * portfolio.startingBalance
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
                                let spyProfit = ((point.close - firstSpy) / firstSpy) * portfolio.startingBalance
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
                } else {
                    ContentUnavailableView(
                        benchmarkTimeframe == .ytd ? "No Trades This Year" : "No Closed Trades",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Close a trade to compare your performance against the S&P 500.")
                    )
                    .frame(height: 180)
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
    
    private var timeOfDayLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "GOOD MORNING"
        case 12..<17: return "GOOD AFTERNOON"
        default: return "GOOD EVENING"
        }
    }

    private var dayOrdinal: String {
        let day = Calendar.current.component(.day, from: Date())
        let suffix: String
        switch day {
        case 11, 12, 13: suffix = "th"
        case _ where day % 10 == 1: suffix = "st"
        case _ where day % 10 == 2: suffix = "nd"
        case _ where day % 10 == 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(day)\(suffix)"
    }

    private var headerView: some View {
        let name = traderName.isEmpty ? "Trader" : traderName
        let weekday = Date().formatted(.dateTime.weekday(.wide))
        let month = Date().formatted(.dateTime.month(.wide))
        let year = Date().formatted(.dateTime.year())
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(timeOfDayLabel),")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.cyan)
                    .tracking(3)
                    .padding(.leading, 4)

                Text(name)
                    .font(personality.nameFont)
                    .foregroundStyle(personality.nameColor)
                    .italic(personality.isItalic)
                    .padding(.leading, 2)

                Button {
                    showPortfolioSwitcher = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 9))
                        Text(portfolio.name)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
                .padding(.top, 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(weekday.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.18))
                    .tracking(3)

                Text("\(month) \(dayOrdinal)")
                    .font(unreadableDate ? .custom("Zapfino", size: 26) : .system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.18))

                Text(year)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.1))
                    .tracking(1)

                Button {
                    stealthMode.toggle()
                } label: {
                    Image(systemName: stealthMode ? "eye.slash" : "eye")
                        .font(.system(size: 9))
                        .foregroundStyle(stealthMode ? .primary : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    // MARK: - Lifecycle Logic
    
    private func initializeDashboard() async {
        liveQuotes = [:]
        isDashboardReady = false
        accountingEngine.update(trades: trades, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        
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
                // An empty response means every symbol failed. Keep the last known
                // prices instead of clearing them — with no quote the engine leaves
                // unrealizedPnl at 0, which reads as "flat" rather than "unknown".
                if quotes.isEmpty {
                    self.quotesAreStale = true
                } else {
                    self.liveQuotes.merge(quotes) { _, new in new }
                    self.quotesAreStale = false
                }
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
        let spyProfits = spyHistoricalData.map { (($0.close - firstSpy) / firstSpy) * portfolio.startingBalance }
        
        let allValues = curve + spyProfits
        guard !allValues.isEmpty else { return -100...100 }
        let minV = (allValues.min() ?? 0) - 100
        let maxV = (allValues.max() ?? 0) + 100
        return minV...maxV
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    DashboardView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
