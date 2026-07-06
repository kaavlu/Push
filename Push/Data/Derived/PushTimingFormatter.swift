//
//  PushTimingFormatter.swift
//  Push
//
//  Derives casual timing copy ("now", "~7:45 PM", "Friday, 9:00 PM",
//  "Saturday") from a plan's startsAt instead of storing display strings.
//

import Foundation

enum PushTimingFormatter {

    static func label(for plan: PushPlan, now: Date = Date()) -> String {
        if plan.state == .happening || plan.startsAt <= now { return "now" }
        if !plan.hasExplicitTime { return weekday(from: plan.startsAt) }
        let time = timeOfDay(from: plan.startsAt)
        if Calendar.current.isDate(plan.startsAt, inSameDayAs: now) {
            return plan.isApproximateTime ? "~\(time)" : time
        }
        return "\(weekday(from: plan.startsAt)), \(time)"
    }

    private static func timeOfDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private static func weekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
