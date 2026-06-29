# Fix Issue #1: Make the Existing App Honest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix five broken UX issues on the existing app before adding new features: group dropdown filtering, Feed/Plans placeholder screens, "Bump"→"Push" copy, PuckLabView dev-only gating, and FriendPuck.swift file split.

**Architecture:** All fixes are isolated to existing files with no new dependencies. The group filter fix threads `selectedFriendGroup` state from ContentView down to StyledMapView via a computed property. Feed/Plans route through the existing `MainMapRoute`/`fullScreenCover` pattern. The file split is a pure refactor with no behaviour change.

**Tech Stack:** SwiftUI, iOS 17+, MVVM, mock data only, XCTest for unit coverage.

## Global Constraints

- SwiftUI only — no UIKit changes beyond what already exists
- iOS 17+ target — no availability guards needed for used APIs
- MVVM: all state in ViewModels or computed properties; Views remain dumb
- Files ≤ 400 lines, functions ≤ 40 lines
- No magic numbers — named constants only
- Mock data only — no real network or location
- Build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build`

---

### Task 1: Replace "Bump" copy with "Push"

Two string literals say "Bump" instead of "Push". The test that asserts the old string must be updated first.

**Files:**
- Modify: `Push/CreateActionModels.swift:30`
- Modify: `Push/ContentView.swift:106`
- Modify: `PushTests/PushTests.swift` — `testCreateActionMenuItemsExposeRequiredCopy`

**Interfaces:**
- Consumes: nothing new
- Produces: `CreateActionMenuItem.addFriend.subtitle == "Invite someone to Push"`

- [ ] **Step 1: Write the failing test** (update the assertion to the correct string first)

In `PushTests/PushTests.swift`, find `testCreateActionMenuItemsExposeRequiredCopy` and change the subtitle assertion:

```swift
// Before:
XCTAssertEqual(items.map(\.subtitle), [
    "Create a plan with friends",
    "Invite someone to Bump"
])

// After:
XCTAssertEqual(items.map(\.subtitle), [
    "Create a plan with friends",
    "Invite someone to Push"
])
```

- [ ] **Step 2: Build to confirm test will fail**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds; test assertion would fail at runtime because the source string still says "Bump".

- [ ] **Step 3: Change "Bump" → "Push" in CreateActionModels.swift**

In `Push/CreateActionModels.swift`, line 30:

```swift
// Before:
return "Invite someone to Bump"

// After:
return "Invite someone to Push"
```

- [ ] **Step 4: Change "Bump" → "Push" in ContentView.swift**

In `Push/ContentView.swift`, line 106:

```swift
// Before:
subtitle: "Invite someone to Bump.",

// After:
subtitle: "Invite someone to Push.",
```

- [ ] **Step 5: Build to confirm clean**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add Push/CreateActionModels.swift Push/ContentView.swift PushTests/PushTests.swift
git commit -m "fix: replace Bump copy with Push"
```

---

### Task 2: Feed and Plans tabs open placeholder screens

