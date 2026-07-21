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

    func testRespond_rightSwipe_setsJoined() async {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        await vm.respond(to: plan, with: .right)
        XCTAssertEqual(vm.plans.first?.status, .joined)
    }

    func testRespond_leftSwipe_setsWaiting() async {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        await vm.respond(to: plan, with: .left)
        XCTAssertEqual(vm.plans.first?.status, .waiting)
    }

    func testRespond_upSwipe_setsOpen() async {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        await vm.respond(to: plan, with: .up)
        XCTAssertEqual(vm.plans.first?.status, .open)
    }

    func testRespond_unknownPlan_doesNotCrash() async {
        let plan = seamPlan("x", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        await vm.respond(to: seamPlan("y", status: .pending), with: .right)
        XCTAssertEqual(vm.plans.first?.status, .pending)
    }

    func testRespondFailure_rollsBackAndSetsActionError() async {
        let fake = ControllablePushRepository()
        fake.shouldFailWrite = true
        let plan = seamPlan("p1", status: .pending)
        let vm = PlansViewModel(plans: [plan], pushes: fake)
        await vm.respond(to: plan, with: .right)
        XCTAssertEqual(vm.plans.first?.status, .pending)
        XCTAssertEqual(vm.actionError?.message, "Couldn't update your response. Try again.")
        XCTAssertEqual(fake.setResponseCalls.count, 1)

        fake.shouldFailWrite = false
        await vm.retryLastAction()
        XCTAssertNil(vm.actionError)
        XCTAssertEqual(vm.plans.first?.status, .joined)
        XCTAssertEqual(fake.setResponseCalls.count, 2)
    }

    func testCancelFailure_restoresCard() async {
        let fake = ControllablePushRepository()
        fake.shouldFailWrite = true
        let plan = seamPlan("p1", status: .joined, isOwner: true)
        let vm = PlansViewModel(plans: [plan], pushes: fake)
        await vm.cancel(plan: plan)
        XCTAssertEqual(vm.plans.map(\.id), ["p1"])
        XCTAssertEqual(vm.actionError?.message, "Couldn't cancel this Push. Try again.")

        fake.shouldFailWrite = false
        await vm.retryLastAction()
        XCTAssertTrue(vm.plans.isEmpty)
        XCTAssertNil(vm.actionError)
    }

    func testDeleteFailure_restoresCard() async {
        let fake = ControllablePushRepository()
        fake.shouldFailWrite = true
        let plan = seamPlan("p1", status: .joined, isOwner: true)
        let vm = PlansViewModel(plans: [plan], pushes: fake)
        await vm.delete(plan: plan)
        XCTAssertEqual(vm.plans.map(\.id), ["p1"])
        XCTAssertEqual(vm.actionError?.message, "Couldn't delete this Push. Try again.")

        fake.shouldFailWrite = false
        await vm.retryLastAction()
        XCTAssertTrue(vm.plans.isEmpty)
        XCTAssertNil(vm.actionError)
    }

    func testWeekLabel_matchesReferenceWeek() throws {
        let components = DateComponents(year: 2026, month: 7, day: 5)
        let sunday = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: sunday)
        XCTAssertEqual(vm.weekLabel, "Jun 29 – Jul 5")
    }

    func testWeekDays_countMatchesDaysInWeek() throws {
        let components = DateComponents(year: 2026, month: 7, day: 1)
        let wednesday = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: wednesday)
        XCTAssertEqual(vm.weekDays.count, 7)
    }

    func testWeekDays_startOnMonday() throws {
        let components = DateComponents(year: 2026, month: 7, day: 1)
        let wednesday = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: wednesday)
        let weekday = Calendar.current.component(
            .weekday,
            from: try XCTUnwrap(vm.weekDays.first?.date)
        )
        XCTAssertEqual(weekday, 2)
    }

    func testTotalPushesThisWeek_sumsPushCounts() throws {
        let components = DateComponents(year: 2026, month: 7, day: 1)
        let wednesday = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: wednesday)
        let expected = vm.weekDays.reduce(0) { $0 + $1.pushCount }
        XCTAssertEqual(vm.totalPushesThisWeek, expected)
    }

    func testMoveWeek_updatesWeekData() throws {
        let components = DateComponents(year: 2026, month: 7, day: 1)
        let wednesday = try XCTUnwrap(Calendar.current.date(from: components))
        let vm = PlansViewModel(referenceDate: wednesday)
        vm.moveWeek(by: 1)
        XCTAssertEqual(vm.weekLabel, "Jul 6 – 12")
    }

    func testYourPushes_ownedPlansHaveParticipants() {
        let owned = PlanData(
            id: "gym-later",
            title: "Gym later",
            group: "Exec",
            timeSignal: "~7:45 PM",
            socialProof: "4 going",
            locationHint: "Crunch Fitness",
            status: .joined,
            isOwner: true,
            participants: [
                HangoutPerson(id: "chitty", name: "Chitty", imageAssetName: "", initials: "CH"),
                HangoutPerson(id: "ishan", name: "Ishan", imageAssetName: "", initials: "IS")
            ]
        )
        let vm = PlansViewModel(plans: [owned, seamPlan("food", status: .pending)])
        let gymPush = vm.yourPushes.first { $0.id == "gym-later" }
        XCTAssertEqual(gymPush?.participants.count, 2)
    }

    func testManagedPlan_defaultsNil() {
        let vm = PlansViewModel(plans: [])
        XCTAssertNil(vm.managedPlan)
    }

    func testEmptyStates_showForLoadedEmptyPlans() {
        let vm = PlansViewModel(plans: [])
        XCTAssertTrue(vm.showsYourPushesEmptyState)
        XCTAssertTrue(vm.showsActivePushesEmptyState)
    }

    func testEmptyStates_areScopedToTheirCorrespondingPlanArrays() {
        let ownedOnly = PlansViewModel(plans: [
            seamPlan("owned", status: .joined, isOwner: true)
        ])
        XCTAssertFalse(ownedOnly.showsYourPushesEmptyState)
        XCTAssertTrue(ownedOnly.showsActivePushesEmptyState)

        let invitedOnly = PlansViewModel(plans: [
            seamPlan("invited", status: .pending)
        ])
        XCTAssertTrue(invitedOnly.showsYourPushesEmptyState)
        XCTAssertFalse(invitedOnly.showsActivePushesEmptyState)
    }

    // MARK: - Seeded content through repositories

    private func julyDate(day: Int) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: day)))
    }

    private func loadedViewModel(referenceDate: Date? = nil) async throws -> PlansViewModel {
        let date: Date
        if let referenceDate {
            date = referenceDate
        } else {
            date = try julyDate(day: 6)
        }
        let container = AppDataContainer(seed: .standard(now: date), referenceDate: date)
        let vm = PlansViewModel(container: container, referenceDate: date)
        await vm.load()
        return vm
    }

    func testSeededPlansMatchTodayContent() async throws {
        let vm = try await loadedViewModel()
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

    func testWeekDerivesFromHangouts() async throws {
        let vm = try await loadedViewModel(referenceDate: julyDate(day: 12))
        XCTAssertEqual(vm.weekLabel, "Jul 6 – 12")
        XCTAssertEqual(vm.weekDays.count, 7)
        XCTAssertEqual(vm.totalPushesThisWeek, 7)
        XCTAssertEqual(vm.bestDayThisWeek, "Sunday")
        let sunday = vm.weekDays.last
        XCTAssertEqual(sunday?.pushCount, 3)
        XCTAssertEqual(sunday?.hangouts.count, 3)
    }

    /// Fixed July reference so hangouts land in the current week (seed days 6–12).
    func testPlansStandardSeedKeepsHistorySummary() async throws {
        let vm = try await loadedViewModel(referenceDate: julyDate(day: 12))
        XCTAssertTrue(vm.hasWeekHangoutSummary)
        XCTAssertTrue(vm.showsHistoryLink)
        XCTAssertEqual(vm.weekFooterPrimaryText, "\(vm.totalPushesThisWeek) Pushes this week")
        XCTAssertNotEqual(vm.weekFooterPrimaryText, EmptySurfaceCopy.calendarEmptyFooter)
        XCTAssertTrue(vm.showsMostActiveGroup)
        XCTAssertFalse(vm.mostActiveGroup.isEmpty)
        XCTAssertTrue(vm.showsBestDay)
        XCTAssertNotNil(vm.bestDayThisWeek)
    }

    // MARK: - Cross-screen refresh subscription

    @MainActor
    func test_plansViewModel_reloadsWhenPushCreated() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = PlansViewModel(container: container)
        // Drain the init's deferred load so the baseline reflects a settled state;
        // after this, only the store-change subscription can change vm.plans.
        try await Task.sleep(nanoseconds: 150_000_000)
        await vm.load()
        let before = vm.plans.count

        _ = try await container.pushes.createPush(PushDraft(
            title: "New hang",
            recipientIDs: ["friend_\(try await container.friends.friends()[0].id)"],
            startsAt: Date(), locationText: "", notes: "", creatorID: container.currentUserID
        ))
        // Let the subscription's reload Task run.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(vm.plans.count, before + 1)
        XCTAssertTrue(vm.plans.contains { $0.title == "New hang" })
    }

    func test_plansViewModel_reloadsWhenPushUpdated() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = PlansViewModel(container: container)
        try await Task.sleep(nanoseconds: 150_000_000)
        await vm.load()

        try await container.pushes.updatePush(planID: "gym-later", with: PushDraft(
            title: "Gym and smoothies",
            recipientIDs: ["group_exec"],
            startsAt: Date(),
            locationText: "Equinox",
            notes: "Meet downstairs",
            creatorID: container.currentUserID
        ))

        try await Task.sleep(nanoseconds: 200_000_000)
        let edited = try XCTUnwrap(vm.yourPushes.first { $0.id == "gym-later" })
        XCTAssertEqual(edited.title, "Gym and smoothies")
        XCTAssertEqual(edited.locationHint, "Equinox")
        XCTAssertEqual(edited.note, "Meet downstairs")
    }

    func testRespondWritesThroughToRepository() async throws {
        let date = try julyDate(day: 6)
        let container = AppDataContainer(seed: .standard(now: date), referenceDate: date)
        let vm = PlansViewModel(container: container, referenceDate: date)
        await vm.load()
        let pending = try XCTUnwrap(vm.plans.first { $0.id == "food-tonight" })

        await vm.respond(to: pending, with: .right)

        XCTAssertEqual(vm.plans.first { $0.id == "food-tonight" }?.status, .joined)
        let responses = try await container.pushes.responses()
        let mine = responses.first { $0.pushID == "food-tonight" && $0.personID == "manav" }
        XCTAssertEqual(mine?.response, .in)
    }
}

// MARK: - Test doubles

private enum PlansTestFailure: Error { case expected }

/// Minimal PushRepository that can fail writes for mutation rollback tests.
@MainActor
final class ControllablePushRepository: PushRepository {
    var shouldFailWrite = false
    var setResponseCalls: [(PushPlan.ID, PushResponse.Response)] = []

    func activePlans() async throws -> [PushPlan] { [] }
    func responses() async throws -> [PushResponse] { [] }
    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout] { [] }
    func allPlaces() async throws -> [Place] { [] }
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID { "new" }
    func updatePush(planID: PushPlan.ID, with draft: PushDraft) async throws {}

    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        setResponseCalls.append((planID, response))
        if shouldFailWrite { throw PlansTestFailure.expected }
    }

    func cancelPush(planID: PushPlan.ID) async throws {
        if shouldFailWrite { throw PlansTestFailure.expected }
    }

    func deletePush(planID: PushPlan.ID) async throws {
        if shouldFailWrite { throw PlansTestFailure.expected }
    }
}
