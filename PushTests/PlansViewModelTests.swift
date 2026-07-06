// PushTests/PlansViewModelTests.swift
import XCTest
@testable import Push

@MainActor
final class PlansViewModelTests: XCTestCase {

    private func seamPlan(_ id: String, status: PlanStatus, isOwner: Bool = false) -> PlanData {
        PlanData(
            id: id, title: id.capitalized, group: "G", timeSignal: "now",
            socialProof: "1 in", locationHint: "here", status: status, isOwner: isOwner
        )
    }

    // MARK: - Pure presentation logic (seam init, no repositories)

    func testSortedPlans_pendingBeforeJoined() {
        let vm = PlansViewModel(plans: [seamPlan("a", status: .joined), seamPlan("b", status: .pending)])
        XCTAssertEqual(vm.sortedPlans.first?.id, "b")
        XCTAssertEqual(vm.sortedPlans.last?.id, "a")
    }

    func testSortedPlans_openBeforeJoined() {
        let vm = PlansViewModel(plans: [seamPlan("a", status: .joined), seamPlan("b", status: .open)])
        XCTAssertEqual(vm.sortedPlans.first?.id, "b")
    }

    func testPlansNeedingResponse_includesPendingAndOpen() {
        let vm = PlansViewModel(plans: [
            seamPlan("a", status: .pending),
            seamPlan("b", status: .joined),
            seamPlan("c", status: .open)
        ])
        let ids = vm.plansNeedingResponse.map(\.id)
        XCTAssertTrue(ids.contains("a"))
        XCTAssertFalse(ids.contains("b"))
        XCTAssertTrue(ids.contains("c"))
        XCTAssertEqual(vm.needsResponseCount, 2)
    }

    func testRespond_rightSwipe_setsJoined() {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .right)
        XCTAssertEqual(vm.plans.first?.status, .joined)
    }

    func testRespond_leftSwipe_setsWaiting() {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .left)
        XCTAssertEqual(vm.plans.first?.status, .waiting)
    }

    func testRespond_upSwipe_setsOpen() {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .up)
        XCTAssertEqual(vm.plans.first?.status, .open)
    }

    func testRespond_unknownPlan_doesNotCrash() {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: seamPlan("y", status: .pending), with: .right)
        XCTAssertEqual(vm.plans.first?.status, .pending)
    }

    func testMonthLabel_matchesCurrentMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let vm = PlansViewModel(plans: [])
        XCTAssertEqual(vm.monthLabel, formatter.string(from: Date()))
    }

    func testManagedPlan_defaultsNil() {
        let vm = PlansViewModel(plans: [])
        XCTAssertNil(vm.managedPlan)
    }

    // MARK: - Seeded content through repositories

    private func loadedViewModel() async -> PlansViewModel {
        let vm = PlansViewModel(container: AppDataContainer(seed: .standard()))
        await vm.load()
        return vm
    }

    func testSeededPlansMatchTodayContent() async throws {
        let vm = await loadedViewModel()
        XCTAssertEqual(vm.plans.map(\.id), [
            "food-tonight", "gym-later", "coffee", "drinks-friday", "poker-night"
        ])
        XCTAssertEqual(vm.plans.map(\.status), [.pending, .joined, .open, .pending, .waiting])
        XCTAssertEqual(vm.plans.map(\.socialProof), [
            "3 in · 2 maybe",
            "4 going",
            "Chitty is there · Ishan maybe",
            "2 in · 1 maybe",
            "Ram in · Ohm maybe"
        ])
        XCTAssertEqual(vm.yourPushes.map(\.id), ["gym-later", "drinks-friday"])
        XCTAssertEqual(vm.yourPushes.first?.participants.count, 4)
        XCTAssertEqual(vm.mostActiveGroup, "Michigan")
        XCTAssertEqual(vm.activeCount, 3)
    }

    func testCalendarDerivesFromHangouts() async throws {
        let vm = await loadedViewModel()
        XCTAssertEqual(
            vm.calendarDays.count,
            Calendar.current.range(of: .day, in: .month, for: Date())?.count
        )
        XCTAssertEqual(vm.totalPushesThisMonth, 19)
        let day14 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 14 }
        XCTAssertEqual(day14?.almostHappened, true)
        XCTAssertEqual(day14?.hangouts.count, 0)
    }

    func testRespondWritesThroughToRepository() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = PlansViewModel(container: container)
        await vm.load()
        let pending = try XCTUnwrap(vm.plans.first { $0.id == "food-tonight" })

        vm.respond(to: pending, with: .right)

        XCTAssertEqual(vm.plans.first { $0.id == "food-tonight" }?.status, .joined)
        // Give the fire-and-forget write-through a beat to land.
        try await Task.sleep(nanoseconds: 100_000_000)
        let responses = try await container.pushes.responses()
        let mine = responses.first { $0.pushID == "food-tonight" && $0.personID == "manav" }
        XCTAssertEqual(mine?.response, .in)
    }
}
