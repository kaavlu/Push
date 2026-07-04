// Push/PlansViewModel.swift
import Foundation
import Combine

final class PlansViewModel: ObservableObject {
    @Published private(set) var plans: [PlanData]
    @Published private(set) var calendarDays: [CalendarDayData]
    @Published private(set) var monthLabel: String
    @Published private(set) var totalPushesThisMonth: Int
    @Published private(set) var mostActiveGroup: String
    @Published var selectedDay: CalendarDayData?
    @Published var isReviewDeckPresented: Bool = false
    @Published var isStartPushPresented: Bool = false
    @Published var isYourPushesPresented: Bool = false
    @Published var isManagePushPresented: Bool = false
    @Published var managedPlan: PlanData? = nil

    init(plans: [PlanData] = PlansMockData.plans, referenceDate: Date = Date()) {
        self.plans = plans
        let days = PlansMockData.calendarDays(for: referenceDate)
        self.calendarDays = days
        self.monthLabel = Self.makeMonthLabel(for: referenceDate)
        self.totalPushesThisMonth = days.reduce(0) { $0 + $1.pushCount }
        self.mostActiveGroup = PlansMockData.mostActiveGroup
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

    func respond(to plan: PlanData, with direction: SwipeDirection) {
        guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        switch direction {
        case .right: plans[idx].status = .joined
        case .left:  plans[idx].status = .waiting
        case .up:    plans[idx].status = .open
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
