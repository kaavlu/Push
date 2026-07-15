// PushTests/PushTimingFormatterTests.swift
import XCTest
@testable import Push

final class PushTimingFormatterTests: XCTestCase {
    private func plan(
        startsAt: Date,
        hasExplicitTime: Bool = true,
        isApproximateTime: Bool = false,
        state: PushPlan.State = .collecting
    ) -> PushPlan {
        PushPlan(
            id: "p1", title: "Test push", groupID: nil, creatorID: "me",
            createdAt: startsAt, updatedAt: startsAt, startsAt: startsAt,
            hasExplicitTime: hasExplicitTime, isApproximateTime: isApproximateTime,
            expiresAt: startsAt.addingTimeInterval(3600), cancelledAt: nil,
            placeID: nil, placeIsSuggested: false, state: state,
            audience: .inviteesOnly, note: nil, locationText: nil
        )
    }

    /// Regression guard: a live push created a few minutes after its
    /// scheduled `startsAt` (e.g. one created at 5:09 PM for a 5:00 PM start)
    /// must still show its real time, not collapse to "now" just because the
    /// clock has passed it. Only an actually-`.happening` push says "now".
    func testPastStartTimeStillShowsFormattedTimeWhenNotHappening() {
        let now = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 17, minute: 9)
        )!
        let startsAt = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 17, minute: 0)
        )!
        let label = PushTimingFormatter.label(for: plan(startsAt: startsAt, state: .collecting), now: now)
        XCTAssertEqual(label, "5:00 PM")
    }

    func testHappeningStateAlwaysShowsNowRegardlessOfStartTime() {
        let now = Date()
        let futureStart = now.addingTimeInterval(600)
        let label = PushTimingFormatter.label(for: plan(startsAt: futureStart, state: .happening), now: now)
        XCTAssertEqual(label, "now")
    }

    func testFutureStartTimeShowsFormattedTimeWhenCollecting() {
        let now = Date()
        let futureStart = now.addingTimeInterval(3600)
        let label = PushTimingFormatter.label(for: plan(startsAt: futureStart, state: .collecting), now: now)
        XCTAssertNotEqual(label, "now")
    }
}
