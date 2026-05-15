//
//  CalendarView.swift
//  Memoria

import SwiftUI
import SwiftData

private struct SelectedDate: Identifiable {
    let id: Date
    var date: Date { id }
}

struct CalendarView: View {
    let portfolio: Portfolio

    @Query private var allTrades: [Trade]
    @Query private var capitalEvents: [CapitalEvent]
    @State private var engine = AccountingEngine.shared
    @State private var selectedDay: SelectedDate? = nil
    @State private var displayMonth: Date = Date()

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _allTrades = Query(
            filter: #Predicate<Trade> { $0.portfolio?.id == id },
            sort: \Trade.dateAdded, order: .forward
        )
        _capitalEvents = Query(filter: #Predicate<CapitalEvent> { $0.portfolio?.id == id })
    }

    // MARK: - Derived

    private let cal = Calendar.current
    private var dailyPnl: [Date: Double] { engine.portfolioState.dailyPnl }
    private var maxAbsPnl: Double { max(dailyPnl.values.map { abs($0) }.max() ?? 1, 1) }

    private var dailyPnlForMonth: [Date: Double] {
        dailyPnl.filter { cal.isDate($0.key, equalTo: displayMonth, toGranularity: .month) }
    }
    private var monthlyPnl:     Double { dailyPnlForMonth.values.reduce(0, +) }
    private var monthGreenDays: Int    { dailyPnlForMonth.values.filter { $0 > 0 }.count }
    private var monthRedDays:   Int    { dailyPnlForMonth.values.filter { $0 < 0 }.count }
    private var monthBestDay:   Double { dailyPnlForMonth.values.max() ?? 0 }
    private var monthWorstDay:  Double { dailyPnlForMonth.values.min() ?? 0 }

