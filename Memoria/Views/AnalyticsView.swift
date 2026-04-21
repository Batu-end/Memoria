import SwiftUI
import SwiftData
import Charts

struct StrategyStat: Identifiable {
    let id = UUID()
    let name: String
    let trades: [Trade]
    
    var totalPnl: Double {
        trades.compactMap { $0.math?.totalPnl }.reduce(0, +)
    }
    
    var closedTrades: [Trade] {
        trades.filter { $0.status == .closed && $0.math != nil }
    }
    
    var winCount: Int {
        closedTrades.filter { $0.isWin }.count
    }
    
    var lossCount: Int {
        closedTrades.filter { !$0.isWin }.count
    }
    
    var winRate: Double {
        guard !closedTrades.isEmpty else { return 0 }
        return Double(winCount) / Double(closedTrades.count) * 100
    }
    
    var avgWin: Double {
        let wins = closedTrades.filter { $0.isWin }.compactMap { $0.math?.totalPnl }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0, +) / Double(wins.count)
    }
    
    var avgLoss: Double {
        let losses = closedTrades.filter { !$0.isWin }.compactMap { $0.math?.totalPnl }
        guard !losses.isEmpty else { return 0 }
        return abs(losses.reduce(0, +)) / Double(losses.count)
    }
    
    var profitFactor: Double {
        let pnls = closedTrades.compactMap { $0.math?.totalPnl }
        let grossWin = pnls.filter { $0 > 0 }.reduce(0, +)
        let grossLoss = abs(pnls.filter { $0 < 0 }.reduce(0, +))
        guard grossLoss > 0 else { return grossWin > 0 ? .infinity : 0 }
        return grossWin / grossLoss
    }
}

struct AnalyticsView: View {
    @Query(filter: #Predicate<Trade> { $0.statusRaw == "Closed" }) private var closedTrades: [Trade]
    
    // Group trades by Strategy
    private var strategyStats: [StrategyStat] {
        let grouped = Dictionary(grouping: closedTrades) { trade in
            trade.strategy ?? "Uncategorized"
        }
        return grouped.map { StrategyStat(name: $0.key, trades: $0.value) }
            .sorted { $0.totalPnl > $1.totalPnl }
    }
    
    // Global Side-based metrics
    private var longWinRate: Double {
        let longs = closedTrades.filter { $0.side == .long }
        guard !longs.isEmpty else { return 0 }
        return Double(longs.filter { $0.isWin }.count) / Double(longs.count) * 100
    }
    
    private var shortWinRate: Double {
        let shorts = closedTrades.filter { $0.side == .short }
        guard !shorts.isEmpty else { return 0 }
        return Double(shorts.filter { $0.isWin }.count) / Double(shorts.count) * 100
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                if strategyStats.isEmpty {
                    ContentUnavailableView(
                        "No Strategy Data",
                        systemImage: "chart.bar.xaxis.ascending",
                        description: Text("Close trades with assigned strategies to see your edge analysis.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            
                            // Top Row: Global Edge Insights
                            HStack(spacing: 16) {
                                EdgeMetricCard(title: "Long Strike", value: String(format: "%.0f%%", longWinRate), icon: "arrow.up.right", color: .blue)
                                EdgeMetricCard(title: "Short Strike", value: String(format: "%.0f%%", shortWinRate), icon: "arrow.down.right", color: .orange)
                            }
                            .padding(.horizontal)
                            
                            // ── Distribution & Matrix Row ──────────────────────
                            VStack(alignment: .leading, spacing: 16) {
                                Text("THE EDGE MATRIX")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 20) {
                                    // Allocation Donut
                                    VStack(alignment: .leading) {
                                        Text("Allocation")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        
                                        Chart(strategyStats) { stat in
                                            SectorMark(
                                                angle: .value("Trades", stat.closedTrades.count),
                                                innerRadius: .ratio(0.6),
                                                angularInset: 2
                                            )
                                            .cornerRadius(4)
                                            .foregroundStyle(by: .value("Strategy", stat.name))
                                        }
                                        .frame(height: 150)
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                                    
                                    // Win/Loss Frequency Matrix
                                    VStack(alignment: .leading) {
                                        Text("Win/Loss Ratio")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        
                                        Chart {
                                            ForEach(strategyStats) { stat in
                                                BarMark(
                                                    x: .value("Strategy", stat.name),
                                                    y: .value("Wins", stat.winCount)
                                                )
                                                .foregroundStyle(Color.green.opacity(0.8))
                                                .position(by: .value("Type", "Win"))
                                                
                                                BarMark(
                                                    x: .value("Strategy", stat.name),
                                                    y: .value("Losses", stat.lossCount)
                                                )
                                                .foregroundStyle(Color.red.opacity(0.8))
                                                .position(by: .value("Type", "Loss"))
                                            }
                                        }
                                        .frame(height: 150)
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                                }
                                .padding(.horizontal)
                            }
                            
                            // ── Performance Grid ─────────────────────────────
                            VStack(alignment: .leading, spacing: 16) {
                                Text("SETUP PERFORMANCE GRID")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(strategyStats) { stat in
                                        StrategyScorecard(stat: stat)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Analytics")
        }
    }
}

// MARK: - Supporting Views

struct EdgeMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.opacity(0.8))
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct StrategyScorecard: View {
    let stat: StrategyStat
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(stat.name)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(stat.totalPnl, format: .currency(code: "USD"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(stat.totalPnl >= 0 ? .green : .red)
            }
            .padding(16)
            
            Divider().background(Color.white.opacity(0.05))
            
            // Stats Grid
            Grid(horizontalSpacing: 20, verticalSpacing: 16) {
                GridRow {
                    MetricBox(label: "WIN RATE", value: String(format: "%.0f%%", stat.winRate), color: stat.winRate >= 50 ? .green : .orange)
                    MetricBox(label: "PROFIT FACTOR", value: stat.profitFactor == .infinity ? "N/A" : String(format: "%.2f", stat.profitFactor), color: stat.profitFactor >= 1.5 ? .green : .orange)
                }
                GridRow {
                    MetricBox(label: "AVG WIN", value: String(format: "+$%.0f", stat.avgWin), color: .green)
                    MetricBox(label: "AVG LOSS", value: String(format: "-$%.0f", stat.avgLoss), color: .red)
                }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct MetricBox: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AnalyticsView()
        .preferredColorScheme(.dark)
}
