import SwiftUI
import SwiftData
import Charts

private let goldGradient = LinearGradient(
    colors: [Color(red: 0.92, green: 0.81, blue: 0.42), Color(red: 0.71, green: 0.55, blue: 0.18)],
    startPoint: .top, endPoint: .bottom
)

// MARK: - Data Models

struct StrategyStat: Identifiable {
    let id = UUID()
    let name: String
    let trades: [Trade]

    var closedTrades: [Trade] { trades.filter { $0.status == .closed && $0.math != nil } }
    var totalPnl: Double { closedTrades.compactMap { $0.math?.totalPnl }.reduce(0, +) }
    var winCount: Int { closedTrades.filter { $0.isWin }.count }
    var winRate: Double {
        guard !closedTrades.isEmpty else { return 0 }
        return Double(winCount) / Double(closedTrades.count) * 100
    }
    var profitFactor: Double {
        let pnls = closedTrades.compactMap { $0.math?.totalPnl }
        let grossWin = pnls.filter { $0 > 0 }.reduce(0, +)
        let grossLoss = abs(pnls.filter { $0 < 0 }.reduce(0, +))
        guard grossLoss > 0 else { return grossWin > 0 ? .infinity : 0 }
        return grossWin / grossLoss
    }
}

struct ConfidenceBucket: Identifiable {
    let id = UUID()
    let label: String
    let trades: [Trade]

    var count: Int { trades.count }
    var totalPnl: Double { trades.compactMap { $0.math?.totalPnl }.reduce(0, +) }
}

// MARK: - Main View

struct AnalyticsView: View {
    let portfolio: Portfolio

    @Query private var allTrades: [Trade]
    @Query private var capitalEvents: [CapitalEvent]
    @State private var engine = AccountingEngine.shared

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _allTrades = Query(filter: #Predicate<Trade> { $0.portfolio?.id == id })
        _capitalEvents = Query(filter: #Predicate<CapitalEvent> { $0.portfolio?.id == id })
    }

    private var closedTrades: [Trade] { allTrades.filter { $0.status == .closed } }
    private var state: AccountingState { engine.portfolioState }
    private var longTrades: [Trade]  { closedTrades.filter { $0.side == .long } }
    private var shortTrades: [Trade] { closedTrades.filter { $0.side == .short } }

    private func winRate(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return Double(trades.filter { $0.isWin }.count) / Double(trades.count) * 100
    }
    private func totalPnl(for trades: [Trade]) -> Double {
        trades.compactMap { $0.math?.totalPnl }.reduce(0, +)
    }

    private var strategyStats: [StrategyStat] {
        let grouped = Dictionary(grouping: closedTrades) { $0.strategy ?? "Untagged" }
        return grouped.map { StrategyStat(name: $0.key, trades: $0.value) }
            .sorted { $0.totalPnl > $1.totalPnl }
    }

    private var confidenceBuckets: [ConfidenceBucket] {
        let rated = closedTrades.filter { $0.confidenceScore > 0 }
        return [
            ConfidenceBucket(label: "LOW",  trades: rated.filter { $0.confidenceScore <= 4 }),
            ConfidenceBucket(label: "MID",  trades: rated.filter { (5...7).contains($0.confidenceScore) }),
            ConfidenceBucket(label: "HIGH", trades: rated.filter { $0.confidenceScore >= 8 }),
        ].filter { $0.count > 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if closedTrades.isEmpty {
                    ContentUnavailableView(
                        "No Closed Trades",
                        systemImage: "chart.bar.xaxis.ascending",
                        description: Text("Close your first trade to see your stats.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            donutHero
                            rule
                            avgWinLossSection
                            sectionBreak
                            sideSection
                            if !strategyStats.isEmpty {
                                sectionBreak
                                setupsSection
                            }
                            if !confidenceBuckets.isEmpty {
                                sectionBreak
                                convictionSection
                            }
                        }
                        .padding(.bottom, 60)
                    }
                }
            }
            .goldTitle("Stats")
            .darkNavigationBar()
        }
        .task(id: portfolio.id) {
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        }
        .onChange(of: allTrades) { _, new in
            engine.update(trades: new, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        }
        .onChange(of: capitalEvents) { _, new in
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: new)
        }
    }

    // MARK: - Primitives

