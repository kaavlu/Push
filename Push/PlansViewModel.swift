// Push/PlansViewModel.swift
import CoreLocation
import Foundation
import Combine

@MainActor
final class PlansViewModel: ObservableObject {
    @Published private(set) var plans: [PlanData] = []
    @Published private(set) var weekDays: [CalendarDayData]
    @Published private(set) var weekLabel: String
    @Published private(set) var totalPushesThisWeek: Int
    @Published private(set) var bestDayThisWeek: String?
    @Published private(set) var mostActiveGroup: String = ""
    @Published private(set) var loadState: LoadState<[PlanData]> = .idle
    @Published var selectedDay: CalendarDayData?
    @Published var isReviewDeckPresented: Bool = false
    @Published var isStartPushPresented: Bool = false
    @Published var isYourPushesPresented: Bool = false
    @Published var managedPlan: PlanData? = nil
    @Published var reviewFocusPlan: PlanData? = nil

    private let container: AppDataContainer?
    private var referenceDate: Date
    private var monthDays: [CalendarDayData] = []
    // Holds the active store-change subscription; nil when container is absent.
    private var storeChangeSub: AnyCancellable?
    // Tracks the last revision we loaded so the subscription skips redundant reloads.
    private var lastSeenRevision = 0

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    init(container: AppDataContainer? = nil, referenceDate: Date = Date()) {
        let container = container ?? .shared
        self.container = container
        self.referenceDate = referenceDate
        let summary = Self.makeWeekSummary(from: [], for: referenceDate)
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
    init(plans: [PlanData], referenceDate: Date = Date()) {
        container = nil
        self.referenceDate = referenceDate
        self.plans = plans
        let summary = Self.makeWeekSummary(from: [], for: referenceDate)
        weekDays = summary.days
        weekLabel = summary.label
        totalPushesThisWeek = summary.totalPushes
        bestDayThisWeek = summary.bestDay
        loadState = .loaded(plans)
    }

    func load() async {
        guard let container else { return }
        if loadState.value == nil { loadState = .loading }
        do {
            let planList = try await container.pushes.activePlans()
            let responses = try await container.pushes.responses()
            let hangouts = try await container.pushes.pastHangouts(forMonthContaining: referenceDate)
            let places = try await container.pushes.allPlaces()
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
                now: Date(),
                userCoordinate: userCoordinate(
                    userID: user.id, statuses: statuses, placesByID: placesByID
                )
            )
            let days = PlansContentBuilder.calendarDays(
                hangouts: hangouts,
                peopleByID: peopleByID,
                month: referenceDate
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
            loadState = .failed(error)
        }
    }

    var yourPushes: [PlanData] {
        plans.filter { $0.isOwner }
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
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: offset * PlansWeekNavigationConstants.daysPerWeek,
            to: referenceDate
        ) else { return }
        referenceDate = newDate
        applyWeekSummary(from: monthDays)
    }

    func respond(to plan: PlanData, with direction: SwipeDirection) {
        guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let response: PushResponse.Response
        switch direction {
        case .right: response = .in
        case .left: response = .out
        case .up: response = .maybe
        }
        // Update the pill synchronously so the swipe feels instant, then
        // write through to the canonical response row.
        plans[idx].status = PlansContentBuilder.pill(for: response)
        if let container {
            Task {
                try? await container.pushes.setCurrentUserResponse(planID: plan.id, response: response)
            }
        }
    }

    /// Owner-only. Removes the card immediately so the cancel feels instant,
    /// then writes through to the canonical push row.
    func cancel(plan: PlanData) {
        plans.removeAll { $0.id == plan.id }
        if let container {
            Task {
                try? await container.pushes.cancelPush(planID: plan.id)
            }
        }
    }

    /// Owner-only. Hard-deletes the push (and its responses). Removes the
    /// card immediately, then writes through to the canonical push row.
    func delete(plan: PlanData) {
        plans.removeAll { $0.id == plan.id }
        if let container {
            Task {
                try? await container.pushes.deletePush(planID: plan.id)
            }
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
        let summary = Self.makeWeekSummary(from: days, for: referenceDate)
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

    private static func makeWeekSummary(
        from monthDays: [CalendarDayData],
        for referenceDate: Date
    ) -> (days: [CalendarDayData], label: String, totalPushes: Int, bestDay: String?) {
        let days = weekDays(from: monthDays, for: referenceDate)
        return (
            days,
            makeWeekLabel(for: days, referenceDate: referenceDate),
            days.reduce(0) { $0 + $1.pushCount },
            makeBestDayLabel(for: days)
        )
    }

    private static func weekDays(
        from monthDays: [CalendarDayData],
        for referenceDate: Date
    ) -> [CalendarDayData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + PlansWeekNavigationConstants.mondayOffsetAdjustment)
            % PlansWeekNavigationConstants.daysPerWeek
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) else {
            return []
        }

        return (0..<PlansWeekNavigationConstants.daysPerWeek).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return monthDays.first { calendar.isDate($0.date, inSameDayAs: date) }
                ?? emptyDay(for: date)
        }
    }

    private static func emptyDay(for date: Date) -> CalendarDayData {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return CalendarDayData(
            id: formatter.string(from: date),
            date: date,
            pushCount: 0,
            hadPlan: false,
            almostHappened: false,
            hangouts: []
        )
    }

    private static func makeBestDayLabel(for days: [CalendarDayData]) -> String? {
        guard let best = days.max(by: { $0.pushCount < $1.pushCount }), best.pushCount > 0 else {
            return nil
        }
        return formatted(best.date, as: "EEEE")
    }

    private static func makeWeekLabel(for days: [CalendarDayData], referenceDate: Date) -> String {
        guard let first = days.first?.date, let last = days.last?.date else {
            return formatted(referenceDate, as: "MMM d")
        }
        let calendar = Calendar.current
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
        let endFormat = sameMonth ? "d" : "MMM d"
        return "\(formatted(first, as: "MMM d")) – \(formatted(last, as: endFormat))"
    }

    private static func formatted(_ date: Date, as format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

private enum PlansWeekNavigationConstants {
    static let daysPerWeek = 7
    static let mondayOffsetAdjustment = 5
}
