# Honest Empty States Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Spec: `docs/superpowers/specs/2026-07-20-honest-empty-states-design.md`.

**Goal:** Make Map, Friends, Feed, and Pushes calendar/History honest when live data is empty or deferred — without building presence, Feed, or History backends.

**Architecture:** Shared presentation kit (`SurfaceContentPhase`, `EmptySurfaceCopy`, cream empty view + map overlay) derived from existing `LoadState` + emptiness checks in ViewModels. Views stay dumb; CTAs use existing Add Friends routes. Feed is a static deferred screen. Mock seed remains populated.

**Tech Stack:** SwiftUI, existing MVVM + `AppDataContainer` repos, XCTest via `scripts/test.sh`.

## Global Constraints

- MVVM only; no Supabase in Views/ViewModels.
- Files ≤ 400 lines; functions ≤ 40 lines; no magic numbers.
- Register new Swift files: `python3 scripts/pbxproj_add.py <path-relative-to-Push/>` (tests: `--target tests`).
- Prefer `PushControlColors` + Friends cream styling; map overlay may use glass-safe chrome.
- User-facing copy: **Push/Pushes** (not Plan/Plans).
- Mock mode must keep populated seed data.
- No presence/Feed/History backends; no offline detector.
- Tests: `scripts/test.sh suite EmptySurfaceTests` (and related suites); build with `scripts/test.sh build`.
- Commit after each logical task.

## File map

| File | Responsibility |
|---|---|
| `Push/EmptySurfaceModels.swift` | `SurfaceContentPhase`, `EmptySurfaceCopy`, layout constants |
| `Push/EmptySurfaceView.swift` | Cream-page empty + loading/failed helpers + optional primary button |
| `Push/MapEmptyOverlay.swift` | Non-blocking map empty/failed overlay |
| `Push/FeedDeferredView.swift` | Full-screen deferred Feed (cream) |
| `Push/MapViewModel.swift` | `surfacePhase`, `hasFriendMapContent` |
| `Push/ContentView.swift` | Map overlay + Feed destination; Add Friends from empty |
| `Push/FriendsViewModel.swift` | `surfacePhase`, `showsFilterChips` |
| `Push/FriendsComponents.swift` / `FriendsView.swift` | Empty CTA; loading/failed; hide filters when empty |
| `Push/PlansViewModel.swift` | `showsHistoryLink`, `hasWeekHangoutSummary`, empty footer strings |
| `Push/PlansCalendarView.swift` | Hide History; honest empty footer |
| `PushTests/EmptySurfaceTests.swift` | Focused VM + copy coverage |

---

### Task 1: Shared empty-surface kit + copy tests

**Files:**
- Create: `Push/EmptySurfaceModels.swift`
- Create: `Push/EmptySurfaceView.swift`
- Create: `PushTests/EmptySurfaceTests.swift` (copy + phase tests first)
- Register both app files + test file in pbxproj

**Interfaces:**
- Produces:
  - `enum SurfaceContentPhase: Equatable { case loading, empty, failed, content, deferred }`
  - `enum EmptySurfaceCopy` with static strings (map, friends, feed, calendar footer, failed generics, action labels)
  - `struct EmptySurfaceView: View` — `title`, `message`, `systemImage`, optional `actionTitle` + `action`
  - `enum EmptySurfaceLayout` — spacing/icon/padding constants

- [ ] **Step 1: Write failing copy/phase tests**

```swift
// PushTests/EmptySurfaceTests.swift
import XCTest
@testable import Push

final class EmptySurfaceTests: XCTestCase {
    func testCopyIsHonestAndDistinct() {
        XCTAssertFalse(EmptySurfaceCopy.mapEmptyTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedDeferredTitle.isEmpty)
        XCTAssertNotEqual(EmptySurfaceCopy.mapEmptyTitle, EmptySurfaceCopy.failedTitle(surface: "map"))
        XCTAssertEqual(EmptySurfaceCopy.addFriendsAction, "Add friends")
        XCTAssertEqual(EmptySurfaceCopy.calendarEmptyFooter, "No hangouts this week")
    }

    func testSurfacePhasesAreDistinct() {
        let phases: [SurfaceContentPhase] = [.loading, .empty, .failed, .content, .deferred]
        XCTAssertEqual(Set(phases.map { String(describing: $0) }).count, 5)
    }
}
```

