// Push/PlansViewModel.swift
import Foundation
import Combine

final class PlansViewModel: ObservableObject {
    @Published private(set) var plans: [PlanData]
    @Published private(set) var weekDays: [CalendarDayData]
    @Published private(set) var weekLabel: String
    @Published private(set) var totalPushesThisWeek: Int
    @Published private(set) var bestDayThisWeek: String?
    @Published private(set) var mostActiveGroup: String
    @Published var selectedDay: CalendarDayData?
    @Published var isReviewDeckPresented: Bool = false
    @Published var isStartPushPresented: Bool = false
    @Published var isYourPushesPresented: Bool = false
    @Published var managedPlan: PlanData? = nil
    private var referenceDate: Date

    init(plans: [PlanData] = PlansMockData.plans, referenceDate: Date = Date()) {
        self.plans = plans
        self.referenceDate = referenceDate
        let summary = Self.makeWeekSummary(for: referenceDate)
        self.weekDays = summary.days
        self.weekLabel = summary.label
        self.totalPushesThisWeek = summary.totalPushes
        self.bestDayThisWeek = summary.bestDay
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

    func openManage(plan: PlanData) {
        managedPlan = plan
    }

    func moveWeek(by offset: Int) {
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: offset * PlansWeekNavigationConstants.daysPerWeek,
            to: referenceDate
        ) else { return }
        referenceDate = newDate
        let summary = Self.makeWeekSummary(for: newDate)
        weekDays = summary.days
        weekLabel = summary.label
        totalPushesThisWeek = summary.totalPushes
        bestDayThisWeek = summary.bestDay
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

    private static func makeWeekSummary(
        for referenceDate: Date
    ) -> (days: [CalendarDayData], label: String, totalPushes: Int, bestDay: String?) {
        let days = PlansMockData.weekDays(for: referenceDate)
        return (
            days,
            makeWeekLabel(for: days, referenceDate: referenceDate),
            days.reduce(0) { $0 + $1.pushCount },
            makeBestDayLabel(for: days)
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
}
