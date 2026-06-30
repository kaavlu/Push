# Friend Detail Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user taps any map puck, a bottom sheet opens showing friend/group context and four quick-action buttons.

**Architecture:** MKMapViewDelegate `didSelect` fires an `onPuckSelected` callback that flows from `StyledMapView` → `ContentView`, which presents a `.sheet(item: $selectedPuck)`. Individual pucks show a per-person view; hangout/cluster/friendGroup pucks show a group-level view. All quick actions are silent no-ops.

**Tech Stack:** SwiftUI, MapKit (MKMapViewDelegate), XCTest

## Global Constraints

- iOS 17+ target; SwiftUI + MVVM; no backend calls, all data is mock.
- Files ≤ 400 lines; functions ≤ 40 lines.
- No magic numbers — named constants only (layout enums).
- No new ViewModels for this feature — sheet is display-only.
- Build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build`
- Build-for-testing command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator'`

---

### Task 1: Extend FriendPuckData + Update RealWorldMockData Factories

**Files:**
- Modify: `Push/PuckModels.swift` — add `lastUpdated` and `withWhom` fields to `FriendPuckData`
- Modify: `Push/RealWorldMockData.swift` — thread new params through `friendPuck()` and `groupPuck()` factories
- Test: `PushTests/PushTests.swift` — two new tests for the new fields

**Interfaces:**
- Produces: `FriendPuckData.lastUpdated: String`, `FriendPuckData.withWhom: [String]?` — used by Task 4 (FriendDetailSheet)
- Produces: `RealWorldMockData.friendPuck(_:activity:symbolName:displayText:availability:venueStatusText:lastUpdated:withWhom:)` — used by Task 2 (MapPuckMockData updates)

- [ ] **Step 1: Write the failing tests**

Add these two test methods to the `PushTests` class in `PushTests/PushTests.swift`, before the final closing brace:

```swift
func testFriendPuckDataStoresLastUpdatedAndWithWhom() throws {
    let puck = FriendPuckData(
        name: "Ishan",
        avatarPlaceholder: "IS",
        profileImageAssetName: "assets/friends/ishan.png",
        activity: "Lunch",
        activitySymbolName: "fork.knife",
        activityDisplayText: "Souvla",
        availability: .joinable,
        venueStatusText: "At Souvla",
        lastUpdated: "Just now",
        withWhom: ["Viplove"]
    )

    XCTAssertEqual(puck.lastUpdated, "Just now")
    XCTAssertEqual(puck.withWhom, ["Viplove"])
}

func testFriendPuckDataDefaultsToJustNowAndNilWithWhom() throws {
    let puck = FriendPuckData(
        name: "Chitty",
        avatarPlaceholder: "CH",
        activity: "Coffee",
        activitySymbolName: "cup.and.saucer.fill",
        activityDisplayText: "Blue Bottle",
        availability: .freeNow,
        venueStatusText: "At Blue Bottle"
    )

    XCTAssertEqual(puck.lastUpdated, "Just now")
    XCTAssertNil(puck.withWhom)
}
```

- [ ] **Step 2: Build-for-testing to verify tests exist but compilation fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: compile errors mentioning missing `lastUpdated` / `withWhom` arguments.

- [ ] **Step 3: Add `lastUpdated` and `withWhom` to `FriendPuckData` in `Push/PuckModels.swift`**

Replace the entire `FriendPuckData` struct (lines 94–126) with:

```swift
struct FriendPuckData: Identifiable, Equatable {
    let id: UUID
    let name: String
    let avatarPlaceholder: String
    let profileImageAssetName: String?
    let activity: String
    let activitySymbolName: String
    let activityDisplayText: String
    let availability: FriendAvailabilityState
    let venueStatusText: String
    let lastUpdated: String
    let withWhom: [String]?

    init(
        id: UUID = UUID(),
        name: String,
        avatarPlaceholder: String,
        profileImageAssetName: String? = nil,
        activity: String,
        activitySymbolName: String,
        activityDisplayText: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        lastUpdated: String = "Just now",
        withWhom: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarPlaceholder = avatarPlaceholder
        self.profileImageAssetName = profileImageAssetName
        self.activity = activity
        self.activitySymbolName = activitySymbolName
        self.activityDisplayText = activityDisplayText
        self.availability = availability
        self.venueStatusText = venueStatusText
        self.lastUpdated = lastUpdated
        self.withWhom = withWhom
    }
}
```

