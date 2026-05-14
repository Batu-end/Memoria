import SwiftUI
import SwiftData
import Charts

struct ConfidenceBucket: Identifiable {
    let id = UUID()
    let label: String
    let trades: [Trade]
    var count: Int { trades.count }
    var totalPnl: Double { trades.compactMap { $0.math?.totalPnl }.reduce(0, +) }
}

private let strategyPalette: [Color] = [
    Color(red: 0.31, green: 0.78, blue: 0.47),
    Color(red: 0.35, green: 0.68, blue: 0.99),
    Color(red: 0.92, green: 0.81, blue: 0.42),
    Color(red: 0.99, green: 0.65, blue: 0.31),
    Color(red: 0.78, green: 0.45, blue: 0.99),
    Color(red: 0.99, green: 0.36, blue: 0.35),
]

// MARK: - Data Model

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
    var avgWin: Double {
        let wins = closedTrades.filter { $0.isWin }.compactMap { $0.math?.totalPnl }
        return wins.isEmpty ? 0 : wins.reduce(0, +) / Double(wins.count)
    }
    var avgLoss: Double {
        let losses = closedTrades.filter { !$0.isWin }.compactMap { $0.math?.totalPnl }
        return losses.isEmpty ? 0 : abs(losses.reduce(0, +) / Double(losses.count))
    }
}

// MARK: - Main View

struct AnalyticsView: View {
    let portfolio: Portfolio

    @Query private var allTrades: [Trade]
    @Query private var capitalEvents: [CapitalEvent]
    @State private var engine = AccountingEngine.shared

    @State private var benchmarkTimeframe: BenchmarkTimeframe = .ytd
    @State private var spyBaseline: Double?
    @State private var spyCurrent: Double?
    @State private var spyHistoricalData: [HistoricalQuote] = []

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

    private var dayOfWeekStats: [(day: String, pnl: Double, count: Int)] {
        let calendar = Calendar.current
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri"]
        var stats = Array(repeating: (pnl: 0.0, count: 0), count: 5)
        for trade in closedTrades {
            guard let closed = trade.dateClosed, let pnl = trade.math?.totalPnl else { continue }
            let weekday = calendar.component(.weekday, from: closed)
            let idx = ((weekday - 2) + 7) % 7
            if idx < 5 {
                stats[idx].pnl += pnl
                stats[idx].count += 1
            }
        }
        return dayNames.enumerated().map { (day: $1, pnl: stats[$0].pnl, count: stats[$0].count) }
    }

    private var benchmarkStartDate: Date {
        if benchmarkTimeframe == .ytd {
            return Calendar.current.date(from: DateComponents(
                year: Calendar.current.component(.year, from: Date()), month: 1, day: 1))!
        } else {
            return closedTrades.last?.dateAdded ?? Date()
        }
    }

    private var spyReturnPct: Double? {
        guard let current = spyCurrent, let baseline = spyBaseline, baseline > 0 else { return nil }
        return ((current - baseline) / baseline) * 100
    }

    private var relativeYDomainPct: ClosedRange<Double> {
        let startingBalance = max(portfolio.startingBalance, 1)
        let curve = engine.calculateRelativeCurve(from: benchmarkStartDate)
        let portfolioPcts = curve.map { ($0.balance / startingBalance) * 100 }
        let firstSpy = spyHistoricalData.first?.close ?? 1.0
        let spyPcts = spyHistoricalData.map { (($0.close - firstSpy) / firstSpy) * 100 }
        let all = portfolioPcts + spyPcts + [0.0]
        let pad = 2.0
        return ((all.min() ?? -5) - pad)...((all.max() ?? 5) + pad)
    }

