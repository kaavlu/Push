# Plans Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Plans page for Push — a social activity calendar heatmap, current pushes module, and swipe review deck — replacing the current `CreatePlaceholderView` stub.

**Architecture:** Single `PlansViewModel` owns all state and is shared between `PlansView` and `ReviewPushesView`. Swipe gestures in the deck call `viewModel.respond(to:with:)` which mutates plan statuses; `PlansView` reacts automatically via `@Published`. The page is presented as a `fullScreenCover` from `ContentView`, following the same pattern as `GroupsView` and `ProfileView`.

**Tech Stack:** SwiftUI, MVVM, `@ObservedObject`, `DragGesture`, `fullScreenCover`, XCTest

## Global Constraints

- iOS 17+, SwiftUI only, no UIKit, no backend calls
- All files in `Push/` directory; test files in `PushTests/`
- Files ≤ 400 lines, functions ≤ 40 lines
- Named constants in layout enums only — no magic numbers
- Color palette: `PushColorPalette.Accent.sunbeam`, `PushColorPalette.Accent.walnut`, `PushControlColors.*` only
- Glass cards via `.pushGlassBackground(cornerRadius:)` — never raw `.background`
- Page background: `PushModalBackground()` — same as Groups and Profile
- Close button: `PushModalCloseButtonBar(accessibilityLabel:action:)` — top overlay
- `@testable import Push` in all test files; framework is `XCTest`
- Build verification command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build`
- Test build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator'`
- **Xcode project registration:** After creating each new Swift file, it must be added to the appropriate target in `Push.xcodeproj/project.pbxproj`. Use the `xcodeproj` Ruby gem (`gem install xcodeproj` if needed) or edit the pbxproj directly. Verify with xcodebuild build after each addition.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Push/PlansModels.swift` | Create | `PlanData`, `PlanStatus`, `CalendarDayData`, `SwipeDirection`, `PlansMockData` |
| `Push/PlansViewModel.swift` | Create | All `@Published` state, `respond(to:with:)`, derived computed properties |
| `Push/PlansStyle.swift` | Create | `PlansLayout` enum constants, `PlanStatusPill` component |
| `Push/ActivePlanCard.swift` | Create | Normalized plan card shared by `PlansView` and `ReviewPushesView` |
| `Push/PlansCalendarView.swift` | Create | Month heatmap grid, `CalendarDayCell`, day-detail sheet |
| `Push/PlansView.swift` | Create | Page shell, `CurrentPushesModule`, `StartPlanButton` |
| `Push/ReviewPushesView.swift` | Create | Full-screen swipe deck, drag gesture, empty state |
| `Push/ContentView.swift` | Modify | Wire `.plans` route to `PlansView()` |
| `PushTests/PlansViewModelTests.swift` | Create | Unit tests for ViewModel mutations, sorting, derived properties |

---

## Task 1: Data Models

**Files:**
- Create: `Push/PlansModels.swift`

**Interfaces:**
- Produces: `PlanData`, `PlanStatus`, `CalendarDayData`, `SwipeDirection`, `PlansMockData` — all consumed by Tasks 2–7

- [ ] **Step 1: Create `Push/PlansModels.swift`**

```swift
// Push/PlansModels.swift
import Foundation

struct PlanData: Identifiable {
    let id: String
    let title: String
    let group: String
    let timeSignal: String
    let socialProof: String
    let locationHint: String
    var status: PlanStatus
}

enum PlanStatus: String, Equatable {
    case pending, joined, open, waiting, locked, happening

    var pill: String { rawValue.capitalized }
}

struct CalendarDayData: Identifiable {
    let id: String
    let date: Date
    let pushCount: Int
    let hadPlan: Bool
    let almostHappened: Bool
}

enum SwipeDirection { case left, right, up }