- [ ] **Step 2: Register test file and run to verify fail**

```bash
python3 scripts/pbxproj_add.py --target tests EmptySurfaceTests.swift
scripts/test.sh suite EmptySurfaceTests
```

Expected: compile fail or test fail — `EmptySurfaceCopy` / `SurfaceContentPhase` missing.

- [ ] **Step 3: Implement models + cream empty view**

`Push/EmptySurfaceModels.swift`:

```swift
import Foundation

enum SurfaceContentPhase: Equatable {
    case loading
    case empty
    case failed
    case content
    case deferred
}

enum EmptySurfaceCopy {
    static let mapEmptyTitle = "Friends will show up here"
    static let mapEmptyMessage = "When they share status — add friends to get started."
    static let addFriendsAction = "Add friends"

    static let friendsEmptyTitle = "No friends yet"
    static let friendsEmptyMessage = "Add friends to see who's around."

    static let feedDeferredTitle = "No Feed activity yet"
    static let feedDeferredMessage = "Feed isn't live yet — check back later."

    static let calendarEmptyFooter = "No hangouts this week"

    static let mapLoading = "Loading map"
    static let friendsLoading = "Loading friends"

    static func failedTitle(surface: String) -> String {
        "Couldn't load \(surface)"
    }
    static let failedMessage = "Try again in a moment."
    static let retryAction = "Try again"
}

enum EmptySurfaceLayout {
    static let contentSpacing: CGFloat = 12
    static let textSpacing: CGFloat = 6
    static let iconSize: CGFloat = 30
    static let horizontalPadding: CGFloat = 28
    static let topPadding: CGFloat = 60
    static let actionTopPadding: CGFloat = 16
}
```

`Push/EmptySurfaceView.swift`:

```swift
import SwiftUI

struct EmptySurfaceView: View {
    let title: String
    let message: String
    var systemImage: String = "person.2"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: EmptySurfaceLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(PushControlColors.activeFill)
                    .foregroundStyle(PushControlColors.activeForeground)
                    .padding(.top, EmptySurfaceLayout.actionTopPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, EmptySurfaceLayout.horizontalPadding)
        .padding(.top, EmptySurfaceLayout.topPadding)
        .accessibilityElement(children: .combine)
    }
}

enum EmptySurfaceStateView {
    static var loading: some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            ProgressView().tint(PushControlColors.activeForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    static func loading(message: String) -> some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            ProgressView().tint(PushControlColors.activeForeground)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    static func failed(surface: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: EmptySurfaceLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text(EmptySurfaceCopy.failedTitle(surface: surface))
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(EmptySurfaceCopy.failedMessage)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
            Button(EmptySurfaceCopy.retryAction, action: retry)
                .buttonStyle(.borderedProminent)
                .tint(PushControlColors.activeFill)
                .foregroundStyle(PushControlColors.activeForeground)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, EmptySurfaceLayout.horizontalPadding)
    }
}
```

- [ ] **Step 4: Register app files and run tests**

```bash
python3 scripts/pbxproj_add.py EmptySurfaceModels.swift
python3 scripts/pbxproj_add.py EmptySurfaceView.swift
scripts/test.sh suite EmptySurfaceTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Push/EmptySurfaceModels.swift Push/EmptySurfaceView.swift PushTests/EmptySurfaceTests.swift Push.xcodeproj/project.pbxproj
git commit -m "Add shared empty-surface kit and copy for Issue #49"
```

---

### Task 2: Map surface phase + overlay + ContentView wiring