- [ ] **Step 4: Update `RealWorldMockData.friendPuck()` in `Push/RealWorldMockData.swift`**

Replace the `friendPuck` method (lines 88–107) with:

```swift
static func friendPuck(
    _ id: String,
    activity: String,
    symbolName: String,
    displayText: String,
    availability: FriendAvailabilityState,
    venueStatusText: String,
    lastUpdated: String = "Just now",
    withWhom: [String]? = nil
) -> FriendPuckData {
    let seed = friend(withID: id)
    return FriendPuckData(
        name: seed.displayName,
        avatarPlaceholder: seed.initials,
        profileImageAssetName: seed.imageAssetName,
        activity: activity,
        activitySymbolName: symbolName,
        activityDisplayText: displayText,
        availability: availability,
        venueStatusText: venueStatusText,
        lastUpdated: lastUpdated,
        withWhom: withWhom
    )
}
```

- [ ] **Step 5: Update `RealWorldMockData.groupPuck()` in `Push/RealWorldMockData.swift`**

Replace the `groupPuck` method (lines 109–121) with:

```swift
static func groupPuck(
    _ groupID: String,
    activity: String,
    displayText: String,
    lastUpdated: String = "Just now"
) -> FriendPuckData {
    let group = groups.first { $0.id == groupID }
    return FriendPuckData(
        name: group?.name ?? groupID,
        avatarPlaceholder: initials(for: group?.name ?? groupID),
        profileImageAssetName: group?.imageAssetName,
        activity: activity,
        activitySymbolName: "person.3.fill",
        activityDisplayText: displayText,
        availability: .joinable,
        venueStatusText: "\(group?.name ?? "Group") is together",
        lastUpdated: lastUpdated,
        withWhom: nil
    )
}
```

- [ ] **Step 6: Build-for-testing to verify tests compile and pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Push/PuckModels.swift Push/RealWorldMockData.swift PushTests/PushTests.swift
git commit -m "feat: add lastUpdated and withWhom fields to FriendPuckData"
```

---

### Task 2: Update MapPuckMockData with Contextual Values

**Files:**
- Modify: `Push/MapPuckModels.swift` — pass explicit `lastUpdated` and `withWhom` at every `friendPuck()` and `groupPuck()` call site

**Interfaces:**
- Consumes: `RealWorldMockData.friendPuck(_:activity:symbolName:displayText:availability:venueStatusText:lastUpdated:withWhom:)` from Task 1
- Consumes: `RealWorldMockData.groupPuck(_:activity:displayText:lastUpdated:)` from Task 1

- [ ] **Step 1: Replace `MapPuckMockData.pucks` in `Push/MapPuckModels.swift`**

Replace the entire `MapPuckMockData` enum (lines 41–192) with:

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
                    venueStatusText: "At Blue Bottle",
                    lastUpdated: "3 min ago",
                    withWhom: nil
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
                    venueStatusText: "Near Dolores",
                    lastUpdated: "8 min ago",
                    withWhom: nil
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
                    venueStatusText: "At Souvla",
                    lastUpdated: "Just now",
                    withWhom: ["Viplove"]
                ),
                RealWorldMockData.friendPuck(
                    "viplove",
                    activity: "Lunch",
                    symbolName: "fork.knife",
                    displayText: "Souvla",
                    availability: .joinable,
                    venueStatusText: "With Ishan",
                    lastUpdated: "Just now",
                    withWhom: ["Ishan"]
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
                    venueStatusText: "Already there",
                    lastUpdated: "5 min ago",
                    withWhom: ["Rohan", "Ryan", "Pranay"]
                ),
                RealWorldMockData.friendPuck(
                    "rohan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Walking over",
                    lastUpdated: "5 min ago",
                    withWhom: ["Ram", "Ryan", "Pranay"]
                ),
                RealWorldMockData.friendPuck(
                    "ryan",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Free in 20",
                    lastUpdated: "5 min ago",
                    withWhom: ["Ram", "Rohan", "Pranay"]
                ),
                RealWorldMockData.friendPuck(
                    "pranay",
                    activity: "Park",
                    symbolName: "leaf.fill",
                    displayText: "Dolores",
                    availability: .joinable,
                    venueStatusText: "Maybe pulling up",
                    lastUpdated: "5 min ago",
                    withWhom: ["Ram", "Rohan", "Ryan"]
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
                    displayText: "Crunch",
                    lastUpdated: "12 min ago"
                ),
                RealWorldMockData.friendPuck(
                    "ram",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Wrapping up",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ohm", "Roh"]
                ),
                RealWorldMockData.friendPuck(
                    "ohm",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "With the crew",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ram", "Roh"]
                ),
                RealWorldMockData.friendPuck(
                    "roh",
                    activity: "Gym",
                    symbolName: "dumbbell.fill",
                    displayText: "Crunch",
                    availability: .joinable,
                    venueStatusText: "Joining soon",
                    lastUpdated: "12 min ago",
                    withWhom: ["Ram", "Ohm"]
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

- [ ] **Step 2: Build to verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add Push/MapPuckModels.swift
git commit -m "feat: populate lastUpdated and withWhom on all map puck mock data"
```

