import SwiftUI
import SwiftData
import Charts

// MARK: - Data Models

struct StrategyStat: Identifiable {
    let id = UUID()
    let name: String
    let trades: [Trade]

    var closedTrades: [Trade] { trades.filter { $0.status == .closed && $0.math != nil } }

    var totalPnl: Double { closedTrades.compactMap { $0.math?.totalPnl }.reduce(0, +) }
    var winCount: Int { closedTrades.filter { $0.isWin }.count }
    var lossCount: Int { closedTrades.filter { !$0.isWin }.count }
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
    let range: String
    let trades: [Trade]

    var count: Int { trades.count }
    var winRate: Double {
        guard !trades.isEmpty else { return 0 }
        return Double(trades.filter { $0.isWin }.count) / Double(trades.count) * 100
    }
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

    private var longTrades: [Trade] { closedTrades.filter { $0.side == .long } }
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
        let buckets: [ConfidenceBucket] = [
            ConfidenceBucket(label: "HIGH", range: "8–10", trades: rated.filter { $0.confidenceScore >= 8 }),
            ConfidenceBucket(label: "MID",  range: "5–7",  trades: rated.filter { (5...7).contains($0.confidenceScore) }),
            ConfidenceBucket(label: "LOW",  range: "1–4",  trades: rated.filter { $0.confidenceScore <= 4 }),
        ]
        return buckets.filter { $0.count > 0 }
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
                        VStack(spacing: 24) {
                            scoreboardHeader
                            winLossBarSection
                            sideBreakdown
                            if !strategyStats.isEmpty { strategyLeaderboard }
                            if !confidenceBuckets.isEmpty { convictionSection }
                        }
                        .padding(.vertical)
                        .padding(.bottom, 40)
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

    // MARK: - Scoreboard Header

    private var scoreboardHeader: some View {
        VStack(spacing: 10) {
            // Big three
            HStack(spacing: 0) {
                bigNumber(label: "WINS", value: "\(state.winCount)", color: .green)
                dividerLine
                bigNumber(label: "LOSSES", value: "\(state.lossCount)", color: .red)
                dividerLine
                bigNumber(label: "TRADES", value: "\(state.closedTradesCount)", color: .primary)
            }
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Key metrics strip
            HStack(spacing: 0) {
                miniStat(label: "WIN RATE",
                         value: String(format: "%.0f%%", state.winRate),
                         color: state.winRate >= 50 ? .green : .orange)
                miniStat(label: "PROFIT FACTOR",
                         value: state.profitFactor.isInfinite ? "∞" : String(format: "%.2f×", state.profitFactor),
                         color: state.profitFactor >= 1.5 ? .green : .orange)
                miniStat(label: "AVG WIN",
                         value: String(format: "+$%.0f", state.avgWin),
                         color: .green)
                miniStat(label: "AVG LOSS",
                         value: String(format: "-$%.0f", state.avgLoss),
                         color: .red)
            }
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    private func bigNumber(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 48)
    }

    // MARK: - Win / Loss Bar

    private var winLossBarSection: some View {
        let total = state.winCount + state.lossCount
        let winFrac = total > 0 ? CGFloat(state.winCount) / CGFloat(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    if winFrac > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.7))
                            .frame(width: (geo.size.width - 3) * winFrac)
                    }
                    if winFrac < 1 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.7))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 10)

            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 6, height: 6)
                    Text("\(state.winCount) wins")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    Text("\(state.lossCount) losses")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Long / Short Split

    private var sideBreakdown: some View {
        HStack(spacing: 12) {
            sideCard(label: "LONG", trades: longTrades, icon: "arrow.up.right", accent: .green)
            sideCard(label: "SHORT", trades: shortTrades, icon: "arrow.down.right", accent: .orange)
        }
        .padding(.horizontal)
    }

    private func sideCard(label: String, trades: [Trade], icon: String, accent: Color) -> some View {
        let wr = winRate(for: trades)
        let pnl = totalPnl(for: trades)
        let isEmpty = trades.isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(accent)
                    .tracking(2)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.5))
            }

            Text(isEmpty ? "—" : String(format: "%.0f%%", wr))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(isEmpty ? Color.secondary : (wr >= 50 ? Color.green : Color.red))

            HStack {
                Text(isEmpty ? "—" : (pnl >= 0 ? "+$\(Int(pnl))" : "-$\(Int(abs(pnl)))"))
                    .foregroundStyle(pnl >= 0 ? .green : .red)
                Spacer()
                Text(isEmpty ? "no trades" : "\(trades.count) trades")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Strategy Leaderboard

    private var strategyLeaderboard: some View {
        let maxAbs = strategyStats.map { abs($0.totalPnl) }.max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("SETUPS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(strategyStats.enumerated()), id: \.offset) { index, stat in
                    if index > 0 {
                        Divider().background(Color.white.opacity(0.05))
                    }
                    strategyRow(stat: stat, rank: index + 1, maxAbs: maxAbs)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal)
        }
    }

    private func strategyRow(stat: StrategyStat, rank: Int, maxAbs: Double) -> some View {
        let fill = maxAbs > 0 ? CGFloat(abs(stat.totalPnl) / maxAbs) : 0
        let barColor: Color = stat.totalPnl >= 0 ? .green : .red

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.quaternary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stat.name)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(stat.totalPnl >= 0 ? "+$\(Int(stat.totalPnl))" : "-$\(Int(abs(stat.totalPnl)))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(barColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor.opacity(0.65))
                            .frame(width: geo.size.width * fill)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 6) {
                    Text(String(format: "%.0f%% WR", stat.winRate))
                        .foregroundStyle(stat.winRate >= 50 ? .green : .orange)
                    Text("·").foregroundStyle(.quaternary)
                    Text("\(stat.closedTrades.count) trades")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Conviction (Confidence) Section

    private var convictionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONVICTION")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(confidenceBuckets.enumerated()), id: \.offset) { index, bucket in
                    if index > 0 {
                        Divider().background(Color.white.opacity(0.05))
                    }
                    convictionRow(bucket: bucket)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal)
        }
    }

    private func convictionRow(bucket: ConfidenceBucket) -> some View {
        let winColor: Color = bucket.winRate >= 50 ? .green : .red

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.label)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(winColor)
                    .tracking(1)
                Text(bucket.range)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
            .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(winColor.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(bucket.winRate / 100))
                }
            }
            .frame(height: 6)

            Text(String(format: "%.0f%%", bucket.winRate))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(winColor)
                .frame(width: 40, alignment: .trailing)

            Text("\(bucket.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    AnalyticsView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