Currently tapping Feed or Plans highlights the tab but nothing opens — the `fullScreenCover` has no route for them and `selectNavigationItem` just sets `selectedNavigationItem`. Fix: add `.feed` and `.plans` cases to `MainMapRoute`, route them through the existing `fullScreenCover`+`CreatePlaceholderView` pattern, and reset `selectedNavigationItem` to `.map` on tap (so the tab doesn't stay highlighted).

**Files:**
- Modify: `Push/MainMapModels.swift` — add `.feed`, `.plans` to `MainMapRoute`
- Modify: `Push/ContentView.swift` — handle feed/plans in `selectNavigationItem` and `destination(for:)`
- Modify: `PushTests/PushTests.swift` — add assertions for new routes + update existing test

**Interfaces:**
- Consumes: existing `MainMapRoute` enum, `CreatePlaceholderView`, `selectNavigationItem` pattern
- Produces: `MainMapRoute.feed`, `MainMapRoute.plans` with `id`, `accessibilityLabel`, `systemImageName`

- [ ] **Step 1: Write failing tests for new routes**

Add to `PushTests/PushTests.swift`, inside `final class PushTests`:

```swift
func testMainMapRoutesFeedAndPlansExposeMetadata() throws {
    XCTAssertEqual(MainMapRoute.feed.id, "feed")
    XCTAssertEqual(MainMapRoute.feed.accessibilityLabel, "Feed")
    XCTAssertEqual(MainMapRoute.feed.systemImageName, "list.bullet")

    XCTAssertEqual(MainMapRoute.plans.id, "plans")
    XCTAssertEqual(MainMapRoute.plans.accessibilityLabel, "Plans")
    XCTAssertEqual(MainMapRoute.plans.systemImageName, "calendar")
}
```

- [ ] **Step 2: Build to confirm test references missing symbol**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: compile error — `MainMapRoute` has no member `feed`.

- [ ] **Step 3: Add `.feed` and `.plans` to MainMapRoute**

In `Push/MainMapModels.swift`, extend the `MainMapRoute` enum:

```swift
enum MainMapRoute: String, Identifiable, Equatable {
    case groups
    case profile
    case startPlan
    case addFriend
    case feed
    case plans

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .groups:
            return "Groups"
        case .profile:
            return "Profile"
        case .startPlan:
            return "Start Plan"
        case .addFriend:
            return "Add Friend"
        case .feed:
            return "Feed"
        case .plans:
            return "Plans"
        }
    }

    var systemImageName: String {
        switch self {
        case .groups:
            return "person.2.fill"
        case .profile:
            return "person.crop.circle.fill"
        case .startPlan:
            return "calendar.badge.plus"
        case .addFriend:
            return "person.badge.plus"
        case .feed:
            return "list.bullet"
        case .plans:
            return "calendar"
        }
    }
}
```

- [ ] **Step 4: Update selectNavigationItem and destination(for:) in ContentView.swift**

In `Push/ContentView.swift`, replace the `selectNavigationItem` function:

```swift
private func selectNavigationItem(_ item: BottomNavigationItem) {
    if item == .create {
        isCreateMenuPresented.toggle()
        return
    }

    isCreateMenuPresented = false

    if item == .group {
        selectedNavigationItem = .map
        presentedRoute = .groups
        return
    }

    if item == .feed {
        selectedNavigationItem = .map
        presentedRoute = .feed
        return
    }

    if item == .plans {
        selectedNavigationItem = .map
        presentedRoute = .plans
        return
    }

    selectedNavigationItem = item
}
```

In the same file, extend `destination(for:)` to handle the new routes:

```swift
@ViewBuilder
private func destination(for route: MainMapRoute) -> some View {
    switch route {
    case .groups:
        GroupsView()
    case .profile:
        ProfileView()
    case .startPlan:
        CreatePlaceholderView(
            title: "Start Plan",
            subtitle: "Create a plan with friends.",
            symbolName: route.systemImageName
        )
    case .addFriend:
        CreatePlaceholderView(
            title: "Add Friend",
            subtitle: "Invite someone to Push.",
            symbolName: route.systemImageName
        )
    case .feed:
        CreatePlaceholderView(
            title: "Feed",
            subtitle: "What's happening with your friends.",
            symbolName: route.systemImageName
        )
    case .plans:
        CreatePlaceholderView(
            title: "Plans",
            subtitle: "Shared plans with your people.",
            symbolName: route.systemImageName
        )
    }
}
```

- [ ] **Step 5: Update testMainMapRoutesExposeStableProfileMetadata to include new routes**

In `PushTests/PushTests.swift`, the existing test `testMainMapRoutesExposeStableProfileMetadata` only tests 4 routes. It doesn't need to change because the new test `testMainMapRoutesFeedAndPlansExposeMetadata` covers the new cases. No update needed.

- [ ] **Step 6: Build**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: succeeds.

- [ ] **Step 7: Commit**

```bash
git add Push/MainMapModels.swift Push/ContentView.swift PushTests/PushTests.swift
git commit -m "fix: Feed and Plans tabs open placeholder screens"
```

---

### Task 3: Group dropdown filters map pucks

`StyledMapView` receives `MapPuckMockData.pucks` hardcoded — the `selectedFriendGroup` state in ContentView is never applied. Fix: add a `groups: [FriendGroupFilter]` property to `MapPuckData`, populate it in the mock data, and compute `filteredPucks` in ContentView.

**Files:**
- Modify: `Push/MapPuckModels.swift` — add `groups` to `MapPuckData`, update mock data, update `==`
- Modify: `Push/ContentView.swift` — add `filteredPucks` computed property, pass it to `StyledMapView`
- Modify: `PushTests/PushTests.swift` — update existing puck assertions + add filter tests

**Interfaces:**
- Consumes: `FriendGroupFilter` from `MainMapModels.swift`
- Produces: `MapPuckData.groups: [FriendGroupFilter]`; `MapPuckMockData.pucks` remains 5 items with group tags

Puck → group membership for mock data:
- `chitty-blue-bottle` → `[.india]`
- `nitin-dolores` → `[.india]`
- `ishan-viplove-souvla` → `[.india]`
- `michigan-cluster` → `[.michigan]`
- `exec-crunch` → `[.exec]`

- [ ] **Step 1: Write failing tests**

Add to `PushTests/PushTests.swift`:

```swift
func testMapPuckMockDataExposesGroupTags() throws {
    let pucks = MapPuckMockData.pucks

    XCTAssertEqual(pucks.filter { $0.groups.contains(.india) }.count, 3)
    XCTAssertEqual(pucks.filter { $0.groups.contains(.michigan) }.count, 1)
    XCTAssertEqual(pucks.filter { $0.groups.contains(.exec) }.count, 1)
    XCTAssertTrue(pucks.allSatisfy { !$0.groups.isEmpty })
}

func testGroupFilterReturnsPucksForSelectedGroup() throws {
    let allPucks = MapPuckMockData.pucks

    let indiaPucks = allPucks.filter { $0.groups.contains(.india) }
    XCTAssertEqual(indiaPucks.count, 3)
    XCTAssertTrue(indiaPucks.allSatisfy { $0.groups.contains(.india) })

    let michiganPucks = allPucks.filter { $0.groups.contains(.michigan) }
    XCTAssertEqual(michiganPucks.count, 1)

    let execPucks = allPucks.filter { $0.groups.contains(.exec) }
    XCTAssertEqual(execPucks.count, 1)

    // allFriends returns everything
    XCTAssertEqual(allPucks.count, 5)
}
```

- [ ] **Step 2: Build to confirm test references missing property**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: compile error — `MapPuckData` has no member `groups`.

- [ ] **Step 3: Add groups to MapPuckData**

In `Push/MapPuckModels.swift`, update `MapPuckData`:

```swift
struct MapPuckData: Identifiable, Equatable {
    let id: String
    let kind: MapPuckKind
    let people: [FriendPuckData]
    let activity: String
    let availability: FriendAvailabilityState
    let venueStatusText: String
    let coordinate: CLLocationCoordinate2D
    let groups: [FriendGroupFilter]

    static func == (lhs: MapPuckData, rhs: MapPuckData) -> Bool {
        lhs.id == rhs.id
            && lhs.kind == rhs.kind
            && lhs.people == rhs.people
            && lhs.activity == rhs.activity
            && lhs.availability == rhs.availability
            && lhs.venueStatusText == rhs.venueStatusText
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.groups == rhs.groups
    }
}
```

- [ ] **Step 4: Update MapPuckMockData.pucks with group tags**

Replace the `pucks` array in `Push/MapPuckModels.swift`:

```swift
enum MapPuckMockData {
    static let pucks: [MapPuckData] = [
        MapPuckData(
            id: "chitty-blue-bottle",
            kind: .individual,
            people: [
                RealWorldMockData.friendPuck(
                    "chitty",
                    activity: "Coffee",
                    symbolName: "cup.and.saucer.fill",
                    displayText: "Blue Bottle",
                    availability: .freeNow,
                    venueStatusText: "At Blue Bottle"
                )
            ],
            activity: "Coffee",
            availability: .freeNow,
            venueStatusText: "At Blue Bottle",
            coordinate: CLLocationCoordinate2D(latitude: 37.7812, longitude: -122.4078),
            groups: [.india]
        ),
        MapPuckData(
            id: "nitin-dolores",
            kind: .individual,
            people: [
                RealWorldMockData.friendPuck(
                    "nitin",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .maybeDown,
                    venueStatusText: "Near Dolores"
                )
            ],
            activity: "Park",
            availability: .maybeDown,
            venueStatusText: "Near Dolores",
            coordinate: CLLocationCoordinate2D(latitude: 37.7596, longitude: -122.4269),
            groups: [.india]
        ),
        MapPuckData(
            id: "ishan-viplove-souvla",
            kind: .hangout,
            people: [
                RealWorldMockData.friendPuck(
                    "ishan",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "At Souvla"
                ),
                RealWorldMockData.friendPuck(
                    "viplove",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "With Ishan"
                )
            ],
            activity: "Lunch",
            availability: .joinable,
            venueStatusText: "At Souvla",
            coordinate: CLLocationCoordinate2D(latitude: 37.7765, longitude: -122.4231),
            groups: [.india]
        ),
        MapPuckData(
            id: "michigan-cluster",
            kind: .cluster,
            people: [
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Already there"
                ),
                RealWorldMockData.friendPuck(
                    "rohan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Walking over"
                ),
                RealWorldMockData.friendPuck(
                    "ryan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Free in 20"
                ),
                RealWorldMockData.friendPuck(
                    "pranay",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Maybe pulling up"
                )
            ],
            activity: "Park",
            availability: .joinable,
            venueStatusText: "Group forming near Dolores",
            coordinate: CLLocationCoordinate2D(latitude: 37.7673, longitude: -122.4358),
            groups: [.michigan]
        ),
        MapPuckData(
            id: "exec-crunch",
            kind: .friendGroup,
            people: [
                RealWorldMockData.groupPuck(
                    "exec",
                    activity: "Gym",
                    displayText: "Crunch"
                ),
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Wrapping up"
                ),
                RealWorldMockData.friendPuck(
                    "ohm",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "With the crew"
                ),
                RealWorldMockData.friendPuck(
                    "roh",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Joining soon"
                )
            ],
            activity: "Gym",
            availability: .joinable,
            venueStatusText: "Exec at Crunch",
            coordinate: CLLocationCoordinate2D(latitude: 37.7898, longitude: -122.4210),
            groups: [.exec]
        )
    ]
}
```

- [ ] **Step 5: Add filteredPucks computed property and pass to StyledMapView in ContentView.swift**

In `Push/ContentView.swift`, add a computed property before `body` (or within the private extension area):

```swift
private var filteredPucks: [MapPuckData] {
    guard selectedFriendGroup != .allFriends else {
        return MapPuckMockData.pucks
    }
    return MapPuckMockData.pucks.filter { $0.groups.contains(selectedFriendGroup) }
}
```

Then update the `StyledMapView` call inside `body` (line ~19):

```swift
// Before:
StyledMapView(region: MapDefaults.region, pucks: MapPuckMockData.pucks)

// After:
StyledMapView(region: MapDefaults.region, pucks: filteredPucks)
```

- [ ] **Step 6: Build**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: succeeds.

- [ ] **Step 7: Commit**

```bash
git add Push/MapPuckModels.swift Push/ContentView.swift PushTests/PushTests.swift
git commit -m "fix: group dropdown filters map pucks by group membership"
```

---

### Task 4: PuckLabView dev-only

`PuckLabView.swift` is a developer design tool and should not be reachable from production code. It's already unreachable (not referenced in any navigation flow), but wrapping it in `#if DEBUG` makes the intent explicit and ensures it's excluded from release builds.

**Files:**
- Modify: `Push/PuckLabView.swift` — wrap all content in `#if DEBUG`

**Interfaces:**
- Produces: `PuckLabView` only exists in DEBUG builds; `PuckLabMockData` (used in `PuckModels.swift`) is unaffected — it stays in `PuckModels.swift` which remains unconditional

Note: `PuckLabMockData` and `PuckLabScenario` live in `Push/PuckModels.swift`, not in `PuckLabView.swift`. The tests reference `PuckLabMockData` directly and must continue to compile. Only the View itself needs the guard.

- [ ] **Step 1: Verify PuckLabMockData is in PuckModels.swift (not PuckLabView.swift)**

Confirm: lines 128-362 of `Push/PuckModels.swift` contain `PuckLabScenario`, `PuckLabPuckStyle`, `PuckLabMockData`. These are NOT in `PuckLabView.swift`. Only the `PuckLabView` struct and its private sub-views/layout are in `PuckLabView.swift`.

- [ ] **Step 2: Wrap PuckLabView.swift in #if DEBUG**

Replace the entire content of `Push/PuckLabView.swift` with the same content wrapped:

```swift
//
//  PuckLabView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

#if DEBUG
import SwiftUI

struct PuckLabView: View {
    // ... (all existing body content unchanged) ...
}

// ... all private structs, enums, layout constants unchanged ...

struct PuckLabView_Previews: PreviewProvider {
    static var previews: some View {
        PuckLabView()
    }
}
#endif
```

The full wrapped file: keep every line of the existing file, add `#if DEBUG` immediately after the import and `#endif` at the very end.

- [ ] **Step 3: Build**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: succeeds (simulator builds are DEBUG by default).

- [ ] **Step 4: Commit**

```bash
git add Push/PuckLabView.swift
git commit -m "fix: gate PuckLabView behind #if DEBUG"
```

---

### Task 5: Split FriendPuck.swift into focused files

`FriendPuck.swift` is 650 lines — well above the 400-line limit. Split into 5 files by responsibility. This is a pure refactor: no behaviour changes, no new symbols, just relocation with minimal access level adjustments (private → internal where cross-file access is needed).

**Files to create:**
- Create: `Push/FriendPuckStyle.swift` — shared styling tokens, ViewModifier, View extensions, ProfilePhotoAvatar
- Create: `Push/FriendClusterPuck.swift` — FriendClusterPuck + its private sub-views
- Create: `Push/ActivityBadge.swift` — ActivityBadge view
- Create: `Push/AvatarStack.swift` — AvatarStack view
- Modify: `Push/FriendPuck.swift` — keep only FriendPuck, FriendGroupPuck, their private layout

**Access level changes required (private → internal):**
- `PuckColorTokens` — used in SmallGroupPuck, PairHangoutPuck, ProfilePhotoAvatar, ActivityBadge
- `FriendPuckLayout` — used in FriendPuck, FriendGroupPuck, SmallGroupPuck, PairHangoutPuck
- `ProfilePhotoAvatar` — used in FriendPuck, FriendGroupPuck, SmallGroupPuck, PairHangoutPuck
- `PulsingAvailabilityGlow` — used via extension in FriendPuck
- `extension View { availabilityPulse, puckGlassBackground }` — used in FriendPuck
- `extension FriendAvailabilityState { accentColor, avatarGradient }` — used across puck files

**Interfaces:**
- Consumes: `FriendPuckData`, `FriendAvailabilityState` from `PuckModels.swift`
- Produces: same public API — `FriendPuck`, `FriendGroupPuck`, `FriendClusterPuck`, `ActivityBadge`, `AvatarStack` all remain internal (usable within module)

- [ ] **Step 1: Create FriendPuckStyle.swift**

Create `Push/FriendPuckStyle.swift` with shared primitives. Make previously-private types internal:

```swift
//
//  FriendPuckStyle.swift
//  Push
//

import SwiftUI
import UIKit

struct ProfilePhotoAvatar: View {
    let imageAssetName: String?
    let fallbackInitials: String

    var body: some View {
        Group {
            if let image = PushImageAssets.image(named: imageAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(fallbackInitials)
                    .font(.system(size: FriendPuckLayout.fallbackInitialsSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PuckColorTokens.avatarForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        Circle()
                            .fill(PuckColorTokens.avatarGradientBase)
                    }
            }
        }
        .clipShape(Circle())
    }
}

struct PulsingAvailabilityGlow: ViewModifier {
    let color: Color
    let lineWidth: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .stroke(color.opacity(FriendPuckLayout.pulseStrokeOpacity), lineWidth: lineWidth)
                    .scaleEffect(isPulsing ? FriendPuckLayout.pulseMaxScale : FriendPuckLayout.pulseMinScale)
                    .opacity(isPulsing ? FriendPuckLayout.pulseLowOpacity : FriendPuckLayout.pulseHighOpacity)
            }
            .overlay {
                Circle()
                    .stroke(color, lineWidth: lineWidth)
            }
            .shadow(
                color: color.opacity(FriendPuckLayout.statusGlowOpacity),
                radius: isPulsing ? FriendPuckLayout.statusGlowExpandedRadius : FriendPuckLayout.statusGlowRadius,
                y: FriendPuckLayout.statusGlowYOffset
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: FriendPuckLayout.pulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func availabilityPulse(color: Color, lineWidth: CGFloat) -> some View {
        modifier(PulsingAvailabilityGlow(color: color, lineWidth: lineWidth))
    }

    func puckGlassBackground(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(FriendPuckLayout.glassTintOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(FriendPuckLayout.glassStrokeOpacity), lineWidth: FriendPuckLayout.glassStrokeWidth)
        }
    }
}

extension FriendAvailabilityState {
    var accentColor: Color {
        switch self {
        case .freeNow:
            return PuckColorTokens.freeNow
        case .freeSoon, .maybeDown:
            return PuckColorTokens.maybeDown
        case .busy:
            return PuckColorTokens.busy
        case .joinable:
            return PuckColorTokens.joinable
        case .driving:
            return PuckColorTokens.driving
        case .unavailable:
            return PuckColorTokens.unavailable
        }
    }

    var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(PuckColorTokens.avatarGradientHighOpacity),
                PuckColorTokens.avatarGradientBase
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum PuckColorTokens {
    static let avatarForeground = Color.white
    static let badgeForeground = Color.white
    static let avatarGradientBase = Color(red: 0.18, green: 0.15, blue: 0.22)
    static let avatarGradientHighOpacity = 0.88
    static let freeNow = Color(red: 0.43, green: 0.91, blue: 0.62)
    static let maybeDown = Color(red: 1.00, green: 0.78, blue: 0.24)
    static let busy = Color(red: 1.00, green: 0.50, blue: 0.25)
    static let joinable = Color(red: 0.25, green: 0.55, blue: 1.00)
    static let driving = Color(red: 0.22, green: 0.88, blue: 1.00)
    static let unavailable = Color(red: 0.55, green: 0.58, blue: 0.64)
}

enum FriendPuckLayout {
    static let defaultSize: CGFloat = 82
    static let defaultClusterSize: CGFloat = 112
    static let cornerDivisor: CGFloat = 2
    static let initialsScale = 0.28
    static let fallbackInitialsSize: CGFloat = 22
    static let statusRingWidth: CGFloat = 3
    static let clusterRingWidth: CGFloat = 3.5
    static let statusGlowOpacity = 0.36
    static let statusGlowRadius: CGFloat = 14
    static let statusGlowExpandedRadius: CGFloat = 22
    static let clusterGlowRadius: CGFloat = 18
    static let statusGlowYOffset: CGFloat = 6
    static let pulseDuration = 2.4
    static let pulseMinScale = 1.02
    static let pulseMaxScale = 1.16
    static let pulseHighOpacity = 0.5
    static let pulseLowOpacity = 0.08
    static let pulseStrokeOpacity = 0.58
    static let badgeOffset: CGFloat = 6
    static let countOffset: CGFloat = 8
    static let countBadgeSize: CGFloat = 30
    static let countStrokeOpacity = 0.82
    static let countStrokeWidth: CGFloat = 1.4
    static let clusterBadgeInset: CGFloat = 36
    static let clusterBadgeOffset: CGFloat = 10
    static let glassTintOpacity = 0.16
    static let glassStrokeOpacity = 0.64
    static let glassStrokeWidth: CGFloat = 0.9
}
```

- [ ] **Step 2: Create ActivityBadge.swift**

Create `Push/ActivityBadge.swift`:

```swift
//
//  ActivityBadge.swift
//  Push
//

import SwiftUI

struct ActivityBadge: View {
    let text: String
    let symbolName: String
    let availability: FriendAvailabilityState

    var body: some View {
        HStack(spacing: ActivityBadgeLayout.spacing) {
            Image(systemName: symbolName)
                .font(.system(size: ActivityBadgeLayout.iconSize, weight: .bold))

            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(PuckColorTokens.badgeForeground)
        .padding(.horizontal, ActivityBadgeLayout.horizontalPadding)
        .padding(.vertical, ActivityBadgeLayout.verticalPadding)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .background {
                    Capsule()
                        .fill(availability.accentColor.opacity(ActivityBadgeLayout.tintOpacity))
                }
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(ActivityBadgeLayout.strokeOpacity), lineWidth: ActivityBadgeLayout.strokeWidth)
        }
    }
}

private enum ActivityBadgeLayout {
    static let spacing: CGFloat = 4
    static let iconSize: CGFloat = 9
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 5
    static let tintOpacity = 0.48
    static let strokeOpacity = 0.7
    static let strokeWidth: CGFloat = 0.8
}
```

- [ ] **Step 3: Create AvatarStack.swift**

Create `Push/AvatarStack.swift`:

```swift
//
//  AvatarStack.swift
//  Push
//

import SwiftUI

struct AvatarStack: View {
    let friends: [FriendPuckData]
    let size: CGFloat

    private var displayedFriends: [FriendPuckData] {
        Array(friends.prefix(AvatarStackLayout.visibleAvatarLimit))
    }

    var body: some View {
        ZStack {
            ForEach(Array(displayedFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(AvatarStackLayout.avatarStrokeOpacity), lineWidth: AvatarStackLayout.avatarStrokeWidth)
                    }
                    .offset(offset(for: index))
            }
        }
    }

    private var avatarSize: CGFloat {
        size * AvatarStackLayout.avatarScale
    }

    private func offset(for index: Int) -> CGSize {
        let offsets = AvatarStackLayout.offsets
        guard offsets.indices.contains(index) else {
            return .zero
        }
        return CGSize(
            width: offsets[index].width * size,
            height: offsets[index].height * size
        )
    }
}

private enum AvatarStackLayout {
    static let visibleAvatarLimit = 3
    static let avatarScale = 0.58
    static let initialsScale = 0.14
    static let avatarStrokeOpacity = 0.86
    static let avatarStrokeWidth: CGFloat = 1.4
    static let offsets: [CGSize] = [
        CGSize(width: -0.16, height: -0.11),
        CGSize(width: 0.18, height: -0.04),
        CGSize(width: 0.02, height: 0.2)
    ]
}
```

- [ ] **Step 4: Create FriendClusterPuck.swift**

Create `Push/FriendClusterPuck.swift` with `FriendClusterPuck` and its private sub-views. Move from `FriendPuck.swift`:

```swift
//
//  FriendClusterPuck.swift
//  Push
//

import SwiftUI

struct FriendClusterPuck: View {
    let friends: [FriendPuckData]
    var size: CGFloat = FriendPuckLayout.defaultClusterSize

    private var leadAvailability: FriendAvailabilityState {
        friends
            .map(\.availability)
            .min { $0.priority < $1.priority } ?? .busy
    }

    private var sharedActivity: String {
        friends.first?.activityDisplayText ?? "Together"
    }

    private var sharedActivitySymbolName: String {
        friends.first?.activitySymbolName ?? "person.2.fill"
    }

    private var layoutKind: FriendClusterLayoutKind {
        FriendClusterLayoutKind(friendsCount: friends.count)
    }

    var body: some View {
        switch layoutKind {
        case .pair:
            PairHangoutPuck(
                friends: friends,
                size: size,
                sharedAvailability: leadAvailability,
                sharedActivity: sharedActivity,
                sharedActivitySymbolName: sharedActivitySymbolName
            )
        case .smallGroup:
            SmallGroupPuck(
                friends: friends,
                size: size,
                leadAvailability: leadAvailability,
                sharedActivity: sharedActivity,
                sharedActivitySymbolName: sharedActivitySymbolName
            )
        }
    }
}

private struct SmallGroupPuck: View {
    let friends: [FriendPuckData]
    let size: CGFloat
    let leadAvailability: FriendAvailabilityState
    let sharedActivity: String
    let sharedActivitySymbolName: String

    private var displayedFriends: [FriendPuckData] {
        Array(friends.prefix(SmallGroupLayout.visibleAvatarLimit))
    }

    var body: some View {
        avatarGroup
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(friends.count) friends, \(sharedActivity), \(leadAvailability.title)")
    }

    private var avatarGroup: some View {
        ZStack {
            ForEach(Array(displayedFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(leadAvailability.accentColor, lineWidth: SmallGroupLayout.avatarRingWidth)
                    }
                    .shadow(
                        color: leadAvailability.accentColor.opacity(SmallGroupLayout.avatarGlowOpacity),
                        radius: SmallGroupLayout.avatarGlowRadius,
                        y: SmallGroupLayout.avatarGlowYOffset
                    )
                    .offset(avatarOffset(for: index))
            }

            groupCount
                .offset(x: countXOffset, y: countYOffset)

            ActivityBadge(
                text: sharedActivity,
                symbolName: sharedActivitySymbolName,
                availability: leadAvailability
            )
            .offset(x: activityXOffset, y: activityYOffset)
        }
    }

    private var groupCount: some View {
        Text("\(friends.count)")
            .font(.caption.weight(.black))
            .foregroundStyle(PuckColorTokens.avatarForeground)
            .frame(
                width: FriendPuckLayout.countBadgeSize,
                height: FriendPuckLayout.countBadgeSize
            )
            .background {
                Circle()
                    .fill(leadAvailability.accentColor)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(FriendPuckLayout.countStrokeOpacity), lineWidth: FriendPuckLayout.countStrokeWidth)
            }
    }

    private var avatarSize: CGFloat { size * SmallGroupLayout.avatarScale }
    private var countXOffset: CGFloat { avatarSize * SmallGroupLayout.countHorizontalAnchorScale }
    private var countYOffset: CGFloat { -avatarSize * SmallGroupLayout.countVerticalAnchorScale }
    private var activityXOffset: CGFloat { avatarSize * SmallGroupLayout.activityHorizontalAnchorScale }
    private var activityYOffset: CGFloat { avatarSize * SmallGroupLayout.activityVerticalAnchorScale }

    private func avatarOffset(for index: Int) -> CGSize {
        let offsets = SmallGroupLayout.avatarOffsets
        guard offsets.indices.contains(index) else { return .zero }
        return CGSize(
            width: offsets[index].width * avatarSize,
            height: offsets[index].height * avatarSize
        )
    }
}

private struct PairHangoutPuck: View {
    let friends: [FriendPuckData]
    let size: CGFloat
    let sharedAvailability: FriendAvailabilityState
    let sharedActivity: String
    let sharedActivitySymbolName: String

    private var pairFriends: [FriendPuckData] {
        Array(friends.prefix(PairHangoutLayout.friendCount))
    }

    var body: some View {
        avatarPair
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pairFriends.count) friends, \(sharedActivity), hanging out together")
    }

    private var avatarPair: some View {
        ZStack {
            ForEach(Array(pairFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(sharedAvailability.accentColor, lineWidth: PairHangoutLayout.avatarRingWidth)
                    }
                    .shadow(
                        color: sharedAvailability.accentColor.opacity(PairHangoutLayout.avatarGlowOpacity),
                        radius: PairHangoutLayout.avatarGlowRadius,
                        y: PairHangoutLayout.avatarGlowYOffset
                    )
                    .offset(x: avatarXOffset(for: index))
            }

            clusterCount
                .offset(x: countXOffset, y: countYOffset)

            ActivityBadge(
                text: sharedActivity,
                symbolName: sharedActivitySymbolName,
                availability: sharedAvailability
            )
            .offset(x: activityXOffset, y: activityYOffset)
        }
    }

    private var clusterCount: some View {
        Text("\(PairHangoutLayout.friendCount)")
            .font(.caption.weight(.black))
            .foregroundStyle(PuckColorTokens.avatarForeground)
            .frame(
                width: FriendPuckLayout.countBadgeSize,
                height: FriendPuckLayout.countBadgeSize
            )
            .background {
                Circle()
                    .fill(sharedAvailability.accentColor)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(FriendPuckLayout.countStrokeOpacity), lineWidth: FriendPuckLayout.countStrokeWidth)
            }
    }

    private var avatarSize: CGFloat { size * PairHangoutLayout.avatarScale }
    private var pairCenterOffset: CGFloat { avatarSize * PairHangoutLayout.avatarCenterOffsetScale }
    private var countXOffset: CGFloat { pairCenterOffset + avatarSize * PairHangoutLayout.countHorizontalAnchorScale }
    private var countYOffset: CGFloat { -avatarSize * PairHangoutLayout.countVerticalAnchorScale }
    private var activityXOffset: CGFloat { pairCenterOffset + avatarSize * PairHangoutLayout.activityHorizontalAnchorScale }
    private var activityYOffset: CGFloat { avatarSize * PairHangoutLayout.activityVerticalAnchorScale }

    private func avatarXOffset(for index: Int) -> CGFloat {
        index == 0 ? -pairCenterOffset : pairCenterOffset
    }
}

private enum PairHangoutLayout {
    static let friendCount = 2
    static let avatarScale = 0.6
    static let avatarCenterOffsetScale = 0.28
    static let avatarRingWidth: CGFloat = 3
    static let avatarGlowOpacity = 0.24
    static let avatarGlowRadius: CGFloat = 12
    static let avatarGlowYOffset: CGFloat = 5
    static let countHorizontalAnchorScale = 0.42
    static let countVerticalAnchorScale = 0.4
    static let activityHorizontalAnchorScale = 0.15
    static let activityVerticalAnchorScale = 0.42
}

private enum SmallGroupLayout {
    static let visibleAvatarLimit = 3
    static let avatarScale = 0.5
    static let avatarRingWidth: CGFloat = 2.6
    static let avatarGlowOpacity = 0.22
    static let avatarGlowRadius: CGFloat = 10
    static let avatarGlowYOffset: CGFloat = 4
    static let countHorizontalAnchorScale = 0.75
    static let countVerticalAnchorScale = 0.6
    static let activityHorizontalAnchorScale = 0.3
    static let activityVerticalAnchorScale = 0.7
    static let avatarOffsets: [CGSize] = [
        CGSize(width: -0.28, height: -0.2),
        CGSize(width: 0.28, height: -0.2),
        CGSize(width: 0.0, height: 0.28)
    ]
}
```

- [ ] **Step 5: Replace FriendPuck.swift with slimmed version**

Replace the entire content of `Push/FriendPuck.swift` — keep only `FriendPuck`, `FriendGroupPuck`, and their private layout:

```swift
//
//  FriendPuck.swift
//  Push
//

import SwiftUI

struct FriendPuck: View {
    let friend: FriendPuckData
    var size: CGFloat = FriendPuckLayout.defaultSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatar
                .frame(width: size, height: size)
                .puckGlassBackground(cornerRadius: size / FriendPuckLayout.cornerDivisor)
                .availabilityPulse(
                    color: friend.availability.accentColor,
                    lineWidth: FriendPuckLayout.statusRingWidth
                )

            ActivityBadge(
                text: friend.activityDisplayText,
                symbolName: friend.activitySymbolName,
                availability: friend.availability
            )
            .offset(
                x: FriendPuckLayout.badgeOffset,
                y: FriendPuckLayout.badgeOffset
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(friend.name), \(friend.activityDisplayText), \(friend.availability.title), \(friend.venueStatusText)")
    }

    private var avatar: some View {
        ProfilePhotoAvatar(
            imageAssetName: friend.profileImageAssetName,
            fallbackInitials: friend.avatarPlaceholder
        )
    }
}

struct FriendGroupPuck: View {
    let friends: [FriendPuckData]
    var size: CGFloat = FriendPuckLayout.defaultSize

    private var leadAvailability: FriendAvailabilityState {
        friends
            .map(\.availability)
            .min { $0.priority < $1.priority } ?? .busy
    }

    private var groupAvatarInitials: String {
        friends.first?.avatarPlaceholder ?? FriendGroupLayout.fallbackInitials
    }

    private var sharedActivity: String {
        friends.first?.activityDisplayText ?? "Together"
    }

    private var sharedActivitySymbolName: String {
        friends.first?.activitySymbolName ?? "person.3.fill"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ProfilePhotoAvatar(
                imageAssetName: friends.first?.profileImageAssetName,
                fallbackInitials: groupAvatarInitials
            )
                .frame(width: size, height: size)
                .puckGlassBackground(cornerRadius: size / FriendPuckLayout.cornerDivisor)
                .availabilityPulse(
                    color: leadAvailability.accentColor,
                    lineWidth: FriendPuckLayout.statusRingWidth
                )

            groupCount
                .offset(
                    x: FriendGroupLayout.countXOffset,
                    y: FriendGroupLayout.countYOffset
                )

            ActivityBadge(
                text: sharedActivity,
                symbolName: sharedActivitySymbolName,
                availability: leadAvailability
            )
            .offset(
                x: FriendPuckLayout.badgeOffset,
                y: FriendPuckLayout.badgeOffset
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(friends.count) person friend group, \(sharedActivity), \(leadAvailability.title)")
    }

    private var groupCount: some View {
        Text("\(friends.count)")
            .font(.caption.weight(.black))
            .foregroundStyle(PuckColorTokens.avatarForeground)
            .frame(
                width: FriendPuckLayout.countBadgeSize,
                height: FriendPuckLayout.countBadgeSize
            )
            .background {
                Circle()
                    .fill(leadAvailability.accentColor)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(FriendPuckLayout.countStrokeOpacity), lineWidth: FriendPuckLayout.countStrokeWidth)
            }
    }
}

private enum FriendGroupLayout {
    static let fallbackInitials = "FG"
    static let countXOffset: CGFloat = 6.8
    static let countYOffset: CGFloat = -70
}
```

- [ ] **Step 6: Add new files to Xcode project**

The new files `FriendPuckStyle.swift`, `FriendClusterPuck.swift`, `ActivityBadge.swift`, and `AvatarStack.swift` must be added to the Xcode project's Push target. Open `Push.xcodeproj` in Xcode and drag the new files into the Push group, ensuring "Add to target: Push" is checked. Alternatively, edit `Push.xcodeproj/project.pbxproj` to include them.

Simplest path: open Xcode → right-click Push group → "Add Files to Push..." → select the 4 new files → ensure Push target is checked.

- [ ] **Step 7: Build**

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build
```

Expected: succeeds. If there are "use of unresolved identifier" errors, check that the new files were added to the Xcode project target (step 6).

- [ ] **Step 8: Commit**

```bash
git add Push/FriendPuck.swift Push/FriendPuckStyle.swift Push/FriendClusterPuck.swift Push/ActivityBadge.swift Push/AvatarStack.swift Push.xcodeproj/project.pbxproj
git commit -m "refactor: split FriendPuck.swift into focused files"
```

---

## Self-Review

**Spec coverage:**
1. ✅ Group dropdown filters map pucks → Task 3
2. ✅ Feed and Plans open placeholder screens → Task 2
3. ✅ Replace "Bump" with "Push" → Task 1
4. ✅ PuckLabView dev-only → Task 4
5. ✅ Split FriendPuck.swift → Task 5

**Placeholder scan:** No TBDs, no "implement later", no "similar to Task N" references. All code steps contain actual code.

**Type consistency:**
- `FriendGroupFilter` used in Tasks 3 and confirmed exists in `MainMapModels.swift`
- `MapPuckData.groups: [FriendGroupFilter]` added in Task 3 step 3, used in step 4 mock data, step 5 ContentView
- `MainMapRoute.feed/.plans` added in Task 2 step 3, used in step 4's `selectNavigationItem` and `destination(for:)`
- `ProfilePhotoAvatar` moved from private in `FriendPuck.swift` to internal in `FriendPuckStyle.swift` — used in `FriendClusterPuck.swift` steps without issue
- `PuckColorTokens`, `FriendPuckLayout`, `FriendAvailabilityState.accentColor` all lifted to internal in `FriendPuckStyle.swift`
