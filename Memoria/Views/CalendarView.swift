//
//  CalendarView.swift
//  Memoria

import SwiftUI
import SwiftData

struct CalendarView: View {
    let portfolio: Portfolio

    @Query private var allTrades: [Trade]
    @State private var engine = AccountingEngine.shared
    @State private var selectedDay: Date? = nil

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _allTrades = Query(
            filter: #Predicate<Trade> { $0.portfolio?.id == id },
            sort: \Trade.dateAdded,
            order: .forward
        )
    }

    // MARK: - Derived Data

    private let cal = Calendar.current
    private var dailyPnl: [Date: Double] { engine.portfolioState.dailyPnl }

    private var gridStart: Date {
        let firstClose = allTrades.compactMap { $0.dateClosed }.min()
            ?? allTrades.map { $0.dateAdded }.min()
            ?? Date()
        let start = cal.startOfDay(for: firstClose)
        let weekday = cal.component(.weekday, from: start)
        let daysBack = weekday == 1 ? 6 : weekday - 2
        return cal.date(byAdding: .day, value: -daysBack, to: start) ?? start
    }

    private var weeks: [[Date?]] {
        let today = cal.startOfDay(for: Date())
        var result: [[Date?]] = []
        var cursor = gridStart
        while cursor <= today {
            var week: [Date?] = []
            for _ in 0..<7 {
                week.append(cursor <= today ? cursor : nil)
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            result.append(week)
        }
        return result
    }

    private var maxAbsPnl: Double {
        max(dailyPnl.values.map { abs($0) }.max() ?? 1, 1)
    }

    private func cellColor(for date: Date) -> Color {
        guard let pnl = dailyPnl[date] else { return Color.white.opacity(0.07) }
        if pnl == 0 { return Color.white.opacity(0.1) }
        let intensity = 0.2 + (abs(pnl) / maxAbsPnl) * 0.8
        return (pnl > 0 ? Color.green : Color.red).opacity(intensity)
    }

    private var greenDays: Int { dailyPnl.values.filter { $0 > 0 }.count }
    private var redDays:   Int { dailyPnl.values.filter { $0 < 0 }.count }
    private var bestDay:  Double { dailyPnl.values.max() ?? 0 }
    private var worstDay: Double { dailyPnl.values.min() ?? 0 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if dailyPnl.isEmpty {
                    ContentUnavailableView(
                        "No Closed Trades",
                        systemImage: "calendar",
                        description: Text("Close a trade to see your trading heartbeat.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            statsBar
                            gridCard
                            if let day = selectedDay {
                                dayDetailCard(for: day)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 8)
                        .animation(.spring(response: 0.3), value: selectedDay)
                    }
                }
            }
            .goldTitle("Calendar")
            .darkNavigationBar()
        }
        .task(id: portfolio.id) {
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance)
        }
        .onChange(of: allTrades) { _, newValue in
            engine.update(trades: newValue, startingBalance: portfolio.startingBalance)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statPill(label: "GREEN", value: "\(greenDays)d", color: .green)
            Divider().frame(height: 30)
            statPill(label: "RED", value: "\(redDays)d", color: .red)
            Divider().frame(height: 30)
            statPill(label: "BEST", value: bestDay > 0 ? "+$\(Int(bestDay))" : "--", color: .green)
            Divider().frame(height: 30)
            statPill(label: "WORST", value: worstDay < 0 ? "-$\(Int(abs(worstDay)))" : "--", color: .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal)
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Calendar Grid

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRADING ACTIVITY")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 6) {
                // Fixed day-of-week labels
                VStack(spacing: cellSpacing) {
                    Color.clear.frame(height: 10) // spacer for month label row
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 26, height: cellSize, alignment: .trailing)
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                                VStack(spacing: cellSpacing) {
                                    Text(monthLabel(weekIndex: idx, week: week))
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(height: 10)

                                    ForEach(0..<7, id: \.self) { di in
                                        if let date = week[di] {
                                            dayCell(for: date)
                                        } else {
                                            Color.clear.frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                                .id(idx)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .onAppear {
                        proxy.scrollTo(max(weeks.count - 1, 0), anchor: .trailing)
                    }
                }
            }
            .padding(.leading)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal)
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = selectedDay == date
        return RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(for: date))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.25 : 1.0)
            .onTapGesture {
                withAnimation(.spring(response: 0.25)) {
                    selectedDay = selectedDay == date ? nil : date
                }
            }
    }

    private func monthLabel(weekIndex: Int, week: [Date?]) -> String {
        guard let first = week.compactMap({ $0 }).first else { return "" }
        let day = cal.component(.day, from: first)
        guard weekIndex == 0 || day <= 7 else { return "" }
        return first.formatted(.dateTime.month(.abbreviated)).uppercased()
    }

    // MARK: - Day Detail Card

    private func dayDetailCard(for date: Date) -> some View {
        let pnl = dailyPnl[date]
        let tradesOnDay = allTrades.filter {
            guard let closed = $0.dateClosed else { return false }
            return cal.startOfDay(for: closed) == date
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Button { withAnimation { selectedDay = nil } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }

            if let pnl {
                Text(pnl >= 0 ? "+\(pnl, specifier: "%.2f")" : "\(pnl, specifier: "%.2f")")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(pnl >= 0 ? Color.green : Color.red)
            }

            if !tradesOnDay.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                VStack(spacing: 6) {
                    ForEach(tradesOnDay) { trade in
                        HStack {
                            Text(trade.ticker)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text(trade.side == .long ? "LONG" : "SHORT")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(trade.side == .long ? .green : .red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background((trade.side == .long ? Color.green : Color.red).opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                            if let tradePnl = engine.tradeAccounting[trade.id]?.totalPnl {
                                Text(tradePnl >= 0 ? "+\(tradePnl, specifier: "%.2f")" : "\(tradePnl, specifier: "%.2f")")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(tradePnl >= 0 ? Color.green : Color.red)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal)
    }
}
