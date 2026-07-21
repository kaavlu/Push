// PushTests/PushTimingFormatterTests.swift
import XCTest
@testable import Push

final class PushTimingFormatterTests: XCTestCase {
    private func plan(
        startsAt: Date,
        expiresAt: Date? = nil,
        hasExplicitTime: Bool = true,
        isApproximateTime: Bool = false,
        state: PushPlan.State = .collecting
    ) -> PushPlan {
        PushPlan(
            id: "p1", title: "Test push", groupID: nil, creatorID: "me",
            createdAt: startsAt, updatedAt: startsAt, startsAt: startsAt,
            hasExplicitTime: hasExplicitTime, isApproximateTime: isApproximateTime,
            expiresAt: expiresAt ?? startsAt.addingTimeInterval(6 * 60 * 60),
            cancelledAt: nil,
            placeID: nil, placeIsSuggested: false, state: state,
            audience: .inviteesOnly, note: nil, locationText: nil
        )
    }

    /// Within the live window after start, timing collapses to "now" even if
    /// the stored `state` column still says collecting.
    func testDerivedHappeningShowsNowIgnoringStoredState() {
        let now = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 17, minute: 9)
        )!
        let startsAt = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 17, minute: 0)
        )!
        let label = PushTimingFormatter.label(
            for: plan(startsAt: startsAt, state: .collecting),
            now: now
        )
        XCTAssertEqual(label, "now")
    }

    /// Stored `.happening` must not force "now" before the start window.
    func testStoredHappeningBeforeStartShowsFormattedTime() {
        let now = Date()
        let futureStart = now.addingTimeInterval(600)
        let label = PushTimingFormatter.label(
            for: plan(startsAt: futureStart, state: .happening),
            now: now
        )
        XCTAssertNotEqual(label, "now")
    }

    func testFutureStartTimeShowsFormattedTimeWhenCollecting() {
        let now = Date()
        let futureStart = now.addingTimeInterval(3600)
        let label = PushTimingFormatter.label(
            for: plan(startsAt: futureStart, state: .collecting),
            now: now
        )
        XCTAssertNotEqual(label, "now")
    }

    /// After expiry the push is historical — show the scheduled time, not "now".
    func testExpiredPushShowsFormattedTime() {
        let now = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 23, minute: 0)
        )!
        let startsAt = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 17, minute: 0)
        )!
        let expiresAt = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 20, minute: 0)
        )!
        let label = PushTimingFormatter.label(
            for: plan(startsAt: startsAt, expiresAt: expiresAt, state: .happening),
            now: now
        )
        XCTAssertEqual(label, "5:00 PM")
    }
}