---

### Task 3: Wire Tap Bridging in StyledMapView and ContentView

**Files:**
- Modify: `Push/StyledMapView.swift` — add `onPuckSelected` closure property; pass to `Coordinator`; implement `mapView(_:didSelect:)` in `Coordinator`
- Modify: `Push/ContentView.swift` — add `@State private var selectedPuck: MapPuckData?`; update `StyledMapView` call site; add `.sheet(item: $selectedPuck)`

**Interfaces:**
- Produces: `StyledMapView(region:pucks:onPuckSelected:)` — consumed by Task 3's ContentView update
- Produces: `ContentView` sheet presentation of `FriendDetailSheet(puck:)` — consumed by Task 4

- [ ] **Step 1: Update `StyledMapView` struct and `Coordinator` in `Push/StyledMapView.swift`**

Replace the entire file content with:

```swift
//
//  StyledMapView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import MapKit
import SwiftUI

struct StyledMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let pucks: [MapPuckData]
    let onPuckSelected: (MapPuckData) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPuckSelected: onPuckSelected)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        applyStyle(to: mapView)
        syncAnnotations(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        applyStyle(to: mapView)
        syncAnnotations(on: mapView)
    }

    private func applyStyle(to mapView: MKMapView) {
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsTraffic = false

        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.emphasisStyle = .muted
            configuration.pointOfInterestFilter = .excludingAll
            configuration.showsTraffic = false
            mapView.preferredConfiguration = configuration
        } else {
            mapView.mapType = .mutedStandard
        }
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let existingPuckAnnotations = mapView.annotations.compactMap { $0 as? MapPuckAnnotation }
        mapView.removeAnnotations(existingPuckAnnotations)
        mapView.addAnnotations(pucks.map(MapPuckAnnotation.init))
    }
}

final class Coordinator: NSObject, MKMapViewDelegate {
    private let onPuckSelected: (MapPuckData) -> Void

    init(onPuckSelected: @escaping (MapPuckData) -> Void) {
        self.onPuckSelected = onPuckSelected
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let puckAnnotation = annotation as? MapPuckAnnotation else {
            return nil
        }

        let annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: MapPuckAnnotationHostingView.reuseIdentifier
        ) as? MapPuckAnnotationHostingView ?? MapPuckAnnotationHostingView(
            annotation: annotation,
            reuseIdentifier: MapPuckAnnotationHostingView.reuseIdentifier
        )
        annotationView.configure(with: puckAnnotation.puck)
        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? MapPuckAnnotation else { return }
        mapView.deselectAnnotation(annotation, animated: false)
        onPuckSelected(annotation.puck)
    }
}

private final class MapPuckAnnotation: NSObject, MKAnnotation {
    let puck: MapPuckData

    var coordinate: CLLocationCoordinate2D {
        puck.coordinate
    }

    init(puck: MapPuckData) {
        self.puck = puck
    }
}

private final class MapPuckAnnotationHostingView: MKAnnotationView {
    static let reuseIdentifier = "MapPuckAnnotationHostingView"

    private var hostingController: UIHostingController<MapPuckAnnotationView>?

    func configure(with puck: MapPuckData) {
        let rootView = MapPuckAnnotationView(puck: puck)
        let size = MapPuckAnnotationView.size(for: puck.kind)
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = .zero
        canShowCallout = false

        if let hostingController {
            hostingController.rootView = rootView
            hostingController.view.frame = bounds
        } else {
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = bounds
            addSubview(hostingController.view)
            self.hostingController = hostingController
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
}

private struct MapPuckAnnotationView: View {
    let puck: MapPuckData

    var body: some View {
        puckView
            .frame(
                width: Self.size(for: puck.kind).width,
                height: Self.size(for: puck.kind).height
            )
            .shadow(
                color: .black.opacity(MapPuckAnnotationLayout.shadowOpacity),
                radius: MapPuckAnnotationLayout.shadowRadius,
                y: MapPuckAnnotationLayout.shadowYOffset
            )
    }

    static func size(for kind: MapPuckKind) -> CGSize {
        switch kind {
        case .individual:
            return MapPuckAnnotationLayout.individualFrameSize
        case .hangout, .cluster, .friendGroup:
            return MapPuckAnnotationLayout.groupFrameSize
        }
    }

    @ViewBuilder
    private var puckView: some View {
        switch puck.kind {
        case .individual:
            if let friend = puck.people.first {
                FriendPuck(friend: friend, size: MapPuckAnnotationLayout.individualPuckSize)
            }
        case .hangout, .cluster:
            FriendClusterPuck(friends: puck.people, size: MapPuckAnnotationLayout.clusterPuckSize)
        case .friendGroup:
            FriendGroupPuck(friends: puck.people, size: MapPuckAnnotationLayout.friendGroupPuckSize)
        }
    }
}

private enum MapPuckAnnotationLayout {
    static let individualPuckSize: CGFloat = 82
    static let clusterPuckSize: CGFloat = 116
    static let friendGroupPuckSize: CGFloat = 92
    static let individualFrameSize = CGSize(width: 126, height: 126)
    static let groupFrameSize = CGSize(width: 164, height: 154)
    static let shadowOpacity = 0.28
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 8
}
```

