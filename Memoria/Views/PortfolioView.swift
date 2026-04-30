//
//  PortfolioView.swift
//  Memoria
//
//  Created by Batu Demirtas on 1/28/26.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    let portfolio: Portfolio

    @Environment(\.modelContext) private var modelContext
    @Query private var openTrades: [Trade]

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _openTrades = Query(
            filter: #Predicate<Trade> { $0.portfolio?.id == id && $0.statusRaw == "Open" },
            sort: \Trade.dateAdded, order: .reverse
        )
    }

    @State private var liveQuotes: [String: StockQuote] = [:]
    @State private var accountingEngine = AccountingEngine.shared
    @State private var isRefreshing = false

    private var totalExposure: Double { accountingEngine.portfolioState.totalExposure }
    private var totalUnrealized: Double { accountingEngine.portfolioState.unrealizedPnl }
    private var netLiquidity: Double { accountingEngine.portfolioState.netLiquidity }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    positionsList
                }
                .padding(.vertical)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            )
            .navigationTitle("Open Positions")
            .darkNavigationBar()
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await fetchLiveQuotes() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                }
            }
            .task { await fetchLiveQuotes() }
            .onChange(of: liveQuotes) { _, newValue in
                accountingEngine.update(quotes: newValue)
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                headerCard(
                    title: "UNREALIZED P&L",
                    value: totalUnrealized >= 0
                        ? "+\(totalUnrealized.formatted(.currency(code: "USD")))"
                        : totalUnrealized.formatted(.currency(code: "USD")),
                    color: totalUnrealized >= 0 ? .green : .red,
                    hideable: true
                )
                headerCard(
                    title: "TOTAL EXPOSURE",
                    value: totalExposure.formatted(.currency(code: "USD")),
                    color: .blue,
                    hideable: true
                )
            }
            HStack(spacing: 12) {
                headerCard(
                    title: "NET LIQUIDITY",
                    value: netLiquidity.formatted(.currency(code: "USD")),
                    color: .white,
                    hideable: true
                )
                headerCard(
                    title: "OPEN POSITIONS",
                    value: "\(openTrades.count)",
                    color: .purple,
                    hideable: false
                )
            }
        }
        .padding(.horizontal)
    }

    private func headerCard(title: String, value: String, color: Color, hideable: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .stealthable(hideable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Positions List

    @ViewBuilder
    private var positionsList: some View {
        if openTrades.isEmpty {
            ContentUnavailableView(
                "No Open Positions",
                systemImage: "tray",
                description: Text("Add a trade to start tracking your portfolio.")
            )
            .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Positions")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(openTrades) { trade in
                    PositionRowView(
                        trade: trade,
                        liveQuote: liveQuotes[trade.ticker.uppercased()],
                        totalExposure: totalExposure
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Data

    private func fetchLiveQuotes() async {
        guard !openTrades.isEmpty else { return }
        isRefreshing = true
        let tickers = Array(Set(openTrades.map { $0.ticker }))
        let quotes = await StockQuoteService.shared.fetchQuotes(for: tickers)
        await MainActor.run {
            withAnimation { self.liveQuotes = quotes }
            self.isRefreshing = false
        }
    }
}

// MARK: - Position Row

struct PositionRowView: View {
    let trade: Trade
    let liveQuote: StockQuote?
    let totalExposure: Double

    private var math: TradeAccounting? { trade.math }
    private var entry: Double? { math?.vwap ?? trade.entryPrice }
    private var livePrice: Double? { liveQuote?.currentPrice }
    private var unrealizedPnl: Double { math?.unrealizedPnl ?? 0 }
    private var positionSize: Double { math?.positionSize ?? 0 }
    private var exposurePct: Double { totalExposure > 0 ? (positionSize / totalExposure) * 100 : 0 }

    private var stopDistance: Double? {
        guard let e = entry, let sl = trade.stopLoss, e > 0 else { return nil }
        return ((sl - e) / e) * 100 * (trade.side == .short ? -1 : 1)
    }

    private var daysHeld: Int {
        Calendar.current.dateComponents([.day], from: trade.dateAdded, to: Date()).day ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(trade.ticker.uppercased())
                            .font(.system(size: 17, weight: .bold))
                        sideBadge
                    }
                    if let strategy = trade.strategy, !strategy.isEmpty {
                        Text(strategy)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(unrealizedPnl >= 0
                         ? "+\(unrealizedPnl.formatted(.currency(code: "USD")))"
                         : unrealizedPnl.formatted(.currency(code: "USD")))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(unrealizedPnl >= 0 ? .green : .red)
                        .stealthable()
                    if let price = livePrice {
                        Text(price.formatted(.currency(code: "USD")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .stealthable()
                    }
                }
            }
            .padding(.bottom, 10)

            Divider().opacity(0.2)

            HStack(spacing: 0) {
                metricCell(label: "ENTRY", value: entry.map { $0.formatted(.currency(code: "USD")) } ?? "—", hideable: true)
                metricCell(label: "SIZE", value: positionSize > 0 ? positionSize.formatted(.currency(code: "USD")) : "—", hideable: true)
                metricCell(
                    label: "EXPOSURE",
                    value: exposurePct > 0 ? String(format: "%.1f%%", exposurePct) : "—",
                    valueColor: exposurePct > 30 ? .orange : .white,
                    hideable: false
                )
                metricCell(
                    label: "STOP DIST",
                    value: stopDistance.map { String(format: "%+.1f%%", $0) } ?? "—",
                    valueColor: (stopDistance ?? 0) < -5 ? .red : .secondary,
                    hideable: false
                )
                metricCell(label: "DAYS", value: "\(daysHeld)d", hideable: false)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    unrealizedPnl >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    private var sideBadge: some View {
        Text(trade.side == .long ? "LONG" : "SHORT")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(trade.side == .long ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((trade.side == .long ? Color.green : Color.red).opacity(0.15))
            .clipShape(Capsule())
    }

    private func metricCell(label: String, value: String, valueColor: Color = .white, hideable: Bool = true) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .stealthable(hideable)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let portfolio = Portfolio(name: "Main")
    PortfolioView(portfolio: portfolio)
        .preferredColorScheme(.dark)
}