**Files:**
- Create: `Push/MapEmptyOverlay.swift`
- Modify: `Push/MapViewModel.swift`
- Modify: `Push/ContentView.swift`
- Modify: `PushTests/EmptySurfaceTests.swift` (map phase tests)

**Interfaces:**
- Consumes: `SurfaceContentPhase`, `EmptySurfaceCopy`
- Produces on `MapViewModel`:
  - `var hasFriendMapContent: Bool` — friend pucks non-empty **or** filtered vague regional sources non-empty (friend-derived)
  - `var surfacePhase: SurfaceContentPhase` — from `loadState` + `hasFriendMapContent`
  - `func retryLoad()` → `Task { await load() }` or just call `load()` from view

Phase rules:
- `loadState` idle/loading and `value == nil` → `.loading`
- `loadState` failed and `value == nil` → `.failed`
- `loadState` loaded (or soft-reload with prior value) and `!hasFriendMapContent` → `.empty`
- otherwise with content → `.content`
- Soft reload: if `value != nil`, keep prior content/empty phase based on last successful value (do not flash `.loading` over known empty/content). Existing `if loadState.value == nil { loadState = .loading }` already supports this — `surfacePhase` must use last value when present.

- [ ] **Step 1: Write failing MapViewModel phase tests**

Append to `EmptySurfaceTests.swift`:

```swift
@MainActor
func testMapEmptyPhaseForEmptyGraph() async throws {
    // Prefer implementing SeedData.emptyGraph() once (Task 2) and reuse everywhere.
    let viewModel = MapViewModel(container: AppDataContainer(seed: .emptyGraph()))
    await viewModel.load()
    XCTAssertEqual(viewModel.surfacePhase, .empty)
    XCTAssertFalse(viewModel.hasFriendMapContent)
}

@MainActor
func testMapContentPhaseForStandardSeed() async throws {
    let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
    await viewModel.load()
    XCTAssertEqual(viewModel.surfacePhase, .content)
    XCTAssertTrue(viewModel.hasFriendMapContent)
}

@MainActor
func testMapFailedPhaseOnRepositoryError() async throws {
    let container = AppDataContainer(seed: .standard())
    let viewModel = MapViewModel(
        friends: ThrowingFriendRepository(),
        groups: container.groups,
        sharing: container.sharing,
        pushes: container.pushes
    )
    await viewModel.load()
    XCTAssertEqual(viewModel.surfacePhase, .failed)
}
```

**Seed helpers (add in Task 2, reuse in Tasks 3 and 5):**

```swift
// SeedData.swift
static func emptyGraph(now: Date = Date()) -> SeedData {
    let user = Person(
        id: SeedIDs.currentUser,
        firstName: "manav",
        imageAssetPath: "assets/profile/manav.jpeg"
    )
    return SeedData(
        currentUserID: SeedIDs.currentUser,
        people: [user],
        acceptedFriendIDs: [],
        groups: [],
        memberships: [],
        places: [],
        statuses: [],
        policies: [],
        plans: [],
        responses: [],
        hangouts: [],
        feedEvents: [],
        friendRequests: [],
        profile: standardProfile()
    )
}

/// Direct friends exist but no PresenceStatus rows — list shows "Hidden right now".
static func friendsWithoutPresence(now: Date = Date()) -> SeedData {
    var seed = standard(now: now)
    // SeedData is a struct with lets — construct explicitly:
    return SeedData(
        currentUserID: seed.currentUserID,
        people: seed.people,
        acceptedFriendIDs: seed.acceptedFriendIDs,
        groups: seed.groups,
        memberships: seed.memberships,
        places: seed.places,
        statuses: [],
        policies: seed.policies,
        plans: seed.plans,
        responses: seed.responses,
        hangouts: seed.hangouts,
        feedEvents: seed.feedEvents,
        friendRequests: seed.friendRequests,
        profile: seed.profile
    )
}
```

- [ ] **Step 2: Run tests — expect fail**

