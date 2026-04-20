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
    
    var winRate: Double {
        let closedTrades = trades.filter { $0.status == .closed && $0.math != nil }
        guard !closedTrades.isEmpty else { return 0 }
        let wins = closedTrades.filter { $0.isWin }.count
        return Double(wins) / Double(closedTrades.count) * 100
    }
    
    var profitFactor: Double {
        let pnls = trades.compactMap { $0.math?.totalPnl }
        let grossWin = pnls.filter { $0 > 0 }.reduce(0, +)
        let grossLoss = abs(pnls.filter { $0 < 0 }.reduce(0, +))
        guard grossLoss > 0 else { return grossWin > 0 ? .infinity : 0 }
        return grossWin / grossLoss
    }
}

struct AnalyticsView: View {
    var engine = AccountingEngine.shared
    
    init() {}
    
    // Note: To bypass SwiftData Predicate limits, we bring in all closed trades and filter down.
    @Query(filter: #Predicate<Trade> { $0.statusRaw == "Closed" }) private var closedTrades: [Trade]
    
    // Group trades by Strategy
    private var strategyStats: [StrategyStat] {
        let grouped = Dictionary(grouping: closedTrades) { trade in
            trade.strategy ?? "Uncategorized"
        }
        return grouped.map { StrategyStat(name: $0.key, trades: $0.value) }
            .sorted { $0.totalPnl > $1.totalPnl } // Highest earner at the top
    }
    
    private var yDomain: ClosedRange<Double> {
        let pnls = strategyStats.map { $0.totalPnl }
        let maxPnl = (pnls.max() ?? 0)
        let minPnl = (pnls.min() ?? 0)
        
        let paddedMax = maxPnl > 0 ? maxPnl * 1.2 : 0
        let paddedMin = minPnl < 0 ? minPnl * 1.2 : 0
        
        guard paddedMax > paddedMin else { return -10...10 }
        return paddedMin...paddedMax
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                if strategyStats.isEmpty {
                    ContentUnavailableView(
                        "No Strategy Data",
                        systemImage: "chart.bar.xaxis.ascending",
                        description: Text("Close trades with assigned strategies to see which setups give you the biggest edge.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // Bar Chart mapping PnL by Strategy
                            VStack(alignment: .leading, spacing: 16) {
                                Text("P&L by Setup")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Chart(strategyStats) { stat in
                                    BarMark(
                                        x: .value("Strategy", stat.name),
                                        y: .value("Total P&L", stat.totalPnl)
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(stat.totalPnl >= 0 ? Color.green : Color.red)
                                }
                                .chartYScale(domain: yDomain)
                                .frame(height: 250)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                            
                            // Underlying Spreadsheet Data
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Strategy Breakdown")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(strategyStats) { stat in
                                        strategyRow(stat)
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
    
    @ViewBuilder
    private func strategyRow(_ stat: StrategyStat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(stat.name)
                    .font(.system(size: 16, weight: .bold))
                
                Text("\(stat.trades.count) \(stat.trades.count == 1 ? "Trade" : "Trades")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(stat.totalPnl, format: .currency(code: "USD"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(stat.totalPnl >= 0 ? .green : .red)
                
                HStack(spacing: 12) {
                    Text("WR: \(stat.winRate, specifier: "%.0f")%")
                        .font(.caption2.bold())
                        .foregroundStyle(stat.winRate >= 50 ? .green : .secondary)
                    
                    Text("PF: \(stat.profitFactor == .infinity ? "N/A" : String(format: "%.2f", stat.profitFactor))")
                        .font(.caption2.bold())
                        .foregroundStyle(stat.profitFactor >= 1.5 ? .green : .secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    AnalyticsView()
        .preferredColorScheme(.dark)
}