- [ ] **Step 2: Update `ContentView.swift` — add state, update call site, add sheet**

Add `@State private var selectedPuck: MapPuckData?` after line 15 (`@State private var isCreateMenuPresented = false`):

```swift
@State private var selectedPuck: MapPuckData?
```

Update the `StyledMapView` call inside `body`'s `ZStack` — replace:

```swift
StyledMapView(region: MapDefaults.region, pucks: filteredPucks)
    .ignoresSafeArea()
```

with:

```swift
StyledMapView(region: MapDefaults.region, pucks: filteredPucks) { puck in
    selectedPuck = puck
}
.ignoresSafeArea()
```

Add the sheet modifier after the `.fullScreenCover(item: $presentedRoute)` modifier:

```swift
.sheet(item: $selectedPuck) { puck in
    FriendDetailSheet(puck: puck)
}
```

- [ ] **Step 3: Build to verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add Push/StyledMapView.swift Push/ContentView.swift
git commit -m "feat: wire puck tap → FriendDetailSheet via MKMapViewDelegate callback"
```

---

### Task 4: Create FriendDetailSheetStyle.swift and FriendDetailSheet.swift

**Files:**
- Create: `Push/FriendDetailSheetStyle.swift` — layout constants + `FriendDetailSheetContent.groupHeadline(for:)` static helper
- Create: `Push/FriendDetailSheet.swift` — sheet view with individual and group layouts
- Test: `PushTests/PushTests.swift` — three new tests for `groupHeadline`

**Interfaces:**
- Consumes: `FriendPuckData.lastUpdated`, `FriendPuckData.withWhom` from Task 1
- Consumes: `MapPuckData` (Identifiable via `id: String`) — passed as `.sheet(item:)` binding from Task 3
- Consumes: `ProfilePhotoAvatar`, `ActivityBadge`, `AvatarStack`, `PushControlColors`, `PushColorPalette`, `pushGlassBackground`

- [ ] **Step 1: Write the failing groupHeadline tests**

Add these three test methods to the `PushTests` class in `PushTests/PushTests.swift`:

```swift
func testGroupHeadlineForTwoPeopleJoinsWithPlus() throws {
    let people: [FriendPuckData] = [
        FriendPuckData(
            name: "Ishan", avatarPlaceholder: "IS", activity: "Lunch",
            activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
            availability: .joinable, venueStatusText: "At Souvla"
        ),
        FriendPuckData(
            name: "Viplove", avatarPlaceholder: "VI", activity: "Lunch",
            activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
            availability: .joinable, venueStatusText: "With Ishan"
        )
    ]

    XCTAssertEqual(FriendDetailSheetContent.groupHeadline(for: people), "Ishan + Viplove")
}

