// PushTests/PushLifecycleTests.swift
import XCTest
@testable import Push

final class PushLifecycleTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private var now: Date {
        date(year: 2026, month: 7, day: 15, hour: 18, minute: 0)
    }

    // MARK: - Active / historical

    func testActiveBeforeExpiry() {
        let plan = makePlan(
            startsAt: date(year: 2026, month: 7, day: 15, hour: 20, minute: 0),
            expiresAt: date(year: 2026, month: 7, day: 16, hour: 2, minute: 0)
        )
        XCTAssertTrue(PushLifecycle.isActive(plan, now: now))
        XCTAssertFalse(PushLifecycle.isHistorical(plan, now: now))
        XCTAssertFalse(PushLifecycle.isHappening(plan, now: now))
        XCTAssertEqual(PushLifecycle.phase(plan, now: now), .collecting)
    }

    func testHappeningAfterStartBeforeExpiry() {
        let plan = makePlan(
            startsAt: date(year: 2026, month: 7, day: 15, hour: 17, minute: 0),
            expiresAt: date(year: 2026, month: 7, day: 15, hour: 23, minute: 0)
        )
        XCTAssertTrue(PushLifecycle.isActive(plan, now: now))
        XCTAssertTrue(PushLifecycle.isHappening(plan, now: now))
        XCTAssertEqual(PushLifecycle.phase(plan, now: now), .happening)
    }

    func testHistoricalAtExpiryBoundary() {
        let expires = now
        let plan = makePlan(
            startsAt: date(year: 2026, month: 7, day: 15, hour: 12, minute: 0),
            expiresAt: expires
        )
        XCTAssertFalse(PushLifecycle.isActive(plan, now: now))
        XCTAssertTrue(PushLifecycle.isHistorical(plan, now: now))
        XCTAssertNil(PushLifecycle.phase(plan, now: now))
    }

    func testCancelledNeverActiveOrHistorical() {
        let plan = makePlan(
            startsAt: date(year: 2026, month: 7, day: 15, hour: 12, minute: 0),
            expiresAt: date(year: 2026, month: 7, day: 15, hour: 23, minute: 0),
            cancelledAt: date(year: 2026, month: 7, day: 15, hour: 10, minute: 0)
        )
        XCTAssertFalse(PushLifecycle.isActive(plan, now: now))
        XCTAssertFalse(PushLifecycle.isHistorical(plan, now: now))
        XCTAssertNil(PushLifecycle.phase(plan, now: now))
    }

    // MARK: - PastHangoutBuilder

    func testHangoutsMapsCompletedInRespondents() {
        let starts = date(year: 2026, month: 7, day: 10, hour: 19, minute: 0)
        let plan = makePlan(
            id: "push-1",
            title: "Dinner",
            startsAt: starts,
            expiresAt: date(year: 2026, month: 7, day: 11, hour: 1, minute: 0)
        )
        let responses = [
            response(pushID: "push-1", personID: "a", .in),
            response(pushID: "push-1", personID: "b", .maybe),
            response(pushID: "push-1", personID: "c", .out),
            response(pushID: "push-1", personID: "d", .pending)
        ]
        let hangouts = PastHangoutBuilder.hangouts(
            plans: [plan],
            responses: responses,
            monthContaining: now,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(hangouts.count, 1)
        XCTAssertEqual(hangouts[0].id, "push-1")
        XCTAssertEqual(hangouts[0].note, "Dinner")
        XCTAssertEqual(hangouts[0].participantIDs, ["a"])
        XCTAssertTrue(hangouts[0].cameFromPush)
        XCTAssertEqual(hangouts[0].timeRange, "7:00 PM")
    }

    func testHangoutsExcludesCancelledAndActiveAndOtherMonths() {
        let completed = makePlan(
            id: "done",
            startsAt: date(year: 2026, month: 7, day: 8, hour: 12, minute: 0),
            expiresAt: date(year: 2026, month: 7, day: 8, hour: 18, minute: 0)
        )
        let cancelled = makePlan(
            id: "cancel",
            startsAt: date(year: 2026, month: 7, day: 9, hour: 12, minute: 0),
            expiresAt: date(year: 2026, month: 7, day: 9, hour: 18, minute: 0),
            cancelledAt: date(year: 2026, month: 7, day: 9, hour: 11, minute: 0)
        )
        let active = makePlan(
            id: "live",
            startsAt: date(year: 2026, month: 7, day: 15, hour: 20, minute: 0),
            expiresAt: date(year: 2026, month: 7, day: 16, hour: 2, minute: 0)
        )
        let otherMonth = makePlan(
            id: "june",
            startsAt: date(year: 2026, month: 6, day: 20, hour: 12, minute: 0),
            expiresAt: date(year: 2026, month: 6, day: 20, hour: 18, minute: 0)
        )
        let hangouts = PastHangoutBuilder.hangouts(
            plans: [completed, cancelled, active, otherMonth],
            responses: [response(pushID: "done", personID: "a", .in)],
            monthContaining: now,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(hangouts.map(\.id), ["done"])
    }

    // MARK: - Helpers

    private func makePlan(
        id: String = "p1",
        title: String = "Test",
        startsAt: Date,
        expiresAt: Date,
        cancelledAt: Date? = nil
    ) -> PushPlan {
        PushPlan(
            id: id,
            title: title,
            groupID: nil,
            creatorID: "creator",
            createdAt: startsAt,
            updatedAt: startsAt,
            startsAt: startsAt,
            hasExplicitTime: true,
            isApproximateTime: false,
            expiresAt: expiresAt,
            cancelledAt: cancelledAt,
            placeID: nil,
            placeIsSuggested: false,
            state: .collecting,
            audience: .inviteesOnly,
            note: nil,
            locationText: nil
        )
    }

    private func response(
        pushID: String,
        personID: String,
        _ value: PushResponse.Response
    ) -> PushResponse {
        PushResponse(
            id: "\(pushID)-\(personID)",
            pushID: pushID,
            personID: personID,
            response: value,
            respondedAt: now,
            readyState: .unknown
        )
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
        )!
    }
}
