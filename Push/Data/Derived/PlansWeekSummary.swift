//
//  PlansWeekSummary.swift
//  Push
//
//  Monday-first week slice + labels for the Pushes calendar header.
//

import Foundation

enum PlansWeekSummary {
    static let daysPerWeek = 7
    private static let mondayOffsetAdjustment = 5

    static func make(
        from monthDays: [CalendarDayData],
        for referenceDate: Date
    ) -> (days: [CalendarDayData], label: String, totalPushes: Int, bestDay: String?) {
        let days = weekDays(from: monthDays, for: referenceDate)
        return (
            days,
            makeWeekLabel(for: days, referenceDate: referenceDate),
            days.reduce(0) { $0 + $1.pushCount },
            makeBestDayLabel(for: days)
        )
    }

    private static func weekDays(
        from monthDays: [CalendarDayData],
        for referenceDate: Date
    ) -> [CalendarDayData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + mondayOffsetAdjustment) % daysPerWeek
        guard let weekStart = calendar.date(
            byAdding: .day, value: -daysFromMonday, to: startOfDay
        ) else { return [] }

        return (0..<daysPerWeek).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return monthDays.first { calendar.isDate($0.date, inSameDayAs: date) }
                ?? emptyDay(for: date)
        }
    }

    private static func emptyDay(for date: Date) -> CalendarDayData {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return CalendarDayData(
            id: formatter.string(from: date),
            date: date,
            pushCount: 0,
            hadPlan: false,
            hangouts: []
        )
    }

    private static func makeBestDayLabel(for days: [CalendarDayData]) -> String? {
        guard let best = days.max(by: { $0.pushCount < $1.pushCount }), best.pushCount > 0 else {
            return nil
        }
        return formatted(best.date, as: "EEEE")
    }

    private static func makeWeekLabel(for days: [CalendarDayData], referenceDate: Date) -> String {
        guard let first = days.first?.date, let last = days.last?.date else {
            return formatted(referenceDate, as: "MMM d")
        }
        let calendar = Calendar.current
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
        let endFormat = sameMonth ? "d" : "MMM d"
        return "\(formatted(first, as: "MMM d")) – \(formatted(last, as: endFormat))"
    }

    private static func formatted(_ date: Date, as format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