enum PlansMockData {
    static let plans: [PlanData] = [
        PlanData(
            id: "food-tonight",
            title: "Food tonight?",
            group: "Michigan",
            timeSignal: "8:00 PM",
            socialProof: "3 in · 2 maybe",
            locationHint: "Suggested: North Park",
            status: .pending
        ),
        PlanData(
            id: "gym-later",
            title: "Gym later",
            group: "Exec",
            timeSignal: "around 7:45 PM",
            socialProof: "4 going",
            locationHint: "Crunch Fitness",
            status: .joined
        ),
        PlanData(
            id: "coffee",
            title: "Coffee?",
            group: "India",
            timeSignal: "now",
            socialProof: "Chitty is there · Ishan maybe",
            locationHint: "Blue Bottle",
            status: .open
        ),
        PlanData(
            id: "drinks-friday",
            title: "Drinks Friday?",
            group: "Michigan",
            timeSignal: "Friday, 9:00 PM",
            socialProof: "2 in · 1 maybe",
            locationHint: "Suggested: Little Italy",
            status: .pending
        ),
        PlanData(
            id: "poker-night",
            title: "Poker night",
            group: "Exec",
            timeSignal: "Saturday",
            socialProof: "Ram in · Ohm maybe",
            locationHint: "Ram's place",
            status: .waiting
        )
    ]

    static let mostActiveGroup: String = "Michigan"

    static func calendarDays(for month: Date) -> [CalendarDayData] {
        let calendar = Calendar.current
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            )
        else { return [] }

        let pushPattern: [Int: (pushCount: Int, hadPlan: Bool, almostHappened: Bool)] = [
            3:  (2, false, false),
            5:  (3, true,  false),
            6:  (1, false, false),
            10: (1, false, false),
            11: (2, true,  false),
            12: (3, true,  false),
            14: (0, false, true),
            17: (1, false, false),
            18: (2, false, false),
            22: (1, false, false),
            23: (3, true,  false),
            25: (0, false, true)
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        return range.compactMap { day -> CalendarDayData? in
            guard let date = calendar.date(
                byAdding: .day, value: day - 1, to: monthStart
            ) else { return nil }
            let pattern = pushPattern[day] ?? (pushCount: 0, hadPlan: false, almostHappened: false)
            return CalendarDayData(
                id: formatter.string(from: date),
                date: date,
                pushCount: pattern.pushCount,
                hadPlan: pattern.hadPlan,
                almostHappened: pattern.almostHappened
            )
        }
    }
}
```

- [ ] **Step 2: Add `PlansModels.swift` to the Push target in `Push.xcodeproj`**

Use the `xcodeproj` gem or edit `project.pbxproj` to register the file under the Push app target's Sources build phase.

- [ ] **Step 3: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/PlansModels.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add Plans data models and mock data"
```

---

## Task 2: ViewModel + Unit Tests

**Files:**
- Create: `Push/PlansViewModel.swift`
- Create: `PushTests/PlansViewModelTests.swift`

**Interfaces:**
- Consumes: `PlanData`, `PlanStatus`, `CalendarDayData`, `SwipeDirection`, `PlansMockData` from Task 1
- Produces: `PlansViewModel` — consumed by Tasks 5, 6, 7

- [ ] **Step 1: Create `Push/PlansViewModel.swift`**

```swift
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

    init(plans: [PlanData] = PlansMockData.plans, referenceDate: Date = Date()) {
        self.plans = plans
        let days = PlansMockData.calendarDays(for: referenceDate)
        self.calendarDays = days
        self.monthLabel = Self.makeMonthLabel(for: referenceDate)
        self.totalPushesThisMonth = days.reduce(0) { $0 + $1.pushCount }
        self.mostActiveGroup = PlansMockData.mostActiveGroup
    }

    var activeCount: Int { plans.count }

    var needsResponseCount: Int { plansNeedingResponse.count }

    var plansNeedingResponse: [PlanData] {
        sortedPlans.filter { $0.status == .pending || $0.status == .open }
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
```

- [ ] **Step 2: Create `PushTests/PlansViewModelTests.swift`**