    private func totalPnl(for trades: [Trade]) -> Double {
        trades.compactMap { $0.math?.totalPnl }.reduce(0, +)
    }
    private func winRate(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return Double(trades.filter { $0.isWin }.count) / Double(trades.count) * 100
    }
    private var avgHoldTimeFormatted: String {
        let closed = closedTrades.filter { $0.dateClosed != nil }
        guard !closed.isEmpty else { return "—" }
        let avgSec = closed.reduce(0.0) { $0 + $1.dateClosed!.timeIntervalSince($1.dateAdded) } / Double(closed.count)
        let days = Int(avgSec) / 86400
        let hours = (Int(avgSec) % 86400) / 3600
        let mins  = (Int(avgSec) % 3600) / 60
        if days > 0  { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
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
                            // ── Hero row ──────────────────────────────────
                            HStack(spacing: 12) {
                                winRateCard
                                profitFactorCard
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                            // ── Performance overview ──────────────────────
                            performanceSummaryCard
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            // ── Directional ───────────────────────────────
                            sectionHeader("DIRECTION")
                            HStack(spacing: 12) {
                                strikeCard(title: "LONG", trades: longTrades)
                                strikeCard(title: "SHORT", trades: shortTrades)
                            }
                            .padding(.horizontal, 16)

                            // ── Edge Matrix ───────────────────────────────
                            if !strategyStats.isEmpty {
                                sectionHeader("EDGE MATRIX")
                                allocationDonutCard
                                    .padding(.horizontal, 16)
                                strategyWinRateCard
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                            }

                            // ── Setup Performance ─────────────────────────
                            if !strategyStats.isEmpty {
                                sectionHeader("SETUP PERFORMANCE")
                                VStack(spacing: 8) {
                                    ForEach(Array(strategyStats.enumerated()), id: \.element.id) { index, stat in
                                        strategyCard(stat, colorIndex: index)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            // ── Conviction ────────────────────────────────
                            if !confidenceBuckets.isEmpty {
                                sectionHeader("CONVICTION")
                                convictionCard
                                    .padding(.horizontal, 16)
                            }

                            // ── Time Analysis ─────────────────────────────
                            if dayOfWeekStats.contains(where: { $0.count > 0 }) {
                                sectionHeader("TIME ANALYSIS")
                                dayOfWeekCard
                                    .padding(.horizontal, 16)
                            }

                            // ── Relative Strength ─────────────────────────
                            sectionHeader("VS S&P 500")
                            relativeStrengthCard
                                .padding(.horizontal, 16)

                            Spacer().frame(height: 60)
                        }
                    }
                }
            }
            .goldTitle("Stats")
            .darkNavigationBar()
        }
        .task(id: portfolio.id) {
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
            await fetchSpyData()
        }
        .onChange(of: allTrades) { _, new in
            engine.update(trades: new, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        }
        .onChange(of: capitalEvents) { _, new in
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: new)
        }
        .onChange(of: benchmarkTimeframe) { _, _ in
            Task { await fetchSpyData() }
        }
    }

    // MARK: - Primitives

