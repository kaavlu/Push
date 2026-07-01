// Push/PlansModels.swift
import Foundation

struct PlanData: Identifiable {
    let id: String
    let title: String
    let group: String
    let timeSignal: String
    let socialProof: String
    let locationHint: String
    var status: PlanStatus
}

enum PlanStatus: String, Equatable {
    case pending, joined, open, waiting, locked, happening

    var pill: String { rawValue.capitalized }
}

struct CalendarDayData: Identifiable {
    let id: String
    let date: Date
    let pushCount: Int
    let hadPlan: Bool
    let almostHappened: Bool
}

enum SwipeDirection { case left, right, up }

enum PlansMockData {
    static let plans: [PlanData] = [
        PlanData(
            id: "food-tonight",
            title: "Food tonight?",
            group: "Michigan",
            timeSignal: "8:00 PM",
            socialProof: "3 in · 2 maybe",
            locationHint: "Suggested: North Park",
            status: .pending
        ),
        PlanData(
            id: "gym-later",
            title: "Gym later",
            group: "Exec",
            timeSignal: "around 7:45 PM",
            socialProof: "4 going",
            locationHint: "Crunch Fitness",
            status: .joined
        ),
        PlanData(
            id: "coffee",
            title: "Coffee?",
            group: "India",
            timeSignal: "now",
            socialProof: "Chitty is there · Ishan maybe",
            locationHint: "Blue Bottle",
            status: .open
        ),
        PlanData(
            id: "drinks-friday",
            title: "Drinks Friday?",
            group: "Michigan",
            timeSignal: "Friday, 9:00 PM",
            socialProof: "2 in · 1 maybe",
            locationHint: "Suggested: Little Italy",
            status: .pending
        ),
        PlanData(
            id: "poker-night",
            title: "Poker night",
            group: "Exec",
            timeSignal: "Saturday",
            socialProof: "Ram in · Ohm maybe",
            locationHint: "Ram's place",
            status: .waiting
        )
    ]

    static let mostActiveGroup: String = "Michigan"

    static func calendarDays(for month: Date) -> [CalendarDayData] {
        let calendar = Calendar.current
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            )
        else { return [] }

        let pushPattern: [Int: (pushCount: Int, hadPlan: Bool, almostHappened: Bool)] = [
            3:  (2, false, false),
            5:  (3, true,  false),
            6:  (1, false, false),
            10: (1, false, false),
            11: (2, true,  false),
            12: (3, true,  false),
            14: (0, false, true),
            17: (1, false, false),
            18: (2, false, false),
            22: (1, false, false),
            23: (3, true,  false),
            25: (0, false, true)
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        return range.compactMap { day -> CalendarDayData? in
            guard let date = calendar.date(
                byAdding: .day, value: day - 1, to: monthStart
            ) else { return nil }
            let pattern = pushPattern[day] ?? (pushCount: 0, hadPlan: false, almostHappened: false)
            return CalendarDayData(
                id: formatter.string(from: date),
                date: date,
                pushCount: pattern.pushCount,
                hadPlan: pattern.hadPlan,
                almostHappened: pattern.almostHappened
            )
        }
    }
}