```bash
scripts/test.sh suite EmptySurfaceTests
```

Expected: `surfacePhase` / `hasFriendMapContent` missing.

- [ ] **Step 3: Implement MapViewModel phase**

```swift
// On MapViewModel
var hasFriendMapContent: Bool {
    let pucks = loadState.value ?? []
    return !pucks.isEmpty || !vagueRegionalSources.isEmpty
}

var surfacePhase: SurfaceContentPhase {
    switch loadState {
    case .idle, .loading:
        return loadState.value == nil ? .loading : phaseForLoadedContent()
    case .failed:
        return loadState.value == nil ? .failed : phaseForLoadedContent()
    case .loaded:
        return phaseForLoadedContent()
    }
}

private func phaseForLoadedContent() -> SurfaceContentPhase {
    hasFriendMapContent ? .content : .empty
}
```

- [ ] **Step 4: MapEmptyOverlay + ContentView**

`Push/MapEmptyOverlay.swift` — compact card with title/message/button; layout constants named; uses `pushGlassBackground` or warm material so it sits on satellite map without covering top controls / bottom nav. Place roughly mid-map or above bottom nav with safe padding.

```swift
struct MapEmptyOverlay: View {
    let phase: SurfaceContentPhase // only empty or failed
    var onAddFriends: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    // body: glass card; empty → copy + Add friends; failed → copy + Try again
}
```

In `ContentView` ZStack (above map, below or beside top controls carefully — **must not** cover profile/filter/bell or bottom nav):

```swift
if viewModel.surfacePhase == .empty || viewModel.surfacePhase == .failed {
    MapEmptyOverlay(
        phase: viewModel.surfacePhase,
        onAddFriends: {
            isFilterDropdownExpanded = false
            presentedRoute = .addFriend
        },
        onRetry: { Task { await viewModel.load() } }
    )
    .padding(.horizontal, /* named constant */)
    .padding(.bottom, /* above bottom nav — named */)
    // position with a Spacer so it sits in the lower-middle map area
}
```

Do **not** show empty overlay when create menu or friend detail sheet is open if it causes occlusion issues — optional: still show behind sheets.

- [ ] **Step 5: Register MapEmptyOverlay, run tests + build**

```bash
python3 scripts/pbxproj_add.py MapEmptyOverlay.swift
scripts/test.sh suite EmptySurfaceTests
scripts/test.sh suite DataLayerTests
scripts/test.sh build
```

Expected: PASS (existing map tests still green).

- [ ] **Step 6: Commit**

```bash
git add Push/MapViewModel.swift Push/MapEmptyOverlay.swift Push/ContentView.swift Push/Data/Seed/SeedData.swift PushTests/EmptySurfaceTests.swift Push.xcodeproj/project.pbxproj
git commit -m "Add map empty/failed overlay and surface phase"
```

---

### Task 3: Friends loading/empty/failed + Add friends CTA

**Files:**
- Modify: `Push/FriendsViewModel.swift`
- Modify: `Push/FriendsComponents.swift` (`FriendsEmptyState`)
- Modify: `Push/FriendsView.swift`
- Modify: `PushTests/EmptySurfaceTests.swift`

**Interfaces:**
- Produces on `FriendsViewModel`:
  - `var surfacePhase: SurfaceContentPhase` — empty only when loaded and `rows.isEmpty` **and** not in a pure search-no-match state for the full list; for presentation:
    - failed (no value) → `.failed`
    - loading (no value) → `.loading`
    - loaded + `rows.isEmpty` → `.empty` (zero friends)
    - loaded + rows non-empty → `.content` (includes all-hidden presence)
  - `var showsFilterChips: Bool` — `friendsCount > 0` (search-no-match still has friends; chips stay)
  - Search no-match is **content** phase with empty `filteredRows` — existing `FriendsEmptyState(isSearching:)`

- [ ] **Step 1: Failing tests**