    private func dimLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.3))
            .tracking(2)
    }

    // Step 3: Stronger section breaks — line + label, generous vertical breathing room
    private func sectionHeader(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private func card<Content: View>(
        border: Color = Color.white.opacity(0.08),
        tint: Color = .clear,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 12).fill(tint))
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 0.5))
    }

    private func hairline() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // Step 2: Row helper — replaces the zigzag metricCell grid
    private func metricRow(label: String, value: String, valueColor: Color = Color.white.opacity(0.85), stealth: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(valueColor)
                .stealthable(stealth)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Hero Cards

    // Step 1: Win Rate keeps color (primary metric). PF stays white/orange.
    private var winRateCard: some View {
        let wr = state.winRate
        let numberColor: Color = wr > 50
            ? Color(red: 0.70, green: 1.0, blue: 0.70)
            : wr < 50
                ? Color(red: 1.0, green: 0.70, blue: 0.70)
                : Color.white.opacity(0.55)
        return card {
            VStack(alignment: .leading, spacing: 8) {
                dimLabel("WIN RATE")
                Text(String(format: "%.0f%%", wr))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(numberColor)
                Text("\(state.closedTradesCount) closed trades")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var profitFactorCard: some View {
        let pf = state.profitFactor
        let numberColor: Color = pf > 1
            ? Color(red: 0.70, green: 1.0, blue: 0.70)
            : pf < 1
                ? Color(red: 1.0, green: 0.70, blue: 0.70)
                : Color.white.opacity(0.55)
        return card {
            VStack(alignment: .leading, spacing: 8) {
                dimLabel("PROFIT FACTOR")
                Text(pf.isInfinite ? "∞" : String(format: "%.2f×", pf))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(numberColor)
                Text(pf >= 1.5 ? "Profitable edge" : pf >= 1 ? "Breakeven range" : "Below target")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    // MARK: - Performance Summary Card

    // Step 2: rows instead of 2×2 grid. Step 1: only Total P&L gets color.
    private var performanceSummaryCard: some View {
        card {
            VStack(spacing: 0) {
                let pnl = state.totalPnl
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        dimLabel("TOTAL P&L")
                        Text(pnl >= 0
                             ? "+\(pnl, format: .currency(code: "USD"))"
                             : "\(pnl, format: .currency(code: "USD"))")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
                            .stealthable()
                    }
                    Spacer()
                }
                .padding(16)

                hairline()
                metricRow(label: "Avg Win",       value: state.avgWin  > 0 ? "+$\(Int(state.avgWin))"  : "—", valueColor: Color(red: 0.82, green: 1.0, blue: 0.82), stealth: true)
                hairline()
                metricRow(label: "Avg Loss",      value: state.avgLoss > 0 ? "−$\(Int(state.avgLoss))" : "—", valueColor: Color(red: 1.0, green: 0.82, blue: 0.82), stealth: true)
                hairline()
                metricRow(label: "Max Drawdown",  value: String(format: "%.1f%%", state.maxDrawdown))
                hairline()
                metricRow(label: "Avg Hold Time", value: avgHoldTimeFormatted)
            }
        }
    }

    // MARK: - Directional Cards

    // Step 1: win rate % keeps color (it's the card's one signal). P&L is white/dim.
    private func strikeCard(title: String, trades: [Trade]) -> some View {
        let wr  = winRate(for: trades)
        let pnl = totalPnl(for: trades)
        let wrColor: Color = trades.isEmpty
            ? Color.white.opacity(0.2)
            : wr > 50 ? Color(red: 0.70, green: 1.0, blue: 0.70)
            : wr < 50 ? Color(red: 1.0, green: 0.70, blue: 0.70)
            : Color.white.opacity(0.55)

        return card {
            VStack(alignment: .leading, spacing: 10) {
                dimLabel(title)
                Text(trades.isEmpty ? "—" : String(format: "%.0f%%", wr))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(wrColor)
                if !trades.isEmpty {
                    HStack(spacing: 4) {
                        Text(pnl >= 0 ? "+$\(Int(pnl))" : "−$\(Int(abs(pnl)))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.35))
                        Text("·")
                            .foregroundStyle(Color.white.opacity(0.15))
                        Text("\(trades.count) trades")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    // MARK: - Edge Matrix

    private var allocationDonutCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                dimLabel("TRADE ALLOCATION")
                Chart(Array(strategyStats.enumerated()), id: \.element.id) { index, stat in
                    SectorMark(
                        angle: .value("Trades", stat.closedTrades.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(strategyPalette[index % strategyPalette.count])
                    .cornerRadius(3)
                }
                .chartLegend(.hidden)
                .frame(height: 150)
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    ForEach(Array(strategyStats.enumerated()), id: \.element.id) { index, stat in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(strategyPalette[index % strategyPalette.count])
                                .frame(width: 6, height: 6)
                            Text(stat.name)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.55))
                            Spacer()
                            Text("\(stat.closedTrades.count) trades")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var strategyWinRateCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                dimLabel("WIN RATE BY SETUP")
                Chart {
                    ForEach(strategyStats) { stat in
                        BarMark(
                            x: .value("Strategy", stat.name),
                            y: .value("Win Rate", stat.winRate)
                        )
                        .foregroundStyle(stat.winRate >= 50 ? Color.green.opacity(0.55) : Color.orange.opacity(0.55))
                        .cornerRadius(4)
                    }
                    RuleMark(y: .value("Breakeven", 50.0))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .trailing, alignment: .bottomLeading, spacing: 4) {
                            Text("50%")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let name = value.as(String.self) {
                                Text(String(name.prefix(3)).uppercased())
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 100]) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
            .padding(16)
        }
    }

    // MARK: - Strategy Card

    // Step 1: P&L in header keeps color (outcome signal). Step 2: metrics are rows, all white.
    private func strategyCard(_ stat: StrategyStat, colorIndex: Int) -> some View {
        let accent = strategyPalette[colorIndex % strategyPalette.count]
        return card(border: accent.opacity(0.35)) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                        Text(stat.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    Spacer()
                    Text(stat.totalPnl >= 0
                         ? "+$\(String(format: "%.0f", stat.totalPnl))"
                         : "−$\(String(format: "%.0f", abs(stat.totalPnl)))")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(stat.totalPnl >= 0 ? Color.green : Color.red)
                        .stealthable()
                }
                .padding(16)

                hairline()
                metricRow(
                    label: "Win Rate",
                    value: String(format: "%.0f%%", stat.winRate),
                    valueColor: stat.winRate > 50 ? Color(red: 0.85, green: 1.0, blue: 0.85) : stat.winRate < 50 ? Color(red: 1.0, green: 0.85, blue: 0.85) : Color.white.opacity(0.55)
                )
                hairline()
                metricRow(
                    label: "Profit Factor",
                    value: stat.profitFactor.isInfinite ? "∞" : String(format: "%.2f×", stat.profitFactor),
                    valueColor: stat.profitFactor > 1 ? Color(red: 0.85, green: 1.0, blue: 0.85) : stat.profitFactor < 1 ? Color(red: 1.0, green: 0.85, blue: 0.85) : Color.white.opacity(0.55)
                )
                hairline()
                metricRow(label: "Avg Win",       value: stat.avgWin  > 0 ? "+$\(Int(stat.avgWin))"  : "—", valueColor: Color(red: 0.82, green: 1.0, blue: 0.82), stealth: true)
                hairline()
                metricRow(label: "Avg Loss",      value: stat.avgLoss > 0 ? "−$\(Int(stat.avgLoss))" : "—", valueColor: Color(red: 1.0, green: 0.82, blue: 0.82), stealth: true)
            }
        }
    }

    // MARK: - Conviction Card

    private var convictionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                let buckets = confidenceBuckets
                let maxAbs = max(buckets.map { abs($0.totalPnl) }.max() ?? 1, 1)
                let hasNeg = buckets.contains { $0.totalPnl < 0 }
                let xDomain: ClosedRange<Double> = hasNeg ? (-maxAbs * 1.5)...(maxAbs * 1.5) : 0...(maxAbs * 1.5)

                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("P&L", bucket.totalPnl),
                        y: .value("Level", bucket.label)
                    )
                    .foregroundStyle(bucket.totalPnl >= 0 ? Color.green.opacity(0.65) : Color.orange.opacity(0.65))
                    .cornerRadius(4)
                    .annotation(position: bucket.totalPnl >= 0 ? .trailing : .leading, spacing: 8) {
                        VStack(alignment: bucket.totalPnl >= 0 ? .leading : .trailing, spacing: 1) {
                            Text(bucket.totalPnl >= 0 ? "+$\(Int(bucket.totalPnl))" : "−$\(Int(abs(bucket.totalPnl)))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .stealthable()
                            Text("\(bucket.count) trades")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
                .chartXScale(domain: xDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(d == 0 ? "0" : (d > 0 ? "+$\(Int(d))" : "−$\(Int(abs(d)))"))
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
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text(label == "LOW" ? "1–4" : label == "MID" ? "5–7" : "8–10")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color.white.opacity(0.22))
                                }
                            }
                        }
                    }
                }
                .frame(height: CGFloat(buckets.count) * 60 + 24)
            }
            .padding(16)
        }
    }

    // MARK: - Day of Week Card

    private var dayOfWeekCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                // avg P&L per trade per day — immune to count bias
                let stats = dayOfWeekStats.map { (day: $0.day, avg: $0.count > 0 ? $0.pnl / Double($0.count) : 0, count: $0.count) }
                let maxAbs = max(stats.map { abs($0.avg) }.max() ?? 1, 1)
                let hasNeg = stats.contains { $0.avg < 0 }
                let xDomain: ClosedRange<Double> = hasNeg ? (-maxAbs * 1.4)...(maxAbs * 1.4) : 0...(maxAbs * 1.4)

                Chart(stats, id: \.day) { item in
                    BarMark(
                        x: .value("Avg P&L", item.avg),
                        y: .value("Day", item.day)
                    )
                    .foregroundStyle(item.avg >= 0 ? Color.green.opacity(0.65) : Color.orange.opacity(0.65))
                    .cornerRadius(4)
                    .annotation(position: item.avg >= 0 ? .trailing : .leading, spacing: 6) {
                        if item.count > 0 {
                            VStack(alignment: item.avg >= 0 ? .leading : .trailing, spacing: 1) {
                                Text(item.avg >= 0 ? "+$\(Int(item.avg))" : "−$\(Int(abs(item.avg)))")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .stealthable()
                                Text("\(item.count) trades")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                        }
                    }
                }
                .chartXScale(domain: xDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(d == 0 ? "$0" : (d > 0 ? "+$\(Int(d))" : "−$\(Int(abs(d)))"))
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
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.45))
                            }
                        }
                    }
                }
                .frame(height: 210)
            }
            .padding(16)
        }
    }

    // MARK: - Relative Strength Card

    // Step 4: % basis. Both curves start at 0. Zero baseline rule. Header shows TWR% vs SPY%.
    private var relativeStrengthCard: some View {
        card {
            VStack(alignment: .leading, spacing: 0) {
                // Header: timeframe picker + return summary
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        dimLabel("RETURN COMPARISON")
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("YOU")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .tracking(1)
                                let twr = state.twr * 100
                                Text(twr >= 0 ? String(format: "+%.1f%%", twr) : String(format: "%.1f%%", twr))
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundStyle(twr >= 0 ? Color.green : Color.red)
                            }
                            Text("vs")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .padding(.top, 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("S&P 500")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .tracking(1)
                                if let sr = spyReturnPct {
                                    Text(sr >= 0 ? String(format: "+%.1f%%", sr) : String(format: "%.1f%%", sr))
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.55))
                                } else {
                                    Text("—")
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.2))
                                }
                            }
                        }
                    }
                    Spacer()
                    Picker("", selection: $benchmarkTimeframe) {
                        ForEach(BenchmarkTimeframe.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
                .padding(16)

                hairline()

                // Chart: % from 0
                let startingBalance = max(portfolio.startingBalance, 1)
                let relativeData = engine.calculateRelativeCurve(from: benchmarkStartDate)
                let twrColor: Color = state.twr >= 0 ? .green : .red

                if relativeData.count >= 2 {
                    Chart {
                        // Zero baseline
                        RuleMark(y: .value("Zero", 0.0))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.12))

                        // Portfolio curve (% TWR)
                        ForEach(relativeData) { point in
                            let pct = (point.balance / startingBalance) * 100
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Return %", pct),
                                series: .value("Series", "You")
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(twrColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        }

                        // SPY curve (%)
                        if let firstSpy = spyHistoricalData.first?.close, firstSpy > 0 {
                            ForEach(spyHistoricalData) { point in
                                let pct = ((point.close - firstSpy) / firstSpy) * 100
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Return %", pct),
                                    series: .value("Series", "S&P 500")
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Color.white.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            }
                        }
                    }
                    .chartYScale(domain: relativeYDomainPct)
                    .chartXAxis {
                        AxisMarks(preset: .aligned, position: .bottom) { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                            AxisValueLabel()
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text(d >= 0 ? "+\(String(format: "%.0f", d))%" : "\(String(format: "%.0f", d))%")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Legend
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1).fill(twrColor).frame(width: 16, height: 2.5)
                            Text("Your portfolio")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.3)).frame(width: 16, height: 1.5)
                            Text("S&P 500")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else {
                    ContentUnavailableView(
                        benchmarkTimeframe == .ytd ? "No Trades This Year" : "No Closed Trades",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Close a trade to compare your performance against the S&P 500.")
                    )
                    .frame(height: 180)
                    .padding(16)
                }
            }
        }
    }

    // MARK: - SPY Fetch

    private func fetchSpyData() async {
        let start = benchmarkStartDate
        async let baseline = StockQuoteService.shared.fetchBaselinePrice(symbol: "SPY", startDate: start)
        async let current = StockQuoteService.shared.fetchQuote(for: "SPY")
        async let history = StockQuoteService.shared.fetchHistoricalSeries(symbol: "SPY", startDate: start)
        let (b, c, h) = await (baseline, current, history)
        spyBaseline = b
        spyCurrent = c?.currentPrice
        spyHistoricalData = h ?? []
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    AnalyticsView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
