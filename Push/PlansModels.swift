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

struct HangoutPerson: Identifiable {
    let id: String
    let name: String
    let imageAssetName: String
    let initials: String
}

struct DayHangoutEntry: Identifiable {
    let id: String
    let people: [HangoutPerson]
    let activityNote: String
    let duration: String
}

struct CalendarDayData: Identifiable {
    let id: String
    let date: Date
    let pushCount: Int
    let hadPlan: Bool
    let almostHappened: Bool
    let hangouts: [DayHangoutEntry]
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

    private static func person(_ firstName: String) -> HangoutPerson {
        HangoutPerson(
            id: firstName,
            name: firstName.prefix(1).uppercased() + firstName.dropFirst(),
            imageAssetName: "assets/friends/\(firstName).png",
            initials: String(firstName.prefix(2)).uppercased()
        )
    }

    private static let hangoutPatterns: [Int: [DayHangoutEntry]] = [
        3: [
            DayHangoutEntry(id: "3-0", people: [person("chitty"), person("ishan")],
                            activityNote: "Coffee run downtown", duration: "10:00am–11:30am"),
            DayHangoutEntry(id: "3-1", people: [person("viplove")],
                            activityNote: "Gym session", duration: "6:00pm–7:30pm")
        ],
        5: [
            DayHangoutEntry(id: "5-0", people: [person("chitty")],
                            activityNote: "Pre-dinner drinks", duration: "5:30pm–7:00pm"),
            DayHangoutEntry(id: "5-1", people: [person("ram"), person("ohm"), person("rohan")],
                            activityNote: "Dinner at North Park", duration: "7:00pm–9:30pm"),
            DayHangoutEntry(id: "5-2", people: [person("ishan"), person("nitin")],
                            activityNote: "After-dinner walk", duration: "9:30pm–10:30pm")
        ],
        6: [
            DayHangoutEntry(id: "6-0", people: [person("ohm")],
                            activityNote: "Coffee at Blue Bottle", duration: "11:00am–12:00pm")
        ],
        10: [
            DayHangoutEntry(id: "10-0", people: [person("pranay"), person("ryan")],
                            activityNote: "Morning gym session", duration: "7:00am–8:30am")
        ],
        11: [
            DayHangoutEntry(id: "11-0", people: [person("rohan"), person("ryan"), person("ram")],
                            activityNote: "Watched the game at Ram's", duration: "3:00pm–7:00pm"),
            DayHangoutEntry(id: "11-1", people: [person("roh")],
                            activityNote: "Late night drive", duration: "10:00pm–11:30pm")
        ],
        12: [
            DayHangoutEntry(id: "12-0", people: [person("chitty"), person("ishan"), person("viplove"), person("nitin")],
                            activityNote: "Pregame at Ishan's", duration: "7:00pm–9:00pm"),
            DayHangoutEntry(id: "12-1", people: [person("chitty"), person("ishan")],
                            activityNote: "Drinks in Little Italy", duration: "9:30pm–11:00pm"),
            DayHangoutEntry(id: "12-2", people: [person("viplove")],
                            activityNote: "Last stop, rooftop bar", duration: "11:30pm–1:00am")
        ],
        17: [
            DayHangoutEntry(id: "17-0", people: [person("roh"), person("pranay")],
                            activityNote: "Walked the promenade", duration: "4:00pm–6:00pm")
        ],
        18: [
            DayHangoutEntry(id: "18-0", people: [person("ram"), person("ohm"), person("pranay"), person("rohan")],
                            activityNote: "Poker night at Ram's", duration: "8:00pm–1:00am"),
            DayHangoutEntry(id: "18-1", people: [person("ryan")],
                            activityNote: "Came by after poker", duration: "11:00pm–12:00am")
        ],
        22: [
            DayHangoutEntry(id: "22-0", people: [person("chitty")],
                            activityNote: "Coffee catch-up", duration: "2:00pm–3:30pm")
        ],
        23: [
            DayHangoutEntry(id: "23-0", people: [person("ishan"), person("viplove")],
                            activityNote: "Brunch at the spot", duration: "11:00am–1:00pm"),
            DayHangoutEntry(id: "23-1", people: [person("rohan"), person("ryan"), person("pranay")],
                            activityNote: "Beach afternoon", duration: "2:00pm–6:00pm"),
            DayHangoutEntry(id: "23-2", people: [person("ram"), person("ohm")],
                            activityNote: "Dinner to end the day", duration: "7:30pm–9:30pm")
        ]
    ]

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
                almostHappened: pattern.almostHappened,
                hangouts: hangoutPatterns[day] ?? []
            )
        }
    }
}