func testGroupHeadlineForThreeOrMorePeopleUsesCount() throws {
    let people: [FriendPuckData] = (0..<4).map { i in
        FriendPuckData(
            name: "Person \(i)", avatarPlaceholder: "P\(i)", activity: "Park",
            activitySymbolName: "leaf.fill", activityDisplayText: "Dolores",
            availability: .joinable, venueStatusText: "At Dolores"
        )
    }

    XCTAssertEqual(FriendDetailSheetContent.groupHeadline(for: people), "4 people")
}

func testGroupHeadlineForEmptyPeopleFallsBack() throws {
    XCTAssertEqual(FriendDetailSheetContent.groupHeadline(for: []), "Group")
}
```

- [ ] **Step 2: Build-for-testing to verify tests fail to compile**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: compile error — `FriendDetailSheetContent` not found.

- [ ] **Step 3: Create `Push/FriendDetailSheetStyle.swift`**

```swift
//
//  FriendDetailSheetStyle.swift
//  Push
//

import Foundation

enum FriendDetailSheetLayout {
    static let heroTopPadding: CGFloat = 24
    static let heroBottomPadding: CGFloat = 20
    static let heroAvatarSize: CGFloat = 72
    static let heroGroupSize: CGFloat = 80
    static let heroNameSpacing: CGFloat = 8
    static let heroInnerSpacing: CGFloat = 4
    static let infoHorizontalPadding: CGFloat = 24
    static let infoRowVerticalPadding: CGFloat = 10
    static let infoIconSize: CGFloat = 14
    static let infoIconFrameWidth: CGFloat = 20
    static let infoIconSpacing: CGFloat = 10
    static let dividerVerticalPadding: CGFloat = 20
    static let actionHorizontalPadding: CGFloat = 20
    static let actionBottomPadding: CGFloat = 32
    static let actionSpacing: CGFloat = 10
    static let actionHeight: CGFloat = 56
    static let actionCornerRadius: CGFloat = 16
    static let actionIconSize: CGFloat = 16
    static let actionLabelSpacing: CGFloat = 4
    static let actionMinimumScaleFactor: CGFloat = 0.8
    static let primaryTintOpacity: CGFloat = 0.35
}

enum FriendDetailSheetContent {
    static func groupHeadline(for people: [FriendPuckData]) -> String {
        guard !people.isEmpty else { return "Group" }
        if people.count == 2 {
            return "\(people[0].name) + \(people[1].name)"
        }
        return "\(people.count) people"
    }
}
```

- [ ] **Step 4: Build-for-testing to verify tests now compile and pass**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 5: Create `Push/FriendDetailSheet.swift`**

```swift
//
//  FriendDetailSheet.swift
//  Push
//

import SwiftUI

