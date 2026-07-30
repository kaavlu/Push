// Push/PlansViewModel.swift
import CoreLocation
import Foundation
import Combine

@MainActor
final class PlansViewModel: ObservableObject {
    @Published private(set) var plans: [PlanData] = []
    @Published private(set) var historyItems: [HistoryItemData] = []
    @Published private(set) var weekDays: [CalendarDayData]
    @Published private(set) var weekLabel: String
    @Published private(set) var totalPushesThisWeek: Int
    @Published private(set) var bestDayThisWeek: String?
    @Published private(set) var mostActiveGroup: String = ""
    @Published private(set) var loadState: LoadState<[PlanData]> = .idle
    @Published var selectedDay: CalendarDayData?
    @Published var isReviewDeckPresented: Bool = false
    @Published var isYourPushesPresented: Bool = false
    @Published var isHistoryPresented: Bool = false
    @Published var managedPlan: PlanData? = nil
    @Published var reviewFocusPlan: PlanData? = nil
    @Published private(set) var actionError: ActionErrorState?

    private let container: AppDataContainer?
    private let pushesOverride: PushRepository?
    private var referenceDate: Date
    private var monthDays: [CalendarDayData] = []
    // Holds the active store-change subscription; nil when container is absent.
    private var storeChangeSub: AnyCancellable?
    // Tracks the last revision we loaded so the subscription skips redundant reloads.
    private var lastSeenRevision = 0
    private var pendingMutation: PendingMutation?

    private var pushRepo: PushRepository? { pushesOverride ?? container?.pushes }