    private var rule: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity, maxHeight: 0.5)
            .padding(.horizontal, 20)
    }

    private var sectionBreak: some View {
        rule.padding(.top, 28)
    }

    private func dimLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.25))
            .tracking(3)
    }

    // MARK: - Donut Hero

    private var donutHero: some View {
        VStack(spacing: 20) {
            ZStack {
                Chart {
                    SectorMark(
                        angle: .value("Wins", Double(max(state.winCount, 0))),
                        innerRadius: .ratio(0.68),
                        angularInset: 2.5
                    )
                    .foregroundStyle(Color.green.opacity(0.72))
                    .cornerRadius(3)

                    SectorMark(
                        angle: .value("Losses", Double(max(state.lossCount, 0))),
                        innerRadius: .ratio(0.68),
                        angularInset: 2.5
                    )
                    .foregroundStyle(Color.red.opacity(0.65))
                    .cornerRadius(3)
                }
                .chartLegend(.hidden)
                .frame(width: 190, height: 190)

                VStack(spacing: 5) {
                    Text(String(format: "%.0f%%", state.winRate))
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundStyle(goldGradient)
                    dimLabel("WIN RATE")
                }
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(state.profitFactor.isInfinite ? "∞" : String(format: "%.2f×", state.profitFactor))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                    dimLabel("PROFIT FACTOR")
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5, height: 32)

                VStack(spacing: 4) {
                    Text("\(state.closedTradesCount)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                    dimLabel("TRADES")
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5, height: 32)

                VStack(alignment: .center, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green.opacity(0.7)).frame(width: 5, height: 5)
                        Text("\(state.winCount)W")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.green.opacity(0.85))
                    }
                    HStack(spacing: 5) {
                        Circle().fill(Color.red.opacity(0.7)).frame(width: 5, height: 5)
                        Text("\(state.lossCount)L")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 32)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Avg Win / Avg Loss Bars

    private var avgWinLossSection: some View {
        let maxVal = max(state.avgWin, state.avgLoss, 1)
        let maxBarH: CGFloat = 72
        let winH = maxBarH * CGFloat(state.avgWin / maxVal)
        let lossH = maxBarH * CGFloat(state.avgLoss / maxVal)
        let ratio = state.avgLoss > 0 ? state.avgWin / state.avgLoss : 0

        return VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 48) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.green.opacity(0.65))
                        .frame(width: 44, height: max(winH, 6))
                    Text("+$\(Int(state.avgWin))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.green)
                    dimLabel("AVG WIN")
                }

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.red.opacity(0.65))
                        .frame(width: 44, height: max(lossH, 6))
                    Text("-$\(Int(state.avgLoss))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.red)
                    dimLabel("AVG LOSS")
                }
            }

            Text(String(format: "%.1f× SPREAD", ratio))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.15))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Side Performance

    private var sideSection: some View {
        let longWR  = winRate(for: longTrades)
        let shortWR = winRate(for: shortTrades)
        let longPnl  = totalPnl(for: longTrades)
        let shortPnl = totalPnl(for: shortTrades)

        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                dimLabel("LONG")
                Text(longTrades.isEmpty ? "—" : String(format: "%.0f%%", longWR))
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(longTrades.isEmpty ? Color.secondary : (longWR >= 50 ? Color.green : Color.red))
                if !longTrades.isEmpty {
                    Text(longPnl >= 0 ? "+$\(Int(longPnl))" : "-$\(Int(abs(longPnl)))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(longPnl >= 0 ? Color.green : Color.red)
                    Text("\(longTrades.count) trades")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5, height: 80)

            VStack(alignment: .trailing, spacing: 6) {
                dimLabel("SHORT")
                Text(shortTrades.isEmpty ? "—" : String(format: "%.0f%%", shortWR))
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(shortTrades.isEmpty ? Color.secondary : (shortWR >= 50 ? Color.green : Color.red))
                if !shortTrades.isEmpty {
                    Text(shortPnl >= 0 ? "+$\(Int(shortPnl))" : "-$\(Int(abs(shortPnl)))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(shortPnl >= 0 ? Color.green : Color.red)
                    Text("\(shortTrades.count) trades")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
    }

    // MARK: - Setups

    private var setupsSection: some View {
        let maxAbs = strategyStats.map { abs($0.totalPnl) }.max() ?? 1

        return VStack(spacing: 0) {
            dimLabel("SETUPS")
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 14)

            ForEach(Array(strategyStats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)
                }
                strategyRow(stat: stat, rank: index + 1, maxAbs: maxAbs)
            }
        }
        .padding(.bottom, 22)
    }

    private func strategyRow(stat: StrategyStat, rank: Int, maxAbs: Double) -> some View {
        let fill = maxAbs > 0 ? CGFloat(abs(stat.totalPnl) / maxAbs) : 0
        let barColor: Color = stat.totalPnl >= 0 ? .green : .red

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.2))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stat.name).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(stat.totalPnl >= 0 ? "+$\(Int(stat.totalPnl))" : "-$\(Int(abs(stat.totalPnl)))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(barColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2).fill(barColor.opacity(0.55))
                            .frame(width: geo.size.width * fill)
                    }
                }
                .frame(height: 3)
                HStack(spacing: 6) {
                    Text(String(format: "%.0f%% WR", stat.winRate))
                        .foregroundStyle(stat.winRate >= 50 ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                    Text("·").foregroundStyle(Color.white.opacity(0.15))
                    Text("\(stat.closedTrades.count) trades")
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .font(.system(size: 10, design: .monospaced))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Conviction (Horizontal Bar Chart)

    private var convictionSection: some View {
        let buckets = confidenceBuckets
        let allPnls = buckets.map { $0.totalPnl }
        let maxAbs = max(allPnls.map { abs($0) }.max() ?? 1, 1)
        let hasNegative = allPnls.contains { $0 < 0 }
        let xDomain: ClosedRange<Double> = hasNegative
            ? (-maxAbs * 1.5)...(maxAbs * 1.5)
            : 0...(maxAbs * 1.5)

        return VStack(alignment: .leading, spacing: 16) {
            dimLabel("CONVICTION")
                .padding(.horizontal, 20)

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("P&L", bucket.totalPnl),
                    y: .value("Level", bucket.label)
                )
                .foregroundStyle(bucket.totalPnl >= 0 ? Color.green.opacity(0.75) : Color.red.opacity(0.75))
                .cornerRadius(4)
                .annotation(position: bucket.totalPnl >= 0 ? .trailing : .leading, spacing: 8) {
                    VStack(alignment: bucket.totalPnl >= 0 ? .leading : .trailing, spacing: 1) {
                        Text(bucket.totalPnl >= 0 ? "+$\(Int(bucket.totalPnl))" : "-$\(Int(abs(bucket.totalPnl)))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(bucket.totalPnl >= 0 ? Color.green : Color.red)
                        Text("\(bucket.count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(d == 0 ? "0" : (d > 0 ? "+$\(Int(d))" : "-$\(Int(abs(d)))"))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                    }
                }
            }
            .frame(height: CGFloat(buckets.count) * 56 + 24)
            .padding(.horizontal, 20)
        }
        .padding(.top, 22)
        .padding(.bottom, 28)
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    AnalyticsView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
