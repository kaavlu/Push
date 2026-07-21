//
//  PastHangoutBuilder.swift
//  Push
//
//  Derives calendar/history hangout rows from completed pushes + responses.
//  Cancelled and still-active pushes are never mapped.
//

import Foundation

enum PastHangoutBuilder {

    /// Completed non-cancelled pushes whose `startsAt` falls in `monthContaining`.
    static func hangouts(
        plans: [PushPlan],
        responses: [PushResponse],
        monthContaining month: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [PastHangout] {
        let responsesByPush = Dictionary(grouping: responses, by: \.pushID)
        return plans
            .filter { PushLifecycle.isHistorical($0, now: now) }
            .filter { calendar.isDate($0.startsAt, equalTo: month, toGranularity: .month) }
            .map { plan in
                hangout(for: plan, responses: responsesByPush[plan.id] ?? [], calendar: calendar)
            }
            .sorted { $0.date < $1.date }
    }

    private static func hangout(
        for plan: PushPlan,
        responses: [PushResponse],
        calendar: Calendar
    ) -> PastHangout {
        let participantIDs = responses
            .filter { $0.response == .in }
            .map(\.personID)
        return PastHangout(
            id: plan.id,
            date: calendar.startOfDay(for: plan.startsAt),
            participantIDs: participantIDs,
            note: plan.title,
            timeRange: timeRange(for: plan),
            cameFromPush: true,
            didHappen: true
        )
    }

    private static func timeRange(for plan: PushPlan) -> String {
        guard plan.hasExplicitTime else {
            return weekdayFormatter.string(from: plan.startsAt)
        }
        let time = timeFormatter.string(from: plan.startsAt)
        return plan.isApproximateTime ? "~\(time)" : time
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