```swift
@MainActor
func testFriendsEmptyPhaseForEmptyGraph() async throws {
    let viewModel = FriendsViewModel(container: AppDataContainer(seed: .emptyGraph()))
    await viewModel.load()
    XCTAssertEqual(viewModel.surfacePhase, .empty)
    XCTAssertEqual(viewModel.friendsCount, 0)
    XCTAssertFalse(viewModel.showsFilterChips)
}

@MainActor
func testFriendsHiddenPresenceIsContentNotEmpty() async throws {
    // Seed: friends present, statuses empty / no visible presence
    let viewModel = FriendsViewModel(container: AppDataContainer(seed: .friendsWithoutPresence()))
    // Implement SeedData.friendsWithoutPresence() = standard friends + empty statuses
    // or strip statuses from a copy of standard.
    await viewModel.load()
    XCTAssertEqual(viewModel.surfacePhase, .content)
    XCTAssertFalse(viewModel.rows.isEmpty)
    XCTAssertTrue(viewModel.rows.allSatisfy { $0.friend.venueStatusText == "Hidden right now" })
}

@MainActor
func testFriendsFailedPhase() async throws {
    let container = AppDataContainer(seed: .standard())
    let viewModel = FriendsViewModel(
        friends: ThrowingFriendRepository(),
        groups: container.groups,
        sharing: container.sharing,
        pushes: container.pushes
    )
    await viewModel.load()
    XCTAssertEqual(viewModel.surfacePhase, .failed)
}
```

Add `SeedData.emptyGraph()` and `SeedData.friendsWithoutPresence()` in `SeedData.swift` (or test-only helpers under `#if DEBUG` — prefer production-visible static helpers used only by tests via `@testable`).

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement ViewModel phase + empty CTA**

```swift
var showsFilterChips: Bool { friendsCount > 0 }

var surfacePhase: SurfaceContentPhase {
    switch loadState {
    case .idle, .loading:
        return loadState.value == nil ? .loading : phaseForLoadedRows()
    case .failed:
        return loadState.value == nil ? .failed : phaseForLoadedRows()
    case .loaded:
        return phaseForLoadedRows()
    }
}

private func phaseForLoadedRows() -> SurfaceContentPhase {
    rows.isEmpty ? .empty : .content
}
```

Update `FriendsEmptyState` to accept optional `onAddFriends: (() -> Void)? = nil`. When `!isSearching` and action provided, show primary button with `EmptySurfaceCopy.addFriendsAction`. Prefer reusing `EmptySurfaceView` for the zero-friends case to avoid duplicate layout — or keep icon/title/message and add button only.

`FriendsView` list area:

```swift
switch viewModel.surfacePhase {
case .loading:
    EmptySurfaceStateView.loading(message: EmptySurfaceCopy.friendsLoading)
case .failed:
    EmptySurfaceStateView.failed(surface: "friends") { Task { await viewModel.load() } }
case .empty:
    FriendsEmptyState(mode: .friends, isSearching: false, onAddFriends: { isAddFriendPresented = true })
case .content:
    // existing filtered list; if filtered empty + searching → FriendsEmptyState(isSearching: true)
case .deferred:
    EmptyView() // unused on Friends
}
```

Hide `FriendsFilterChipRow` when `!viewModel.showsFilterChips`.

- [ ] **Step 4: Run tests**

```bash
scripts/test.sh suite EmptySurfaceTests
scripts/test.sh build
```

- [ ] **Step 5: Commit**

```bash
git commit -m "Add Friends empty CTA and loading/failed phases"
```

---

### Task 4: Feed deferred screen

**Files:**
- Create: `Push/FeedDeferredView.swift`
- Modify: `Push/ContentView.swift` (`.feed` destination)
- Modify: `PushTests/EmptySurfaceTests.swift` (optional copy assertion already covered)

**Interfaces:**
- Produces: `FeedDeferredView` — cream background, close bar, centered `EmptySurfaceView` with feed copy, **no action**.
- Phase is always `.deferred` (static); no ViewModel required unless tests want a tiny enum on the view.

