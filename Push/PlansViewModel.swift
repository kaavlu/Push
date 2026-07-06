// Push/PlansViewModel.swift
import Foundation
import Combine

@MainActor
final class PlansViewModel: ObservableObject {
    @Published private(set) var plans: [PlanData] = []
    @Published private(set) var calendarDays: [CalendarDayData] = []
    @Published private(set) var monthLabel: String
    @Published private(set) var totalPushesThisMonth: Int = 0
    @Published private(set) var mostActiveGroup: String = ""
    @Published private(set) var loadState: LoadState<[PlanData]> = .idle
    @Published var selectedDay: CalendarDayData?
    @Published var isReviewDeckPresented: Bool = false
    @Published var isStartPushPresented: Bool = false
    @Published var isYourPushesPresented: Bool = false
    @Published var managedPlan: PlanData? = nil

    private let container: AppDataContainer?
    private let referenceDate: Date

    init(container: AppDataContainer = .shared, referenceDate: Date = Date()) {
        self.container = container
        self.referenceDate = referenceDate
        self.monthLabel = Self.makeMonthLabel(for: referenceDate)
        Task { await load() }
    }

    /// Preview/test seam: serve injected cards without touching repositories.
    init(plans: [PlanData], referenceDate: Date = Date()) {
        container = nil
        self.referenceDate = referenceDate
        self.plans = plans
        self.monthLabel = Self.makeMonthLabel(for: referenceDate)
        self.loadState = .loaded(plans)
    }

    func load() async {
        guard let container else { return }
        loadState = .loading
        do {
            let planList = try await container.pushes.activePlans()
            let responses = try await container.pushes.responses()
            let hangouts = try await container.pushes.pastHangouts(forMonthContaining: referenceDate)
            let places = try await container.pushes.allPlaces()
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let friendList = try await container.friends.friends()
            let user = try await container.friends.currentUser()

            let peopleByID = Dictionary(
                uniqueKeysWithValues: (friendList + [user]).map { ($0.id, $0) }
            )
            let groupsByID = Dictionary(uniqueKeysWithValues: groupList.map { ($0.id, $0) })
            let cards = PlansContentBuilder.planData(
                plans: planList,
                responses: responses,
                groupsByID: groupsByID,
                placesByID: Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) }),
                peopleByID: peopleByID,
                currentUserID: user.id,
                now: Date()
            )
            let days = PlansContentBuilder.calendarDays(
                hangouts: hangouts, peopleByID: peopleByID, month: referenceDate
            )
            plans = cards
            calendarDays = days
            totalPushesThisMonth = days.reduce(0) { $0 + $1.pushCount }
            mostActiveGroup = PlansContentBuilder.mostActiveGroup(
                hangouts: hangouts,
                memberships: memberships,
                groupsByID: groupsByID,
                groupOrder: groupList.map(\.id)
            )
            loadState = .loaded(cards)
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

    private static func makeMonthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
}