    private enum PendingMutation {
        case respond(planID: PlanData.ID, direction: SwipeDirection)
        case cancel(plan: PlanData, index: Int)
        case delete(plan: PlanData, index: Int)
    }

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    init(
        container: AppDataContainer? = nil,
        referenceDate: Date = Date(),
        pushes: PushRepository? = nil
    ) {
        let container = container ?? .shared
        self.container = container
        self.pushesOverride = pushes
        self.referenceDate = referenceDate
        let summary = PlansWeekSummary.make(from: [], for: referenceDate)
        weekDays = summary.days
        weekLabel = summary.label
        totalPushesThisWeek = summary.totalPushes
        bestDayThisWeek = summary.bestDay
        Task { await load() }
        // Subscribe after the initial load task so each real mutation triggers a reload.
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    /// Preview/test seam: serve injected cards without touching repositories.
    /// Optional `pushes` override drives mutation tests without a full container.
    init(plans: [PlanData], referenceDate: Date = Date(), pushes: PushRepository? = nil) {
        container = nil
        self.pushesOverride = pushes
        self.referenceDate = referenceDate
        self.plans = plans
        let summary = PlansWeekSummary.make(from: [], for: referenceDate)
        weekDays = summary.days
        weekLabel = summary.label
        totalPushesThisWeek = summary.totalPushes
        bestDayThisWeek = summary.bestDay
        loadState = .loaded(plans)
    }

    func dismissActionError() {
        actionError = nil
    }

    func retryLastAction() async {
        guard let pendingMutation else { return }
        switch pendingMutation {
        case .respond(let id, let direction):
            guard let plan = plans.first(where: { $0.id == id }) else { return }
            await respond(to: plan, with: direction)
        case .cancel(let plan, _):
            await cancel(plan: plan)
        case .delete(let plan, _):
            await delete(plan: plan)
        }
    }

    /// Pull-to-refresh: re-warm the live session snapshot, then reload cards.
    func refresh() async {
        try? await container?.refreshSession()
        await load()
    }

    func load() async {
        guard let container else { return }
        let hadLoadedContent = loadState.value != nil
        if loadState.value == nil { loadState = .loading }
        do {
            guard let pushRepo else { return }
            let now = Date()
            let planList = try await pushRepo.activePlans()
            let historicalPlans = try await pushRepo.historicalPlans(
                forMonthContaining: referenceDate
            )
            let responses = try await pushRepo.responses()
            let hangouts = try await pushRepo.pastHangouts(forMonthContaining: referenceDate)
            let places = try await pushRepo.allPlaces()
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let friendList = try await container.friends.friends()
            let statuses = try await container.friends.presenceStatuses()
            let user = try await container.friends.currentUser()

            let peopleByID = Dictionary(
                uniqueKeysWithValues: (friendList + [user]).map { ($0.id, $0) }
            )
            let groupsByID = Dictionary(uniqueKeysWithValues: groupList.map { ($0.id, $0) })
            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            let cards = PlansContentBuilder.planData(
                plans: planList,
                responses: responses,
                groupsByID: groupsByID,
                placesByID: placesByID,
                peopleByID: peopleByID,
                currentUserID: user.id,
                now: now,
                userCoordinate: userCoordinate(
                    userID: user.id, statuses: statuses, placesByID: placesByID
                )
            )
            let days = PlansContentBuilder.calendarDays(
                hangouts: hangouts,
                peopleByID: peopleByID,
                month: referenceDate
            )
            historyItems = HistoryContentBuilder.items(
                plans: historicalPlans,
                responses: responses,
                hangouts: hangouts,
                peopleByID: peopleByID,
                groupsByID: groupsByID,
                placesByID: placesByID,
                now: now
            )
            plans = cards
            monthDays = days
            applyWeekSummary(from: days)
            mostActiveGroup = PlansContentBuilder.mostActiveGroup(
                hangouts: hangouts,
                memberships: memberships,
                groupsByID: groupsByID,
                groupOrder: groupList.map(\.id)
            )
            loadState = .loaded(cards)
            // Stamp the revision so the subscription guard can detect duplicates.
            lastSeenRevision = container.storeRevision
        } catch {
            if !hadLoadedContent {
                loadState = .failed(error)
            }
        }
    }

    var yourPushes: [PlanData] {
        plans.filter { $0.isOwner }
    }

    var surfacePhase: SurfaceContentPhase {
        switch loadState {
        case .idle, .loading:
            return .loading
        case .failed:
            return .failed
        case .loaded:
            return .content
        }
    }

    var activePushes: [PlanData] {
        plans.filter { !$0.isOwner }.sorted { priority($0) < priority($1) }
    }

    var showsYourPushesEmptyState: Bool {
        loadState.value != nil && yourPushes.isEmpty
    }

    var showsActivePushesEmptyState: Bool {
        loadState.value != nil && activePushes.isEmpty
    }

    /// True when the visible week has hangouts or a push total.
    var hasWeekHangoutSummary: Bool {
        totalPushesThisWeek > 0 || weekDays.contains { !$0.hangouts.isEmpty }
    }

    /// Hide the dead History control when the week has no hangout story.
    var showsHistoryLink: Bool { hasWeekHangoutSummary }

    var weekFooterPrimaryText: String {
        hasWeekHangoutSummary
            ? "\(totalPushesThisWeek) Pushes this week"
            : EmptySurfaceCopy.calendarEmptyFooter
    }

    var showsMostActiveGroup: Bool {
        hasWeekHangoutSummary && !mostActiveGroup.isEmpty
    }

    var showsBestDay: Bool { bestDayThisWeek != nil }

    var activeCount: Int { activePushes.count }

    var needsResponseCount: Int { plansNeedingResponse.count }

    var plansNeedingResponse: [PlanData] {
        activePushes.filter { $0.status == .pending || $0.status == .open }
    }

    var sortedPlans: [PlanData] {
        plans.sorted { priority($0) < priority($1) }
    }

    func openManage(plan: PlanData) {
        managedPlan = plan
    }

    /// Opens the swipe deck focused on a single push so the user can change
    /// an existing response, bypassing the "needs response" queue.
    func openReview(plan: PlanData) {
        reviewFocusPlan = plan
    }

    func moveWeek(by offset: Int) {
        let calendar = Calendar.current
        guard let newDate = calendar.date(
            byAdding: .day,
            value: offset * PlansWeekSummary.daysPerWeek,
            to: referenceDate
        ) else { return }
        let monthChanged = !calendar.isDate(newDate, equalTo: referenceDate, toGranularity: .month)
        referenceDate = newDate
        if monthChanged {
            // Hangouts are month-scoped; reload so adjacent months are not empty/stale.
            Task { await load() }
        } else {
            applyWeekSummary(from: monthDays)
        }
    }

    func openHistory() {
        isHistoryPresented = true
    }

    func respond(to plan: PlanData, with direction: SwipeDirection) async {
        guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let previous = plans[idx].status
        let response: PushResponse.Response
        switch direction {
        case .right: response = .in
        case .left: response = .out
        case .up: response = .maybe
        }
        // Optimistic pill so the swipe feels instant; roll back if the write fails.
        plans[idx].status = PlansContentBuilder.pill(for: response)
        guard let pushRepo else { return }
        do {
            try await pushRepo.setCurrentUserResponse(planID: plan.id, response: response)
            actionError = nil
            pendingMutation = nil
            lastSeenRevision = container?.storeRevision ?? lastSeenRevision
        } catch {
            plans[idx].status = previous
            pendingMutation = .respond(planID: plan.id, direction: direction)
            actionError = ActionErrorState(message: PlansMutationCopy.respondFailed)
        }
    }

    /// Owner-only. Removes the card immediately so the cancel feels instant,
    /// then writes through to the canonical push row.
    func cancel(plan: PlanData) async {
        guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let snapshot = plans[idx]
        plans.remove(at: idx)
        guard let pushRepo else { return }
        do {
            try await pushRepo.cancelPush(planID: plan.id)
            actionError = nil
            pendingMutation = nil
            lastSeenRevision = container?.storeRevision ?? lastSeenRevision
        } catch {
            let insertAt = min(idx, plans.count)
            plans.insert(snapshot, at: insertAt)
            pendingMutation = .cancel(plan: snapshot, index: insertAt)
            actionError = ActionErrorState(message: PlansMutationCopy.cancelFailed)
        }
    }

    /// Owner-only. Hard-deletes the push (and its responses). Removes the
    /// card immediately, then writes through to the canonical push row.
    func delete(plan: PlanData) async {
        guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let snapshot = plans[idx]
        plans.remove(at: idx)
        guard let pushRepo else { return }
        do {
            try await pushRepo.deletePush(planID: plan.id)
            actionError = nil
            pendingMutation = nil
            lastSeenRevision = container?.storeRevision ?? lastSeenRevision
        } catch {
            let insertAt = min(idx, plans.count)
            plans.insert(snapshot, at: insertAt)
            pendingMutation = .delete(plan: snapshot, index: insertAt)
            actionError = ActionErrorState(message: PlansMutationCopy.deleteFailed)
        }
    }

    /// The user's own coordinate, resolved from their current presence place.
    /// Powers the "x mi away" distance shown on review cards.
    private func userCoordinate(
        userID: Person.ID,
        statuses: [PresenceStatus],
        placesByID: [Place.ID: Place]
    ) -> CLLocationCoordinate2D? {
        guard
            let placeID = statuses.first(where: { $0.personID == userID })?.placeID,
            let place = placesByID[placeID]
        else { return nil }
        return place.coordinate
    }

    private func applyWeekSummary(from days: [CalendarDayData]) {
        let summary = PlansWeekSummary.make(from: days, for: referenceDate)
        weekDays = summary.days
        weekLabel = summary.label
        totalPushesThisWeek = summary.totalPushes
        bestDayThisWeek = summary.bestDay
    }

    private func priority(_ plan: PlanData) -> Int {
        switch plan.status {
        case .pending:   return 0
        case .open:      return 1
        case .happening: return 2
        case .joined:    return 3
        case .locked:    return 4
        case .waiting:   return 5
        }
    }
}

private enum PlansMutationCopy {
    static let respondFailed = "Couldn't update your response. Try again."
    static let cancelFailed = "Couldn't cancel this Push. Try again."
    static let deleteFailed = "Couldn't delete this Push. Try again."
}
