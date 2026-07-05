// PushTests/PlansViewModelTests.swift
import XCTest
@testable import Push

final class PlansViewModelTests: XCTestCase {

    func testSortedPlans_pendingBeforeJoined() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "1 in", locationHint: "here", status: .joined, isOwner: false),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "1 in", locationHint: "here", status: .pending, isOwner: false)
        ]
        let vm = PlansViewModel(plans: plans)
        XCTAssertEqual(vm.sortedPlans.first?.id, "b")
        XCTAssertEqual(vm.sortedPlans.last?.id, "a")
    }

    func testSortedPlans_openBeforeJoined() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .joined, isOwner: false),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .open, isOwner: false)
        ]
        let vm = PlansViewModel(plans: plans)
        XCTAssertEqual(vm.sortedPlans.first?.id, "b")
    }

    func testPlansNeedingResponse_includesPendingAndOpen() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .pending, isOwner: false),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .joined, isOwner: false),
            PlanData(id: "c", title: "C", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .open, isOwner: false)
        ]
        let vm = PlansViewModel(plans: plans)
        let ids = vm.plansNeedingResponse.map(\.id)
        XCTAssertTrue(ids.contains("a"))
        XCTAssertFalse(ids.contains("b"))
        XCTAssertTrue(ids.contains("c"))
    }

    func testNeedsResponseCount_matchesPendingAndOpen() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .pending, isOwner: false),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .open, isOwner: false),
            PlanData(id: "c", title: "C", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .joined, isOwner: false)
        ]
        let vm = PlansViewModel(plans: plans)
        XCTAssertEqual(vm.needsResponseCount, 2)
    }

    func testActiveCount_matchesInvitedPlans() {
        let vm = PlansViewModel(plans: PlansMockData.plans)
        let expectedCount = PlansMockData.plans.filter { !$0.isOwner }.count
        XCTAssertEqual(vm.activeCount, expectedCount)
    }

    func testRespond_rightSwipe_setsJoined() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending, isOwner: false)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .right)
        XCTAssertEqual(vm.plans.first?.status, .joined)
    }

    func testRespond_leftSwipe_setsWaiting() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending, isOwner: false)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .left)
        XCTAssertEqual(vm.plans.first?.status, .waiting)
    }

    func testRespond_upSwipe_setsOpen() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending, isOwner: false)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .up)
        XCTAssertEqual(vm.plans.first?.status, .open)
    }

    func testRespond_unknownPlan_doesNotCrash() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending, isOwner: false)
        let other = PlanData(id: "y", title: "Y", group: "G", timeSignal: "now",
                             socialProof: "", locationHint: "", status: .pending, isOwner: false)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: other, with: .right)
        XCTAssertEqual(vm.plans.first?.status, .pending)
    }

    func testMonthLabel_matchesCurrentMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let vm = PlansViewModel()
        XCTAssertEqual(vm.monthLabel, formatter.string(from: Date()))
    }

    func testCalendarDays_countMatchesDaysInMonth() throws {
        let components = DateComponents(year: 2026, month: 7, day: 1)
        let july = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: july)
        XCTAssertEqual(vm.calendarDays.count, 31)
    }

    func testTotalPushesThisMonth_sumsPushCounts() throws {
        let components = DateComponents(year: 2026, month: 7, day: 1)
        let july = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: july)
        let expected = vm.calendarDays.reduce(0) { $0 + $1.pushCount }
        XCTAssertEqual(vm.totalPushesThisMonth, expected)
    }

    func testYourPushes_ownedPlansHaveParticipants() {
        let vm = PlansViewModel(plans: PlansMockData.plans)
        let gymPush = vm.yourPushes.first { $0.id == "gym-later" }
        let drinksPush = vm.yourPushes.first { $0.id == "drinks-friday" }
        XCTAssertEqual(gymPush?.participants.count, 4)
        XCTAssertEqual(drinksPush?.participants.count, 2)
    }

    func testManagedPlan_defaultsNil() {
        let vm = PlansViewModel()
        XCTAssertNil(vm.managedPlan)
    }
}
