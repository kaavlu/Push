//
//  RelativeTimeFormatter.swift
//  Push
//

import Foundation

enum RelativeTimeFormatter {
    /// Casual freshness labels matching the app's status language.
    static func label(for date: Date, now: Date = Date(), isCurrentUser: Bool = false) -> String {
        if isCurrentUser { return "Now" }
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "Just now" }
        return "\(minutes) min ago"
    }
}