```swift
// PushTests/PlansViewModelTests.swift
import XCTest
@testable import Push

final class PlansViewModelTests: XCTestCase {

    func testSortedPlans_pendingBeforeJoined() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "1 in", locationHint: "here", status: .joined),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "1 in", locationHint: "here", status: .pending)
        ]
        let vm = PlansViewModel(plans: plans)
        XCTAssertEqual(vm.sortedPlans.first?.id, "b")
        XCTAssertEqual(vm.sortedPlans.last?.id, "a")
    }

    func testSortedPlans_openBeforeJoined() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .joined),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .open)
        ]
        let vm = PlansViewModel(plans: plans)
        XCTAssertEqual(vm.sortedPlans.first?.id, "b")
    }

    func testPlansNeedingResponse_includesPendingAndOpen() {
        let plans = [
            PlanData(id: "a", title: "A", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .pending),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .joined),
            PlanData(id: "c", title: "C", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .open)
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
                     socialProof: "", locationHint: "", status: .pending),
            PlanData(id: "b", title: "B", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .open),
            PlanData(id: "c", title: "C", group: "G", timeSignal: "now",
                     socialProof: "", locationHint: "", status: .joined)
        ]
        let vm = PlansViewModel(plans: plans)
        XCTAssertEqual(vm.needsResponseCount, 2)
    }

    func testActiveCount_matchesTotalPlans() {
        let vm = PlansViewModel(plans: PlansMockData.plans)
        XCTAssertEqual(vm.activeCount, PlansMockData.plans.count)
    }

    func testRespond_rightSwipe_setsJoined() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .right)
        XCTAssertEqual(vm.plans.first?.status, .joined)
    }

    func testRespond_leftSwipe_setsWaiting() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .left)
        XCTAssertEqual(vm.plans.first?.status, .waiting)
    }

    func testRespond_upSwipe_setsOpen() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending)
        let vm = PlansViewModel(plans: [plan])
        vm.respond(to: plan, with: .up)
        XCTAssertEqual(vm.plans.first?.status, .open)
    }

    func testRespond_unknownPlan_doesNotCrash() {
        let plan = PlanData(id: "x", title: "X", group: "G", timeSignal: "now",
                            socialProof: "", locationHint: "", status: .pending)
        let other = PlanData(id: "y", title: "Y", group: "G", timeSignal: "now",
                             socialProof: "", locationHint: "", status: .pending)
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
}
```

- [ ] **Step 3: Add both files to their respective Xcode targets**

Add `Push/PlansViewModel.swift` to the Push app target and `PushTests/PlansViewModelTests.swift` to the PushTests target in `Push.xcodeproj`.

- [ ] **Step 4: Verify test build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  build-for-testing -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator'
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Push/PlansViewModel.swift PushTests/PlansViewModelTests.swift \
  Push.xcodeproj/project.pbxproj
git commit -m "feat: add PlansViewModel with unit tests"
```

---

## Task 3: Style + Status Pill

**Files:**
- Create: `Push/PlansStyle.swift`

**Interfaces:**
- Consumes: `PlanStatus` from Task 1; `PushColorPalette`, `PushControlColors` from `PushColorPalette.swift` / `PushGlassStyle.swift`
- Produces: `PlansLayout` enum, `PlanStatusPill` view — consumed by Tasks 4–7

- [ ] **Step 1: Create `Push/PlansStyle.swift`**

```swift
// Push/PlansStyle.swift
import SwiftUI

enum PlansLayout {
    static let horizontalPadding: CGFloat = 18
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 110
    static let sectionSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 26
    static let cardPadding: CGFloat = 18
    static let cardRowSpacing: CGFloat = 8
    static let calendarCornerRadius: CGFloat = 26
    static let calendarPadding: CGFloat = 18
    static let calendarCellSize: CGFloat = 30
    static let calendarCellSpacing: CGFloat = 4
    static let calendarHeaderSpacing: CGFloat = 12
    static let calendarFooterSpacing: CGFloat = 12
    static let dotEmptySize: CGFloat = 4
    static let dotSmallSize: CGFloat = 6
    static let dotMediumSize: CGFloat = 9
    static let dotLargeSize: CGFloat = 12
    static let dotRingStrokeWidth: CGFloat = 1.5
    static let dotRingPadding: CGFloat = 6
    static let statusPillHorizontalPadding: CGFloat = 10
    static let statusPillVerticalPadding: CGFloat = 5
    static let currentPushesSpacing: CGFloat = 12
    static let reviewAllButtonTopPadding: CGFloat = 4
    static let startPlanButtonHeight: CGFloat = 56
    static let startPlanButtonCornerRadius: CGFloat = 28
    static let startPlanButtonBottomPadding: CGFloat = 32
    static let startPlanButtonHorizontalPadding: CGFloat = 48
    static let headerTopPadding: CGFloat = 8
    static let deckCardPadding: CGFloat = 24
    static let swipeThreshold: CGFloat = 100
    static let swipeUpThreshold: CGFloat = -80
    static let swipeRotationDivisor: Double = 20.0
    static let deckHintsBottomPadding: CGFloat = 24
    static let deckRemainingLabelBottomPadding: CGFloat = 48
}