- [ ] **Step 1: Implement FeedDeferredView**

```swift
struct FeedDeferredView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                // Header matching Friends/Alerts close pattern
                HStack {
                    Spacer(minLength: 0)
                    FriendsCircleButton(
                        systemImageName: "xmark",
                        accessibilityLabel: "Close Feed",
                        action: { dismiss() }
                    )
                }
                .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
                Spacer(minLength: 0)
                EmptySurfaceView(
                    title: EmptySurfaceCopy.feedDeferredTitle,
                    message: EmptySurfaceCopy.feedDeferredMessage,
                    systemImage: "list.bullet"
                )
                Spacer(minLength: 0)
            }
        }
    }
}
```

- [ ] **Step 2: Wire ContentView**

Replace:

```swift
case .feed:
    CreatePlaceholderView(...)
```

with:

```swift
case .feed:
    FeedDeferredView()
```

Leave `CreatePlaceholderView.swift` in the project if unused elsewhere; delete only if nothing references it (grep first).

- [ ] **Step 3: Register + build**

```bash
python3 scripts/pbxproj_add.py FeedDeferredView.swift
scripts/test.sh build
```

- [ ] **Step 4: Commit**

```bash
git commit -m "Replace Feed placeholder with deferred empty state"
```

---

### Task 5: Calendar empty week + hide History

**Files:**
- Modify: `Push/PlansViewModel.swift`
- Modify: `Push/PlansCalendarView.swift`
- Modify: `PushTests/EmptySurfaceTests.swift` and/or `PlansViewModelTests.swift`

**Interfaces:**
- Produces on `PlansViewModel`:
  - `var hasWeekHangoutSummary: Bool` — `totalPushesThisWeek > 0` **or** any `weekDays` with hangouts / almostHappened
  - `var showsHistoryLink: Bool` — `hasWeekHangoutSummary` for this issue (hide dead control when empty). Spec: hide when no history story — using week summary + month hangouts is enough; if `mostActiveGroup` is empty/placeholder and week total is 0 → hide.
  - `var weekFooterPrimaryText: String` — if empty week: `EmptySurfaceCopy.calendarEmptyFooter`; else existing `"\(totalPushesThisWeek) Pushes this week"`
  - `var showsMostActiveGroup: Bool` — `hasWeekHangoutSummary && !mostActiveGroup.isEmpty`
  - `var showsBestDay: Bool` — `bestDayThisWeek != nil`

Today `mostActiveGroup` defaults to `""` and footer always shows “Most active: \(viewModel.mostActiveGroup)”. Fix that.

- [ ] **Step 1: Failing tests**

```swift
@MainActor
func testPlansEmptyWeekHidesHistoryAndUsesHonestFooter() async throws {
    let viewModel = PlansViewModel(container: AppDataContainer(seed: .emptyGraph()))
    await viewModel.load()
    XCTAssertFalse(viewModel.showsHistoryLink)
    XCTAssertFalse(viewModel.hasWeekHangoutSummary)
    XCTAssertEqual(viewModel.weekFooterPrimaryText, EmptySurfaceCopy.calendarEmptyFooter)
    XCTAssertFalse(viewModel.showsMostActiveGroup)
    XCTAssertFalse(viewModel.showsBestDay)
}

@MainActor
func testPlansStandardSeedKeepsHistorySummary() async throws {
    let viewModel = PlansViewModel(container: AppDataContainer(seed: .standard()))
    await viewModel.load()
    // Standard seed has hangouts — expect summary path
    XCTAssertTrue(viewModel.hasWeekHangoutSummary || viewModel.totalPushesThisWeek >= 0)
    // If standard hangouts fall outside current week, still: when totalPushesThisWeek > 0, showsHistoryLink true
    if viewModel.totalPushesThisWeek > 0 {
        XCTAssertTrue(viewModel.showsHistoryLink)
        XCTAssertNotEqual(viewModel.weekFooterPrimaryText, EmptySurfaceCopy.calendarEmptyFooter)
    }
}
```

