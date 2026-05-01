//
//  CalendarView.swift
//  Memoria

import SwiftUI
import SwiftData

struct CalendarView: View {
    let portfolio: Portfolio

    @Query private var allTrades: [Trade]
    @Query private var capitalEvents: [CapitalEvent]
    @State private var engine = AccountingEngine.shared
    @State private var selectedDay: Date? = nil
    @State private var displayMonth: Date = Date()

    init(portfolio: Portfolio) {
        self.portfolio = portfolio
        let id = portfolio.id
        _allTrades = Query(
            filter: #Predicate<Trade> { $0.portfolio?.id == id },
            sort: \Trade.dateAdded,
            order: .forward
        )
        _capitalEvents = Query(filter: #Predicate<CapitalEvent> { $0.portfolio?.id == id })
    }

    // MARK: - Derived

    private let cal = Calendar.current
    private var dailyPnl: [Date: Double] { engine.portfolioState.dailyPnl }

    private var greenDays: Int { dailyPnl.values.filter { $0 > 0 }.count }
    private var redDays:   Int { dailyPnl.values.filter { $0 < 0 }.count }
    private var bestDay:  Double { dailyPnl.values.max() ?? 0 }
    private var worstDay: Double { dailyPnl.values.min() ?? 0 }
    private var maxAbsPnl: Double { max(dailyPnl.values.map { abs($0) }.max() ?? 1, 1) }

    private func monthStart(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var monthDays: [Date?] {
        let start = monthStart(displayMonth)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let weekday = cal.component(.weekday, from: start)
        let offset = weekday == 1 ? 6 : weekday - 2
        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in range {
            days.append(cal.date(byAdding: .day, value: i - 1, to: start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func cellBackground(for date: Date) -> Color {
        guard let pnl = dailyPnl[date], pnl != 0 else { return .clear }
        let intensity = 0.15 + (abs(pnl) / maxAbsPnl) * 0.5
        return (pnl > 0 ? Color.green : Color.red).opacity(intensity)
    }

    private var canGoForward: Bool {
        monthStart(displayMonth) < monthStart(Date())
    }

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
                        description: Text("Close a trade to see your trading calendar.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            monthCard
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
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        }
        .onChange(of: allTrades) { _, newValue in
            engine.update(trades: newValue, startingBalance: portfolio.startingBalance, capitalEvents: capitalEvents)
        }
        .onChange(of: capitalEvents) { _, newValue in
            engine.update(trades: allTrades, startingBalance: portfolio.startingBalance, capitalEvents: newValue)
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

    // MARK: - Month Card

    private var monthCard: some View {
        VStack(spacing: 10) {
            // Navigation header
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
            .padding(.horizontal, 4)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(minHeight: 52)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal)
    }

    private func dayCell(for date: Date) -> some View {
        let pnl = dailyPnl[date]
        let isSelected = selectedDay == date
        let isToday = cal.isDateInToday(date)

        return Button {
            guard pnl != nil else { return }
            withAnimation(.spring(response: 0.25)) {
                selectedDay = selectedDay == date ? nil : date
            }
        } label: {
            VStack(alignment: .center, spacing: 3) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isToday ? Color(red: 0.92, green: 0.81, blue: 0.42) : .secondary)

                if let pnl {
                    Text(pnl >= 0 ? "+\(Int(pnl))" : "\(Int(pnl))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.vertical, 5)
            .background(cellBackground(for: date))
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.04), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
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