    private func monthStart(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var monthDays: [Date?] {
        let start = monthStart(displayMonth)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let weekday = cal.component(.weekday, from: start)
        let offset  = weekday == 1 ? 6 : weekday - 2
        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in range { days.append(cal.date(byAdding: .day, value: i - 1, to: start)) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var canGoForward: Bool { monthStart(displayMonth) < monthStart(Date()) }

    private func cellBackground(for date: Date) -> Color {
        guard let pnl = dailyPnl[date], pnl != 0 else { return .clear }
        let intensity = 0.15 + (abs(pnl) / maxAbsPnl) * 0.5
        return (pnl > 0 ? Color.green : Color.red).opacity(intensity)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color.white.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if dailyPnl.isEmpty {
                    ContentUnavailableView(
                        "No Closed Trades",
                        systemImage: "calendar",
                        description: Text("Close a trade to see your trading calendar.")
                    )
                } else {
                    VStack(spacing: 0) {
                        // Calendar — fills all available space
                        VStack(spacing: 8) {
                            monthNavHeader
                            weekdayRow
                            calendarGrid
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Monthly summary — pinned at bottom
                        monthlySummaryCard
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                    }
                }
            }
            .goldTitle("Calendar")
            .darkNavigationBar()
        }
        .sheet(item: $selectedDay) { selected in
            dayDetailSheet(for: selected.date)
                .presentationDetents([.fraction(0.45), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .task(id: portfolio.id) {
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        }
        .onChange(of: allTrades)      { _, v in engine.update(trades: v, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents) }
        .onChange(of: capitalEvents)  { _, v in engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: v) }
    }

    // MARK: - Month Nav Header

    private var monthNavHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(displayMonth, format: .dateTime.month(.wide).year())
                .font(.system(size: 15, weight: .bold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(canGoForward ? .secondary : .quaternary)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(canGoForward ? 0.07 : 0.02))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
    }

    // MARK: - Weekday Row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid (fills remaining space)

    private var calendarGrid: some View {
        let rowCount = monthDays.count / 7
        let rows = (0..<rowCount).map { i in Array(monthDays[i*7..<(i+1)*7]) }
        // Each row gets equal share of available height via maxHeight: .infinity
        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(for: date)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let direction = value.translation.width < 0 ? 1 : -1
                        let next = cal.date(byAdding: .month, value: direction, to: displayMonth) ?? displayMonth
                        if direction == 1 && !canGoForward { return }
                        displayMonth = next
                        selectedDay = nil
                    }
                }
        )
    }

    // MARK: - Day Cell

    private func formatCellPnl(_ pnl: Double) -> String {
        let abs = Swift.abs(pnl)
        let prefix = pnl >= 0 ? "+" : "-"
        if abs >= 10_000 { return "\(prefix)\(Int(abs / 1000))k" }
        if abs >= 1_000  { return String(format: "\(prefix)%.1fk", abs / 1000) }
        return "\(prefix)\(Int(abs))"
    }

    private func dayCell(for date: Date) -> some View {
        let pnl        = dailyPnl[date]
        let isSelected = selectedDay?.date == date
        let isToday    = cal.isDateInToday(date)

        return Button {
            guard pnl != nil else { return }
            withAnimation(.spring(response: 0.25)) {
                selectedDay = SelectedDate(id: date)
            }
        } label: {
            VStack(alignment: .center, spacing: 4) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isToday ? Color(red: 0.92, green: 0.81, blue: 0.42) : .secondary)

                if let pnl {
                    Text(formatCellPnl(pnl))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(cellBackground(for: date))
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(
                    isSelected ? Color.white.opacity(0.5) :
                    isToday    ? Color(red: 0.92, green: 0.81, blue: 0.42).opacity(0.5) :
                                 Color.white.opacity(0.04),
                    lineWidth: isSelected ? 1.5 : isToday ? 1.0 : 0.5
                )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Monthly Summary Card

    private var monthlySummaryCard: some View {
        let pnl = monthlyPnl
        return HStack(spacing: 0) {
            // Total P&L
            VStack(alignment: .leading, spacing: 3) {
                Text("MONTH")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text(pnl >= 0 ? "+$\(Int(pnl))" : "-$\(Int(abs(pnl)))")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(pnl >= 0 ? Color(red: 0.35, green: 0.85, blue: 0.55) : Color(red: 0.95, green: 0.38, blue: 0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .stealthable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 36).padding(.horizontal, 12)

            summaryCell(label: "GREEN", value: "\(monthGreenDays)d", color: Color(red: 0.35, green: 0.85, blue: 0.55))
            summaryCell(label: "RED",   value: "\(monthRedDays)d",   color: Color(red: 0.95, green: 0.38, blue: 0.38))

            Divider().frame(height: 36).padding(.horizontal, 12)

            summaryCell(label: "BEST",  value: monthBestDay  > 0 ? "+$\(Int(monthBestDay))"       : "—", color: Color(red: 0.35, green: 0.85, blue: 0.55))
            summaryCell(label: "WORST", value: monthWorstDay < 0 ? "-$\(Int(abs(monthWorstDay)))" : "—", color: Color(red: 0.95, green: 0.38, blue: 0.38))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Day Detail Sheet

    private func dayDetailSheet(for date: Date) -> some View {
        let pnl = dailyPnl[date]
        let trades = allTrades.filter {
            guard let closed = $0.dateClosed else { return false }
            return cal.startOfDay(for: closed) == date
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Date + P&L hero
                VStack(alignment: .leading, spacing: 6) {
                    Text(date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let pnl {
                        Text(pnl >= 0 ? "+$\(String(format: "%.2f", pnl))" : "-$\(String(format: "%.2f", abs(pnl)))")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(pnl >= 0 ? Color(red: 0.35, green: 0.85, blue: 0.55) : Color(red: 0.95, green: 0.38, blue: 0.38))
                            .stealthable()
                    }
                }

                if !trades.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    VStack(spacing: 12) {
                        ForEach(trades) { trade in
                            HStack(spacing: 10) {
                                Text(trade.ticker)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))

                                Text(trade.side == .long ? "LONG" : "SHORT")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(trade.side == .long ? .green : .red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background((trade.side == .long ? Color.green : Color.red).opacity(0.12))
                                    .clipShape(Capsule())

                                if let strat = trade.strategy {
                                    Text(strat)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let tradePnl = engine.tradeAccounting[trade.id]?.totalPnl {
                                    Text(tradePnl >= 0 ? "+$\(String(format: "%.2f", tradePnl))" : "-$\(String(format: "%.2f", abs(tradePnl)))")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(tradePnl >= 0 ? Color(red: 0.35, green: 0.85, blue: 0.55) : Color(red: 0.95, green: 0.38, blue: 0.38))
                                        .stealthable()
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