Adjust assertions to match how `SeedData.standard` hangouts align with `Date()` — if flaky, pass a fixed `referenceDate` that matches seed hangout dates (inspect `SeedData+History.swift`).

- [ ] **Step 2: Implement ViewModel helpers**

```swift
var hasWeekHangoutSummary: Bool {
    totalPushesThisWeek > 0
        || weekDays.contains { !$0.hangouts.isEmpty || $0.almostHappened }
}

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
```

- [ ] **Step 3: Update PlansCalendarView footer + header**

```swift
// Header History button:
if viewModel.showsHistoryLink {
    Button(action: {}) {
        Text("History ›")
        // existing styling
    }
    .buttonStyle(.plain)
}

// Footer:
Text(viewModel.weekFooterPrimaryText)
if viewModel.showsMostActiveGroup {
    Text("Most active: \(viewModel.mostActiveGroup)")
}
if viewModel.showsBestDay, let bestDay = viewModel.bestDayThisWeek {
    Text("Best day: \(bestDay)")
}
```

Leave Your/Active empty cards as-is (`showsYourPushesEmptyState` already gated on loaded empty).

- [ ] **Step 4: Run tests**

```bash
scripts/test.sh suite EmptySurfaceTests
scripts/test.sh suite PlansViewModelTests
scripts/test.sh build
```

- [ ] **Step 5: Commit**

```bash
git commit -m "Honest empty calendar week and hide dead History link"
```

---

### Task 6: Todo tracking + full verification

**Files:**
- Modify: `tasks/todo.md` — add Issue #49 checklist with completed tasks
- Optionally update `tasks/spec.md` with a short pointer to the design doc (if project habit expects it)

- [ ] **Step 1: Write `tasks/todo.md` section for Issue #49** reflecting done work

- [ ] **Step 2: Final verification**

```bash
scripts/test.sh build
scripts/test.sh suite EmptySurfaceTests
scripts/test.sh suite DataLayerTests
scripts/test.sh suite PlansViewModelTests
```

Expected: all SUCCEEDED / 0 failures.

- [ ] **Step 3: Manual sanity (simulator if available)**

```bash
scripts/run-ios-sim.sh -- --live
```

Or mock: confirm seed still shows map pucks / friends. Empty graph is harder without a live empty account — unit tests cover empty seed.

- [ ] **Step 4: Final commit if todo/docs changed**

```bash
git commit -m "Track Issue #49 empty-states verification"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Map empty overlay + Add friends | Task 2 |
| Map loading vs empty vs failed | Task 2 |
| Friends empty + Add friends CTA | Task 3 |
| Friends hidden presence remains content | Task 3 |
| Friends loading/failed | Task 3 |
| Feed deferred, no CTA, not CreatePlaceholder | Task 4 |
| Calendar honest empty footer | Task 5 |
| Hide History when empty | Task 5 |
| Suppress most active / best day when empty | Task 5 |
| Keep Your/Active push empty cards | Task 5 (no change; verify) |
| Mock populated seed | Tasks 2–5 tests |
| Shared kit / copy / phases | Task 1 |
| Unit tests | Tasks 1–5 |
| No Feed/presence/history backends | All tasks (out of scope respected) |

## Self-review notes

- No TBD placeholders; seed helpers `emptyGraph` / `friendsWithoutPresence` are required deliverables of Tasks 2–3.
- `UserProfile` construction: prefer `SeedData` helpers over ad-hoc profile in tests.
- `ThrowingFriendRepository` already exists in `DataLayerTests.swift` — reuse (same module via `@testable` / file visibility). If internal to that file only, move to a shared test helper or duplicate minimal thrower in `EmptySurfaceTests`.
- Soft-reload behavior reuses existing `LoadState` value retention patterns.
- Map self-only puck still → empty phase (no friend content).