struct PlanStatusPill: View {
    let status: PlanStatus

    var body: some View {
        Text(status.pill)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, PlansLayout.statusPillHorizontalPadding)
            .padding(.vertical, PlansLayout.statusPillVerticalPadding)
            .background(Capsule().fill(backgroundColor))
    }

    private var foregroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.walnut
        case .joined:    return Color(red: 0.18, green: 0.48, blue: 0.28)
        case .open:      return PushControlColors.textSecondary
        case .waiting:   return PushControlColors.textTertiary
        case .locked:    return PushColorPalette.Accent.walnut
        case .happening: return PushColorPalette.Accent.walnut
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.sunbeam.opacity(0.7)
        case .joined:    return Color(red: 0.78, green: 0.94, blue: 0.84)
        case .open:      return PushColorPalette.Accent.walnut.opacity(0.10)
        case .waiting:   return PushColorPalette.Accent.walnut.opacity(0.06)
        case .locked:    return PushColorPalette.Accent.sunbeam
        case .happening: return PushColorPalette.Accent.sunbeam
        }
    }
}
```

- [ ] **Step 2: Add `PlansStyle.swift` to the Push target**

- [ ] **Step 3: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/PlansStyle.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add PlansLayout constants and PlanStatusPill"
```

---

## Task 4: Active Plan Card

**Files:**
- Create: `Push/ActivePlanCard.swift`

**Interfaces:**
- Consumes: `PlanData` (Task 1), `PlanStatusPill` (Task 3), `PlansLayout` (Task 3), `PushControlColors`, `.pushGlassBackground(cornerRadius:)`
- Produces: `ActivePlanCard` view — consumed by Tasks 6 and 7

- [ ] **Step 1: Create `Push/ActivePlanCard.swift`**

```swift
// Push/ActivePlanCard.swift
import SwiftUI

struct ActivePlanCard: View {
    let plan: PlanData

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing) {
            headerRow
            groupRow
            Divider()
                .background(PushColorPalette.Accent.walnut.opacity(0.12))
            socialProofRow
            locationRow
        }
        .padding(PlansLayout.cardPadding)
        .pushGlassBackground(cornerRadius: PlansLayout.cardCornerRadius)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
            Spacer(minLength: 8)
            PlanStatusPill(status: plan.status)
        }
    }

    private var groupRow: some View {
        Text("\(plan.group) · \(plan.timeSignal)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PushControlColors.textSecondary)
            .lineLimit(1)
    }

    private var socialProofRow: some View {
        Text(plan.socialProof)
            .font(.subheadline)
            .foregroundStyle(PushControlColors.textSecondary)
            .lineLimit(1)
    }

    private var locationRow: some View {
        Text(plan.locationHint)
            .font(.footnote.weight(.medium))
            .foregroundStyle(PushControlColors.textTertiary)
            .lineLimit(1)
    }
}
```

- [ ] **Step 2: Add `ActivePlanCard.swift` to the Push target**