struct FriendDetailSheet: View {
    let puck: MapPuckData

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if puck.kind == .individual, let friend = puck.people.first {
                    individualContent(friend: friend)
                } else {
                    groupContent
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Individual

    private func individualContent(friend: FriendPuckData) -> some View {
        VStack(spacing: 0) {
            individualHero(friend: friend)
            individualInfo(friend: friend)
            Divider()
                .padding(.vertical, FriendDetailSheetLayout.dividerVerticalPadding)
            actionsRow(availability: friend.availability, isGroup: false)
        }
    }

    private func individualHero(friend: FriendPuckData) -> some View {
        VStack(spacing: FriendDetailSheetLayout.heroNameSpacing) {
            ProfilePhotoAvatar(
                imageAssetName: friend.profileImageAssetName,
                fallbackInitials: friend.avatarPlaceholder
            )
            .frame(
                width: FriendDetailSheetLayout.heroAvatarSize,
                height: FriendDetailSheetLayout.heroAvatarSize
            )

            VStack(spacing: FriendDetailSheetLayout.heroInnerSpacing) {
                Text(friend.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                ActivityBadge(
                    text: friend.activityDisplayText,
                    symbolName: friend.activitySymbolName,
                    availability: friend.availability
                )
            }
        }
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.heroBottomPadding)
    }

    private func individualInfo(friend: FriendPuckData) -> some View {
        VStack(spacing: 0) {
            DetailInfoRow(symbolName: friend.activitySymbolName, text: friend.venueStatusText)

            if let withWhom = friend.withWhom, !withWhom.isEmpty {
                DetailInfoRow(
                    symbolName: "person.2.fill",
                    text: withWhom.joined(separator: ", ")
                )
            }

            DetailInfoRow(symbolName: "clock", text: friend.lastUpdated, isSecondary: true)
        }
        .padding(.horizontal, FriendDetailSheetLayout.infoHorizontalPadding)
    }

    // MARK: - Group

    private var groupContent: some View {
        VStack(spacing: 0) {
            groupHero
            groupInfo
            Divider()
                .padding(.vertical, FriendDetailSheetLayout.dividerVerticalPadding)
            actionsRow(availability: puck.availability, isGroup: true)
        }
    }

    private var groupHero: some View {
        VStack(spacing: FriendDetailSheetLayout.heroNameSpacing) {
            AvatarStack(friends: puck.people, size: FriendDetailSheetLayout.heroGroupSize)
                .frame(
                    width: FriendDetailSheetLayout.heroGroupSize,
                    height: FriendDetailSheetLayout.heroGroupSize
                )

            VStack(spacing: FriendDetailSheetLayout.heroInnerSpacing) {
                Text(FriendDetailSheetContent.groupHeadline(for: puck.people))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                ActivityBadge(
                    text: puck.activity,
                    symbolName: puck.people.first?.activitySymbolName ?? "person.3.fill",
                    availability: puck.availability
                )
            }
        }
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.heroBottomPadding)
    }

    private var groupInfo: some View {
        VStack(spacing: 0) {
            DetailInfoRow(
                symbolName: puck.people.first?.activitySymbolName ?? "mappin",
                text: puck.venueStatusText
            )
            DetailInfoRow(
                symbolName: "clock",
                text: puck.people.first?.lastUpdated ?? "Recently",
                isSecondary: true
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.infoHorizontalPadding)
    }

    // MARK: - Actions

    private func actionsRow(availability: FriendAvailabilityState, isGroup: Bool) -> some View {
        HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
            DetailActionButton(label: isGroup ? "Ping all" : "Ping", symbolName: "bolt.fill")
            DetailActionButton(label: "Start plan", symbolName: "calendar.badge.plus")
            if availability == .joinable {
                DetailActionButton(label: "Pull Up?", symbolName: "figure.wave", isPrimary: true)
            }
            DetailActionButton(label: "Hide", symbolName: "eye.slash.fill")
        }
        .padding(.horizontal, FriendDetailSheetLayout.actionHorizontalPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
    }
}

// MARK: - Sub-components

private struct DetailInfoRow: View {
    let symbolName: String
    let text: String
    var isSecondary: Bool = false

    var body: some View {
        HStack(spacing: FriendDetailSheetLayout.infoIconSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: FriendDetailSheetLayout.infoIconSize, weight: .semibold))
                .foregroundStyle(isSecondary ? Color.secondary : PushControlColors.activeForeground)
                .frame(width: FriendDetailSheetLayout.infoIconFrameWidth)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(isSecondary ? Color.secondary : PushControlColors.activeForeground)

            Spacer()
        }
        .padding(.vertical, FriendDetailSheetLayout.infoRowVerticalPadding)
    }
}

private struct DetailActionButton: View {
    let label: String
    let symbolName: String
    var isPrimary: Bool = false

    var body: some View {
        Button(action: {}) {
            VStack(spacing: FriendDetailSheetLayout.actionLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: FriendDetailSheetLayout.actionIconSize, weight: .semibold))

                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(FriendDetailSheetLayout.actionMinimumScaleFactor)
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.actionHeight)
            .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.actionCornerRadius)
            .overlay {
                if isPrimary {
                    RoundedRectangle(
                        cornerRadius: FriendDetailSheetLayout.actionCornerRadius,
                        style: .continuous
                    )
                    .fill(PushColorPalette.Accent.sunbeam.opacity(FriendDetailSheetLayout.primaryTintOpacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
```

- [ ] **Step 6: Final build to verify everything compiles**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Push/FriendDetailSheetStyle.swift Push/FriendDetailSheet.swift PushTests/PushTests.swift
git commit -m "feat: add FriendDetailSheet with individual and group layouts"
```