- [ ] **Step 3: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/ActivePlanCard.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add ActivePlanCard normalized plan card"
```

---

## Task 5: Calendar Heatmap

**Files:**
- Create: `Push/PlansCalendarView.swift`

**Interfaces:**
- Consumes: `PlansViewModel` (Task 2), `CalendarDayData` (Task 1), `PlansLayout` (Task 3), `PushColorPalette`, `PushControlColors`, `.pushGlassBackground(cornerRadius:)`
- Produces: `PlansCalendarView` — consumed by Task 6

- [ ] **Step 1: Create `Push/PlansCalendarView.swift`**

```swift
// Push/PlansCalendarView.swift
import SwiftUI

struct PlansCalendarView: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            calendarHeader
                .padding(.bottom, PlansLayout.calendarHeaderSpacing)
            weekdayRow
                .padding(.bottom, 8)
            calendarGrid
            calendarFooter
                .padding(.top, PlansLayout.calendarFooterSpacing)
        }
        .padding(PlansLayout.calendarPadding)
        .pushGlassBackground(cornerRadius: PlansLayout.calendarCornerRadius)
        .sheet(item: $viewModel.selectedDay) { day in
            DayDetailSheet(day: day)
        }
    }

    private var calendarHeader: some View {
        HStack {
            Text(viewModel.monthLabel)
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Spacer()
            Button {
                // history stub — future issue
            } label: {
                Text("History ›")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: PlansLayout.calendarCellSpacing) {
            ForEach(CalendarConstants.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PushControlColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let weeks = groupedIntoWeeks(viewModel.calendarDays)
        return VStack(spacing: PlansLayout.calendarCellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: PlansLayout.calendarCellSpacing) {
                    ForEach(0..<7, id: \.self) { col in
                        if let day = week[col] {
                            CalendarDayCell(day: day) {
                                viewModel.selectedDay = day
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(
                                    width: PlansLayout.calendarCellSize,
                                    height: PlansLayout.calendarCellSize
                                )
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var calendarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.totalPushesThisMonth) Pushes this month")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
            Text("Most active: \(viewModel.mostActiveGroup)")
                .font(.footnote)
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private func groupedIntoWeeks(_ days: [CalendarDayData]) -> [[CalendarDayData?]] {
        guard let firstDate = days.first?.date else { return [] }
        let calendar = Calendar.current
        let weekdayOfFirst = calendar.component(.weekday, from: firstDate)
        // Monday-first: Mon=2→0, Tue=3→1, ... Sun=1→6
        let mondayOffset = (weekdayOfFirst + 5) % 7
        var slots: [CalendarDayData?] = Array(repeating: nil, count: mondayOffset)
        slots.append(contentsOf: days.map { Optional($0) })
        let remainder = slots.count % 7
        if remainder != 0 {
            slots.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return stride(from: 0, to: slots.count, by: 7).map {
            Array(slots[$0..<$0 + 7])
        }
    }
}

private enum CalendarConstants {
    static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
}

private struct CalendarDayCell: View {
    let day: CalendarDayData
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if day.almostHappened {
                    Circle()
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(0.4),
                            lineWidth: PlansLayout.dotRingStrokeWidth
                        )
                        .frame(width: PlansLayout.dotMediumSize, height: PlansLayout.dotMediumSize)
                } else {
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                    if day.hadPlan {
                        Circle()
                            .stroke(
                                PushColorPalette.Accent.walnut.opacity(0.6),
                                lineWidth: PlansLayout.dotRingStrokeWidth
                            )
                            .frame(
                                width: dotSize + PlansLayout.dotRingPadding,
                                height: dotSize + PlansLayout.dotRingPadding
                            )
                    }
                }
            }
            .frame(
                width: PlansLayout.calendarCellSize,
                height: PlansLayout.calendarCellSize
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dotSize: CGFloat {
        switch day.pushCount {
        case 0:  return PlansLayout.dotEmptySize
        case 1:  return PlansLayout.dotSmallSize
        case 2:  return PlansLayout.dotMediumSize
        default: return PlansLayout.dotLargeSize
        }
    }

    private var dotColor: Color {
        switch day.pushCount {
        case 0:  return PushColorPalette.Accent.walnut.opacity(0.15)
        case 1:  return PushColorPalette.Accent.walnut.opacity(0.45)
        case 2:  return PushColorPalette.Accent.walnut.opacity(0.70)
        default: return PushColorPalette.Accent.walnut
        }
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: day.date)), \(day.pushCount) pushes"
    }
}

private struct DayDetailSheet: View {
    let day: CalendarDayData

    private var dayHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(dayHeader)
                .font(.title3.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)

            if day.almostHappened {
                Text("Almost happened")
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textTertiary)
            } else if day.pushCount == 0 {
                Text("Nothing happened")
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textTertiary)
            } else {
                Text("\(day.pushCount) \(day.pushCount == 1 ? "Push" : "Pushes")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
            }

            Spacer()
        }
        .padding(24)
        .presentationDetents([.fraction(0.35)])
    }
}
```

- [ ] **Step 2: Add `PlansCalendarView.swift` to the Push target**

- [ ] **Step 3: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/PlansCalendarView.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add calendar heatmap view"
```

---

## Task 6: Plans Page

**Files:**
- Create: `Push/PlansView.swift`

**Interfaces:**
- Consumes: `PlansViewModel` (Task 2), `PlansCalendarView` (Task 5), `ActivePlanCard` (Task 4), `PlansLayout` (Task 3), `PushModalBackground`, `PushModalCloseButtonBar` from `ProfileStyle.swift`
- Produces: `PlansView` — consumed by Task 8 (ContentView wiring)

- [ ] **Step 1: Create `Push/PlansView.swift`**

```swift
// Push/PlansView.swift
import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlansViewModel

    init(viewModel: PlansViewModel = PlansViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PushModalBackground()
            scrollContent
            StartPlanButton()
                .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding)
                .padding(.bottom, PlansLayout.startPlanButtonBottomPadding)
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close plans") {
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $viewModel.isReviewDeckPresented) {
            ReviewPushesView(viewModel: viewModel)
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PlansLayout.sectionSpacing) {
                PlansPageHeader()
                PlansCalendarView(viewModel: viewModel)
                CurrentPushesModule(viewModel: viewModel)
            }
            .padding(.horizontal, PlansLayout.horizontalPadding)
            .padding(.top, PlansLayout.topPadding)
            .padding(.bottom, PlansLayout.bottomPadding)
        }
    }
}

private struct PlansPageHeader: View {
    var body: some View {
        Text("Plans")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.top, PlansLayout.headerTopPadding)
    }
}

private struct CurrentPushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.currentPushesSpacing) {
            summaryRow
            ForEach(previewPlans) { plan in
                ActivePlanCard(plan: plan)
            }
            if viewModel.activeCount > CurrentPushesConstants.previewLimit {
                reviewAllButton
            }
        }
    }

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Current Pushes")
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text("\(viewModel.activeCount) active · \(viewModel.needsResponseCount) need you")
                .font(.footnote)
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private var previewPlans: [PlanData] {
        Array(viewModel.sortedPlans.prefix(CurrentPushesConstants.previewLimit))
    }

    private var reviewAllButton: some View {
        Button {
            viewModel.isReviewDeckPresented = true
        } label: {
            Text("Review all \(viewModel.activeCount) →")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.top, PlansLayout.reviewAllButtonTopPadding)
    }
}

private enum CurrentPushesConstants {
    static let previewLimit = 2
}

private struct StartPlanButton: View {
    var body: some View {
        Button {
            // start plan flow — deferred to future issue
        } label: {
            Text("+ Start Plan")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .frame(maxWidth: .infinity)
                .frame(height: PlansLayout.startPlanButtonHeight)
                .background(
                    Capsule().fill(PushColorPalette.Accent.sunbeam)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a new plan")
    }
}
```

- [ ] **Step 2: Add `PlansView.swift` to the Push target**

- [ ] **Step 3: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/PlansView.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add Plans page with calendar and current pushes module"
```

---

## Task 7: Review Pushes Swipe Deck

**Files:**
- Create: `Push/ReviewPushesView.swift`

**Interfaces:**
- Consumes: `PlansViewModel` (Task 2) — including `plansNeedingResponse`, `respond(to:with:)`, `isReviewDeckPresented`; `ActivePlanCard` (Task 4); `PlansLayout` (Task 3); `SwipeDirection` (Task 1); `PushModalBackground`, `PushModalCloseButtonBar`, `PushControlColors`, `PushColorPalette`
- Produces: `ReviewPushesView` — consumed by `PlansView.fullScreenCover` (Task 6)

- [ ] **Step 1: Create `Push/ReviewPushesView.swift`**

```swift
// Push/ReviewPushesView.swift
import SwiftUI

struct ReviewPushesView: View {
    @ObservedObject var viewModel: PlansViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var deckIndex: Int = 0
    @State private var dragOffset: CGSize = .zero

    private var currentPlan: PlanData? {
        let plans = viewModel.plansNeedingResponse
        guard deckIndex < plans.count else { return nil }
        return plans[deckIndex]
    }

    var body: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 0) {
                reviewHeader
                    .padding(.top, PlansLayout.headerTopPadding)
                Spacer()
                cardOrEmptyState
                Spacer()
                if currentPlan != nil {
                    swipeHints
                        .padding(.bottom, PlansLayout.deckHintsBottomPadding)
                }
                remainingLabel
                    .padding(.bottom, PlansLayout.deckRemainingLabelBottomPadding)
            }
            .padding(.horizontal, PlansLayout.horizontalPadding)
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close review") {
                dismiss()
            }
        }
    }

    private var reviewHeader: some View {
        Text("Review Pushes")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cardOrEmptyState: some View {
        if let plan = currentPlan {
            ActivePlanCard(plan: plan)
                .padding(PlansLayout.deckCardPadding)
                .offset(dragOffset)
                .rotationEffect(
                    .degrees(Double(dragOffset.width) / PlansLayout.swipeRotationDivisor)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            handleSwipeEnd(value.translation, plan: plan)
                        }
                )
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.8),
                    value: dragOffset
                )
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("You're all caught up")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text("Check back later")
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private var swipeHints: some View {
        HStack {
            Text("← Pass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            Spacer()
            Text("Maybe ↑")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Spacer()
            Text("Join →")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushColorPalette.Accent.walnut)
        }
    }

    private var remainingLabel: some View {
        let remaining = max(0, viewModel.plansNeedingResponse.count - deckIndex)
        return Text(remaining > 0 ? "\(remaining) left" : "")
            .font(.caption)
            .foregroundStyle(PushControlColors.textTertiary)
    }

    private func handleSwipeEnd(_ translation: CGSize, plan: PlanData) {
        if translation.width > PlansLayout.swipeThreshold {
            commit(plan: plan, direction: .right)
        } else if translation.width < -PlansLayout.swipeThreshold {
            commit(plan: plan, direction: .left)
        } else if translation.height < PlansLayout.swipeUpThreshold {
            commit(plan: plan, direction: .up)
        } else {
            dragOffset = .zero
        }
    }

    private func commit(plan: PlanData, direction: SwipeDirection) {
        viewModel.respond(to: plan, with: direction)
        deckIndex += 1
        dragOffset = .zero
    }
}
```

- [ ] **Step 2: Add `ReviewPushesView.swift` to the Push target**

- [ ] **Step 3: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/ReviewPushesView.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add ReviewPushesView swipe deck"
```

---

## Task 8: Wire ContentView

**Files:**
- Modify: `Push/ContentView.swift` — line 141–146 (`case .plans:` branch in `destination(for:)`)

**Interfaces:**
- Consumes: `PlansView` (Task 6)
- Produces: Plans page is reachable from the bottom nav and all existing routes still work

- [ ] **Step 1: Replace the `.plans` placeholder in `ContentView.swift`**

Find this block in `ContentView.swift` (around line 141):

```swift
case .plans:
    CreatePlaceholderView(
        title: "Plans",
        subtitle: "Shared plans with your people.",
        symbolName: route.systemImageName
    )
```

Replace it with:

```swift
case .plans:
    PlansView()
```

- [ ] **Step 2: Verify final build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Verify test build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  build-for-testing -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator'
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Push/ContentView.swift
git commit -m "feat: wire Plans page into ContentView (issue #5)"
```
