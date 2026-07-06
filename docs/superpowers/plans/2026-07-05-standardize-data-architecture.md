# Standardize Data Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace six scattered mock-data enums with one local data layer: normalized seed → in-memory store → async throws repositories → view-model builders, per the approved spec `docs/superpowers/specs/2026-07-05-data-architecture-design.md`.

**Architecture:** Plain-struct domain entities with stable opaque String IDs live in `Push/Data/Domain/`. A `@MainActor` `InMemoryDatabase` is seeded from one `SeedData` file and wrapped by `async throws` repository protocols composed in `AppDataContainer`. View models load through repositories into `LoadState` and derive the existing presentation structs (`FriendPuckData`, `MapPuckData`, `PushGroupData`, `PlanData`, …) so views barely change.

**Tech Stack:** Swift 5 / SwiftUI, ObservableObject + async/await, XCTest, xcodeproj objectVersion 56 (manual pbxproj registration via helper script).

## Global Constraints

- Deployment target is **iOS 16.4** (project.pbxproj) — do NOT use `@Observable`, `Observation`, or other iOS 17-only APIs. Use `ObservableObject`/`@Published`.
- Files ≤ 400 lines; functions ≤ 40 lines; no magic numbers; comments explain WHY (CLAUDE.md).
- User-facing copy says **Push/Pushes**, never Plan/Plans.
- **Every new Swift file must be registered in `Push.xcodeproj/project.pbxproj`** with `scripts/pbxproj_add.py` (created in Task 1). App files: `python3 scripts/pbxproj_add.py Data/Domain/Person.swift …`. Test files: `python3 scripts/pbxproj_add.py --target tests DataLayerTests.swift`.
- Build command (must pass at the end of every task):
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build`
- Test command:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PushTests`
  **Known environment issue** (tasks/lessons.md): the local simulator runner may fail with `xcrun: error: unable to find utility "simctl"`. If that exact error occurs, fall back to compiling tests:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator'`
  and note in the commit message that tests compiled but could not run locally. "Run test, expect FAIL" steps then become "confirm the compile fails / assertion is present".
- Existing `GroupsTests.testGroupMockDataExposesRequestedGroups` asserts `memberCount == [5, 2, 5]` while the code produces `[5, 3, 5]` — proof the suite has not actually run in a while. Do not treat existing test expectations as ground truth; the rewrites below give correct values.
- Commit after every task with the message given in the task. All commits append:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- A post-commit hook runs a documentation updater; it may create an extra `[skip ci]` commit. That is expected — do not fight it.

---

### Task 1: pbxproj registration helper script

**Files:**
- Create: `scripts/pbxproj_add.py`

**Interfaces:**
- Produces: CLI `python3 scripts/pbxproj_add.py [--target tests] <path-relative-to-group> …` used by every later task.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""Register Swift source files in Push.xcodeproj (objectVersion 56).

Usage:
  python3 scripts/pbxproj_add.py Data/Domain/Person.swift ...      # app target, paths relative to Push/
  python3 scripts/pbxproj_add.py --target tests DataLayerTests.swift  # test target, relative to PushTests/

IDs are deterministic (md5 of target+path) so re-running is idempotent.
"""
import hashlib
import pathlib
import re
import sys

PBXPROJ = pathlib.Path("Push.xcodeproj/project.pbxproj")


def hex_id(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def insert_after(content: str, pattern: str, addition: str) -> str:
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        sys.exit(f"anchor not found: {pattern}")
    idx = content.index("\n", match.end()) + 1
    return content[:idx] + addition + content[idx:]


def add_file(content: str, rel_path: str, target: str) -> str:
    name = rel_path.split("/")[-1]
    file_ref = hex_id(f"{target}:{rel_path}")
    build = hex_id(f"{target}:{rel_path}:build")
    if file_ref in content:
        print(f"skip (already registered): {rel_path}")
        return content
    content = insert_after(
        content,
        r"^/\* Begin PBXBuildFile section \*/$",
        f"\t\t{build} /* {name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {file_ref} /* {name} */; }};\n",
    )
    if "/" in rel_path:
        path_attr = f'name = {name}; path = "{rel_path}"; '
    else:
        path_attr = f"path = {name}; "
    content = insert_after(
        content,
        r"^/\* Begin PBXFileReference section \*/$",
        f"\t\t{file_ref} /* {name} */ = {{isa = PBXFileReference; "
        f'lastKnownFileType = sourcecode.swift; {path_attr}sourceTree = "<group>"; }};\n',
    )
    # Anchor on a file that already exists in the right group / build phase.
    group_member = "ContentView.swift" if target == "app" else "PushTests.swift"
    content = insert_after(
        content,
        rf"^\s+\w{{24}} /\* {group_member} \*/,$",
        f"\t\t\t\t{file_ref} /* {name} */,\n",
    )
    content = insert_after(
        content,
        rf"^\s+\w{{24}} /\* {group_member} in Sources \*/,$",
        f"\t\t\t\t{build} /* {name} in Sources */,\n",
    )
    print(f"registered: {rel_path} -> {target}")
    return content


def main() -> None:
    args = sys.argv[1:]
    target = "app"
    if args[:1] == ["--target"]:
        target = "tests" if args[1] == "tests" else "app"
        args = args[2:]
    if not args:
        sys.exit("no files given")
    content = PBXPROJ.read_text()
    for rel in args:
        content = add_file(content, rel, target)
    PBXPROJ.write_text(content)


main()
```

- [ ] **Step 2: Smoke-test idempotence without touching real state**

Run: `git stash list >/dev/null && python3 scripts/pbxproj_add.py Data/SmokeTest.swift && python3 scripts/pbxproj_add.py Data/SmokeTest.swift && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project Push.xcodeproj`
Expected: first run prints `registered:`, second prints `skip (already registered):`, `xcodebuild -list` prints targets without parse errors.

- [ ] **Step 3: Revert the smoke entry**

Run: `git checkout -- Push.xcodeproj/project.pbxproj`

- [ ] **Step 4: Commit**

```bash
git add scripts/pbxproj_add.py
git commit -m "chore: add pbxproj registration helper for new source files"
```

---

### Task 2: Domain entities + LoadState

**Files:**
- Create: `Push/Data/Domain/Person.swift`, `Push/Data/Domain/FriendGroup.swift`, `Push/Data/Domain/GroupMembership.swift`, `Push/Data/Domain/Place.swift`, `Push/Data/Domain/PresenceStatus.swift`, `Push/Data/Domain/SharingPolicy.swift`, `Push/Data/Domain/PushPlan.swift`, `Push/Data/Domain/PushResponse.swift`, `Push/Data/Domain/PastHangout.swift`, `Push/Data/Domain/FeedEvent.swift`, `Push/Data/Domain/UserProfile.swift`, `Push/Data/LoadState.swift`
- Modify: `Push/PuckModels.swift:10` (`FriendAvailabilityState` gains `String` raw value + `Codable`)
- Modify: `Push/ProfileModels.swift` (`ProfileToggleItem`, `ProfileConnector`, `ProfileAvailabilityOption` gain `Codable`)
- Test: `PushTests/DataLayerTests.swift` (new)

**Interfaces:**
- Produces (exact, used by every later task):
  - `Person(id: String, firstName: String, imageAssetPath: String?)` + computed `displayName`, `initials`
  - `FriendGroup(id: String, name: String, imageAssetPath: String?)` + computed `initials`
  - `GroupMembership(id:personID:groupID:role:sharingLevel:membershipStatus:joinedAt:)` with nested `Role { owner, member }`, `SharingLevel { full, availabilityOnly, hidden }`, `Status { active, invited, left }`
  - `Place(id:name:shortName:address:vagueLabel:latitude:longitude:)` + computed `coordinate: CLLocationCoordinate2D`
  - `PresenceActivity(name: String, symbolName: String)`
  - `PresenceStatus(id:personID:availability:activity:placeID:statusNote:confidence:observedAt:updatedAt:expiresAt:source:)` with `Confidence { high, medium, low }`, `Source { seed, location, manualOverride, inference }`
  - `SharingPolicy(id:ownerPersonID:audienceType:audienceID:locationVisibility:activityVisibility:availabilityVisibility:expiresAt:)` with `AudienceType { friend, group, globalDefault }`, `LocationVisibility { exact, vague, hidden }`, `DetailVisibility { full, vague, hidden }`, `AvailabilityVisibility { full, hidden }`
  - `PushPlan(id:title:groupID:creatorID:createdAt:updatedAt:startsAt:hasExplicitTime:isApproximateTime:expiresAt:cancelledAt:placeID:placeIsSuggested:state:audience:)` with `State { collecting, locked, happening }`, `Audience { group, inviteesOnly }`
  - `PushResponse(id:pushID:personID:response:respondedAt:readyState:)` with `Response { in, maybe, out, pending }` (backtick `` `in` ``), `ReadyState { readyNow, readyLater, needsRide, notReady, unknown }`
  - `PastHangout(id:date:participantIDs:note:timeRange:cameFromPush:didHappen:)`
  - `FeedEvent(id:kind:actorIDs:placeID:groupID:timestamp:)` with `Kind { arrived, becameFree, groupForming, pushCreated }`
  - `UserProfile(personID:handle:chosenAvailability:visibilityNote:availabilityOptions:activityVisibility:mapPreferences:closeFriends:connectors:)`
  - `LoadState<Value> { idle, loading, loaded(Value), failed(Error) }` + `var value: Value?`

- [ ] **Step 1: Write the failing test**

Create `PushTests/DataLayerTests.swift`:

```swift
import XCTest
@testable import Push

final class DataLayerTests: XCTestCase {

    func testPersonDerivesDisplayNameAndInitials() {
        let person = Person(id: "chitty", firstName: "chitty", imageAssetPath: "assets/friends/chitty.png")
        XCTAssertEqual(person.displayName, "Chitty")
        XCTAssertEqual(person.initials, "CH")
    }

    func testFriendGroupDerivesInitials() {
        let group = FriendGroup(id: "michigan", name: "Michigan", imageAssetPath: nil)
        XCTAssertEqual(group.initials, "M")
    }

    func testAvailabilityStateIsCodable() throws {
        let data = try JSONEncoder().encode(FriendAvailabilityState.freeNow)
        let decoded = try JSONDecoder().decode(FriendAvailabilityState.self, from: data)
        XCTAssertEqual(decoded, .freeNow)
    }

    func testLoadStateExposesLoadedValue() {
        XCTAssertEqual(LoadState.loaded(3).value, 3)
        XCTAssertNil(LoadState<Int>.loading.value)
    }
}
```

Register: `python3 scripts/pbxproj_add.py --target tests DataLayerTests.swift`

- [ ] **Step 2: Run tests, expect failure (types missing)**

Run the test command from Global Constraints. Expected: compile FAILS with "cannot find 'Person' in scope". (If the simctl blocker applies, `build-for-testing` shows the same compile failure.)

- [ ] **Step 3: Implement the domain files**

`Push/Data/Domain/Person.swift`:

```swift
import Foundation

/// Canonical person. IDs are stable and opaque: seed IDs are readable slugs
/// for convenience, production IDs will be UUID/ULID/database IDs. Never
/// derive identity from display names outside the seed file.
struct Person: Identifiable, Codable, Equatable {
    let id: String
    let firstName: String
    let imageAssetPath: String?

    var displayName: String {
        firstName.prefix(1).uppercased() + firstName.dropFirst()
    }

    var initials: String {
        String(firstName.prefix(2)).uppercased()
    }
}
```

`Push/Data/Domain/FriendGroup.swift`:

```swift
import Foundation

/// Canonical friend group. Member lists and counts derive from
/// `GroupMembership` rows — never stored here.
struct FriendGroup: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let imageAssetPath: String?

    var initials: String {
        name.split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
```

`Push/Data/Domain/GroupMembership.swift`:

```swift
import Foundation

struct GroupMembership: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case owner, member }
    enum SharingLevel: String, Codable { case full, availabilityOnly, hidden }
    enum Status: String, Codable { case active, invited, left }

    let id: String
    let personID: Person.ID
    let groupID: FriendGroup.ID
    let role: Role
    let sharingLevel: SharingLevel
    let membershipStatus: Status
    let joinedAt: Date
}
```

`Push/Data/Domain/Place.swift`:

```swift
import CoreLocation
import Foundation

struct Place: Identifiable, Codable, Equatable {
    let id: String
    /// Full venue name, e.g. "Crunch Fitness".
    let name: String
    /// Compact name used on pucks, e.g. "Crunch".
    let shortName: String
    /// Street-level label, e.g. "350 Bay St".
    let address: String
    /// Neighborhood-level label used when location visibility is `vague`.
    let vagueLabel: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

`Push/Data/Domain/PresenceStatus.swift`:

```swift
import Foundation

struct PresenceActivity: Codable, Equatable {
    let name: String
    let symbolName: String
}

/// Canonical internal presence — what Push knows. Exactly one per person.
/// UI never consumes this directly; it consumes `VisiblePresence` after
/// sharing-policy resolution.
struct PresenceStatus: Identifiable, Codable, Equatable {
    enum Confidence: String, Codable { case high, medium, low }
    enum Source: String, Codable { case seed, location, manualOverride, inference }

    let id: String
    let personID: Person.ID
    let availability: FriendAvailabilityState
    let activity: PresenceActivity
    let placeID: Place.ID?
    let statusNote: String?
    let confidence: Confidence
    let observedAt: Date
    let updatedAt: Date
    let expiresAt: Date?
    let source: Source
}
```

`Push/Data/Domain/SharingPolicy.swift`:

```swift
import Foundation

/// What does person A share with person B in context C.
/// Resolution order: friend-specific → group → globalDefault.
struct SharingPolicy: Identifiable, Codable, Equatable {
    enum AudienceType: String, Codable { case friend, group, globalDefault }
    enum LocationVisibility: String, Codable { case exact, vague, hidden }
    enum DetailVisibility: String, Codable { case full, vague, hidden }
    enum AvailabilityVisibility: String, Codable { case full, hidden }

    let id: String
    let ownerPersonID: Person.ID
    let audienceType: AudienceType
    let audienceID: String?
    let locationVisibility: LocationVisibility
    let activityVisibility: DetailVisibility
    let availabilityVisibility: AvailabilityVisibility
    let expiresAt: Date?
}
```

`Push/Data/Domain/PushPlan.swift`:

```swift
import Foundation

/// Canonical coordination object. User-facing copy calls these "Pushes".
struct PushPlan: Identifiable, Codable, Equatable {
    enum State: String, Codable { case collecting, locked, happening }
    enum Audience: String, Codable { case group, inviteesOnly }

    let id: String
    let title: String
    let groupID: FriendGroup.ID
    let creatorID: Person.ID
    let createdAt: Date
    let updatedAt: Date
    let startsAt: Date
    /// false → timing renders as day only ("Saturday").
    let hasExplicitTime: Bool
    /// true → timing renders with "~" prefix.
    let isApproximateTime: Bool
    let expiresAt: Date
    let cancelledAt: Date?
    let placeID: Place.ID
    /// true → location renders as "Suggested: {place}".
    let placeIsSuggested: Bool
    let state: State
    let audience: Audience
}
```

`Push/Data/Domain/PushResponse.swift`:

```swift
import Foundation

struct PushResponse: Identifiable, Codable, Equatable {
    enum Response: String, Codable { case `in`, maybe, out, pending }
    enum ReadyState: String, Codable { case readyNow, readyLater, needsRide, notReady, unknown }

    let id: String
    let pushID: PushPlan.ID
    let personID: Person.ID
    let response: Response
    let respondedAt: Date?
    let readyState: ReadyState
}
```

`Push/Data/Domain/PastHangout.swift`:

```swift
import Foundation

/// Recorded fact: a hangout that happened (or almost happened).
/// Calendar aggregates derive from these rows.
struct PastHangout: Identifiable, Codable, Equatable {
    let id: String
    let date: Date
    let participantIDs: [Person.ID]
    let note: String
    let timeRange: String
    let cameFromPush: Bool
    let didHappen: Bool
}
```

`Push/Data/Domain/FeedEvent.swift`:

```swift
import Foundation

/// Materialized read model generated from canonical facts (presence, plans,
/// responses). Seeded manually for now; generated once a feed UI exists.
struct FeedEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case arrived, becameFree, groupForming, pushCreated }

    let id: String
    let kind: Kind
    let actorIDs: [Person.ID]
    let placeID: Place.ID?
    let groupID: FriendGroup.ID?
    let timestamp: Date
}
```

`Push/Data/Domain/UserProfile.swift`:

```swift
import Foundation

/// Current-user profile and settings. Privacy toggles here are backed by the
/// user's SharingPolicy rows where the two overlap.
struct UserProfile: Codable, Equatable {
    let personID: Person.ID
    let handle: String
    /// The status the user picked on the profile screen (Set Status cards).
    let chosenAvailability: FriendAvailabilityState
    let visibilityNote: String
    let availabilityOptions: [ProfileAvailabilityOption]
    let activityVisibility: [ProfileToggleItem]
    let mapPreferences: [ProfileToggleItem]
    let closeFriends: [ProfileToggleItem]
    let connectors: [ProfileConnector]
}
```

`Push/Data/LoadState.swift`:

```swift
import Foundation

/// Lightweight loading/error state for view-model content. The local data
/// layer never fails, but the seam supports it so a real backend won't
/// retrofit loading UX onto every screen.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
```

Modify `Push/PuckModels.swift:10` — change the declaration line only:

```swift
enum FriendAvailabilityState: String, Codable, CaseIterable, Equatable {
```

Modify `Push/ProfileModels.swift` — add `Codable` to three structs:

```swift
struct ProfileAvailabilityOption: Identifiable, Equatable, Codable {
struct ProfileToggleItem: Identifiable, Equatable, Codable {
struct ProfileConnector: Identifiable, Equatable, Codable {
```

Register the app files:

```bash
python3 scripts/pbxproj_add.py \
  Data/Domain/Person.swift Data/Domain/FriendGroup.swift Data/Domain/GroupMembership.swift \
  Data/Domain/Place.swift Data/Domain/PresenceStatus.swift Data/Domain/SharingPolicy.swift \
  Data/Domain/PushPlan.swift Data/Domain/PushResponse.swift Data/Domain/PastHangout.swift \
  Data/Domain/FeedEvent.swift Data/Domain/UserProfile.swift Data/LoadState.swift
```

- [ ] **Step 4: Run tests, expect pass**

Run the test command (or build-for-testing fallback). Expected: PASS / compiles clean.

- [ ] **Step 5: Commit**

```bash
git add Push/Data PushTests/DataLayerTests.swift Push/PuckModels.swift Push/ProfileModels.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add canonical domain entities and LoadState"
```

---

### Task 3: SeedData

**Files:**
- Create: `Push/Data/Seed/SeedData.swift`, `Push/Data/Seed/SeedData+History.swift`
- Test: append to `PushTests/DataLayerTests.swift`

**Interfaces:**
- Produces: `struct SeedData` with properties `people: [Person]`, `currentUserID: String` (= `"manav"`), `groups: [FriendGroup]`, `memberships: [GroupMembership]`, `places: [Place]`, `statuses: [PresenceStatus]`, `policies: [SharingPolicy]`, `plans: [PushPlan]`, `responses: [PushResponse]`, `hangouts: [PastHangout]`, `feedEvents: [FeedEvent]`, `profile: UserProfile`; factory `static func standard(now: Date = Date()) -> SeedData`.

Content rules (canonical versions per the approved spec, "map wins"):
- 10 friends (`chitty, ishan, nitin, ohm, pranay, ram, roh, rohan, ryan, viplove`) + current user `manav` (image `assets/profile/manav.jpeg`).
- Groups: india (chitty, nitin, ishan, viplove, roh), exec (ram, ohm, manav), michigan (ram, rohan, ryan, ohm, pranay). First member listed is `role: .owner`, rest `.member`; all `sharingLevel: .full`, `membershipStatus: .active`, `joinedAt: now - 90 days`.
- 8 places: blue-bottle ("Blue Bottle"/"Blue Bottle"/"315 Linden St"/"Hayes Valley"/37.7812,-122.4078), dolores-park ("Dolores Park"/"Dolores"/"19th St & Dolores St"/"Mission"/37.7596,-122.4269), dolores-lawn ("Dolores Park Lawn"/"Dolores"/"Dolores Park, 19th St"/"Mission"/37.7673,-122.4358), souvla ("Souvla"/"Souvla"/"517 Hayes St"/"Hayes Valley"/37.7765,-122.4231), crunch ("Crunch Fitness"/"Crunch"/"350 Bay St"/"North Beach"/37.7898,-122.4210), north-park ("North Park"/"North Park"/"North Park"/"North Park"/37.7700,-122.4100), little-italy ("Little Italy"/"Little Italy"/"Columbus Ave"/"North Beach"/37.7997,-122.4098), rams-place ("Ram's place"/"Ram's place"/"Ram's place"/"Nob Hill"/37.7920,-122.4150).
- One status per person. **Ram is only at Crunch** (the documented fix — he was in two places). Statuses (availability, activity/symbol, place, note, updatedAt offset):
  chitty (freeNow, Coffee/cup.and.saucer.fill, blue-bottle, nil, −3 min) · nitin (maybeDown, Park/leaf.fill, dolores-park, "Near Dolores", −8 min) · ishan (freeNow, Lunch/fork.knife, souvla, nil, 0) · viplove (joinable, Lunch/fork.knife, souvla, "With Ishan", 0) · rohan (joinable, Park/leaf.fill, dolores-lawn, "Walking over", −5 min) · ryan (maybeDown, Park/leaf.fill, dolores-lawn, "Free in 20", −5 min) · pranay (freeSoon, Park/leaf.fill, dolores-lawn, "Maybe pulling up", −5 min) · ram (maybeDown, Gym/dumbbell.fill, crunch, "Wrapping up", −12 min) · ohm (busy, Gym/dumbbell.fill, crunch, "With Ram", −12 min) · manav (maybeDown, Gym/dumbbell.fill, crunch, "With Ram & Ohm", 0) · roh (unavailable, Off/moon.zzz.fill, no place, nil, −60 min).
  All: `confidence: .high, source: .seed, observedAt = updatedAt, expiresAt: nil`.
- Policies: one `globalDefault` per person (11 rows), all `exact`/`full`/`full`, `expiresAt: nil` — full visibility so today's screens render unchanged.
- Plans (all `audience: .group`, `cancelledAt: nil`, `createdAt = now − 1h`, `updatedAt = now`, `expiresAt = startsAt + 6h`):
  food-tonight ("Food tonight?", michigan, creator ram, today 20:00, hasExplicitTime, not approx, north-park suggested, .collecting) · gym-later ("Gym later", exec, creator manav, today 19:45, hasExplicitTime, **approx**, crunch, .locked) · coffee ("Coffee?", india, creator chitty, now − 5 min, hasExplicitTime, not approx, blue-bottle, .happening) · drinks-friday ("Drinks Friday?", michigan, creator manav, next Friday 21:00, hasExplicitTime, not approx, little-italy suggested, .collecting) · poker-night ("Poker night", exec, creator ram, next Saturday 19:00, **hasExplicitTime false**, not approx, rams-place, .collecting).
- Responses (id `"{pushID}-{personID}"`, `respondedAt = now − 30 min` when not pending, `readyState: .unknown`):
  food-tonight: rohan/ryan/pranay `.in`, ram/ohm `.maybe`, manav `.pending` → "3 in · 2 maybe", my pill Pending.
  gym-later: chitty/ishan/viplove/ram `.in`, manav `.in` → "4 going", my pill Joined. (Responders outside the Exec group are a retained quirk of today's content.)
  coffee: chitty `.in`, ishan `.maybe`, manav `.maybe` → "Chitty is there · Ishan maybe", my pill Open.
  drinks-friday: rohan/ryan `.in`, pranay `.maybe`, manav `.pending` → "2 in · 1 maybe", my pill Pending.
  poker-night: ram `.in`, ohm `.maybe`, manav `.out` → "Ram in · Ohm maybe", my pill Waiting.
- Hangouts (SeedData+History): replicate today's `hangoutPatterns` for the current month exactly (days 3, 5, 6, 10, 11, 12, 17, 18, 22, 23 with the same participants/notes/durations), with `cameFromPush: true` on the first entry of days 5, 11, 12, 23 and `didHappen: true`; plus two `didHappen: false` rows on days 14 and 25 (note "Almost happened", timeRange "", cameFromPush false).
- Feed events: chitty `.arrived` blue-bottle; ishan+viplove `.groupForming` souvla (india); rohan+ryan+pranay `.groupForming` dolores-lawn (michigan); chitty `.pushCreated` (coffee, india, blue-bottle); ram `.pushCreated` (food-tonight, michigan, north-park). Timestamps `now − 3…45 min`.
- Profile: personID manav, handle "@manav", chosenAvailability `.maybeDown`, visibilityNote "Visible to close friends for the next few hours.", availabilityOptions/toggles/connectors copied verbatim from today's `ProfileMockData` (`Push/ProfileMockData.swift:11-74`).

- [ ] **Step 1: Write the failing integrity tests** (append to `PushTests/DataLayerTests.swift`)

```swift
    // MARK: - Seed integrity

    func testSeedReferentialIntegrity() {
        let seed = SeedData.standard()
        let personIDs = Set(seed.people.map(\.id))
        let groupIDs = Set(seed.groups.map(\.id))
        let placeIDs = Set(seed.places.map(\.id))
        let planIDs = Set(seed.plans.map(\.id))

        XCTAssertTrue(personIDs.contains(seed.currentUserID))
        for membership in seed.memberships {
            XCTAssertTrue(personIDs.contains(membership.personID), membership.id)
            XCTAssertTrue(groupIDs.contains(membership.groupID), membership.id)
        }
        for status in seed.statuses {
            XCTAssertTrue(personIDs.contains(status.personID), status.id)
            if let placeID = status.placeID { XCTAssertTrue(placeIDs.contains(placeID), status.id) }
        }
        for plan in seed.plans {
            XCTAssertTrue(groupIDs.contains(plan.groupID), plan.id)
            XCTAssertTrue(personIDs.contains(plan.creatorID), plan.id)
            XCTAssertTrue(placeIDs.contains(plan.placeID), plan.id)
        }
        for response in seed.responses {
            XCTAssertTrue(planIDs.contains(response.pushID), response.id)
            XCTAssertTrue(personIDs.contains(response.personID), response.id)
        }
        for hangout in seed.hangouts {
            for pid in hangout.participantIDs { XCTAssertTrue(personIDs.contains(pid), hangout.id) }
        }
        for event in seed.feedEvents {
            for pid in event.actorIDs { XCTAssertTrue(personIDs.contains(pid), event.id) }
        }
    }

    func testSeedHasExactlyOneStatusPerPerson() {
        let seed = SeedData.standard()
        let statusPersonIDs = seed.statuses.map(\.personID)
        XCTAssertEqual(statusPersonIDs.count, Set(statusPersonIDs).count)
        XCTAssertEqual(Set(statusPersonIDs), Set(seed.people.map(\.id)))
    }

    func testSeedPoliciesAreFullVisibilityDefaults() {
        let seed = SeedData.standard()
        XCTAssertEqual(Set(seed.policies.map(\.ownerPersonID)), Set(seed.people.map(\.id)))
        XCTAssertTrue(seed.policies.allSatisfy { $0.audienceType == .globalDefault })
        XCTAssertTrue(seed.policies.allSatisfy { $0.locationVisibility == .exact })
    }

    func testSeedRamIsOnlyAtCrunch() {
        let seed = SeedData.standard()
        let ram = seed.statuses.filter { $0.personID == "ram" }
        XCTAssertEqual(ram.count, 1)
        XCTAssertEqual(ram.first?.placeID, "crunch")
    }
```

- [ ] **Step 2: Run tests, expect compile failure** (`cannot find 'SeedData'`).

- [ ] **Step 3: Implement `SeedData.swift` and `SeedData+History.swift`** following the content rules above. Skeleton for `SeedData.swift` (fill every array per the rules — no omissions):

```swift
import Foundation

struct SeedData {
    let currentUserID: Person.ID
    let people: [Person]
    let groups: [FriendGroup]
    let memberships: [GroupMembership]
    let places: [Place]
    let statuses: [PresenceStatus]
    let policies: [SharingPolicy]
    let plans: [PushPlan]
    let responses: [PushResponse]
    let hangouts: [PastHangout]
    let feedEvents: [FeedEvent]
    let profile: UserProfile

    static func standard(now: Date = Date()) -> SeedData {
        let people = standardPeople()
        return SeedData(
            currentUserID: "manav",
            people: people,
            groups: standardGroups(),
            memberships: standardMemberships(now: now),
            places: standardPlaces(),
            statuses: standardStatuses(now: now),
            policies: people.map { person in
                SharingPolicy(
                    id: "policy-\(person.id)-default",
                    ownerPersonID: person.id,
                    audienceType: .globalDefault,
                    audienceID: nil,
                    locationVisibility: .exact,
                    activityVisibility: .full,
                    availabilityVisibility: .full,
                    expiresAt: nil
                )
            },
            plans: standardPlans(now: now),
            responses: standardResponses(now: now),
            hangouts: standardHangouts(now: now),
            feedEvents: standardFeedEvents(now: now),
            profile: standardProfile()
        )
    }

    private static func friend(_ slug: String) -> Person {
        Person(id: slug, firstName: slug, imageAssetPath: "assets/friends/\(slug).png")
    }

    private static func standardPeople() -> [Person] {
        [
            friend("chitty"), friend("ishan"), friend("nitin"), friend("ohm"),
            friend("pranay"), friend("ram"), friend("roh"), friend("rohan"),
            friend("ryan"), friend("viplove"),
            Person(id: "manav", firstName: "manav", imageAssetPath: "assets/profile/manav.jpeg")
        ]
    }
    // … standardGroups(), standardMemberships(now:), standardPlaces(),
    //   standardStatuses(now:), standardPlans(now:), standardResponses(now:),
    //   standardProfile() per the content rules table above.

    /// Next occurrence of a weekday (1 = Sunday … 7 = Saturday) at hour:minute.
    static func next(weekday: Int, hour: Int, minute: Int, after now: Date) -> Date {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        return Calendar.current.nextDate(
            after: now, matching: components, matchingPolicy: .nextTime
        ) ?? now
    }

    /// Today at hour:minute (may be in the past late at night — acceptable for a prototype seed).
    static func today(hour: Int, minute: Int, relativeTo now: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
}
```

`SeedData+History.swift` holds `standardHangouts(now:)` (build dates with `Calendar.current.date(bySetting day…)` on the current month, exactly today's `hangoutPatterns` content from `Push/PlansModels.swift:144-203`) and `standardFeedEvents(now:)`. Keep each file under 400 lines — that is why history is split out.

Register: `python3 scripts/pbxproj_add.py Data/Seed/SeedData.swift Data/Seed/SeedData+History.swift`

- [ ] **Step 4: Run tests, expect pass.**

- [ ] **Step 5: Commit**

```bash
git add Push/Data/Seed PushTests/DataLayerTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: add centralized normalized seed data"
```

---

### Task 4: InMemoryDatabase, repositories, AppDataContainer

**Files:**
- Create: `Push/Data/Store/InMemoryDatabase.swift`, `Push/Data/Repositories/Repositories.swift`, `Push/Data/Repositories/LocalRepositories.swift`, `Push/Data/AppDataContainer.swift`
- Test: append to `PushTests/DataLayerTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor final class InMemoryDatabase` — `init(seed: SeedData)`; dictionaries `people: [String: Person]`, `groupsByID: [String: FriendGroup]`, `memberships: [GroupMembership]`, `placesByID: [String: Place]`, `statusesByPersonID: [String: PresenceStatus]`, `policies: [SharingPolicy]`, `plansByID: [String: PushPlan]`, `responses: [PushResponse]`, `hangouts: [PastHangout]`, `feedEvents: [FeedEvent]`, `profile: UserProfile`, `currentUserID: String`, plus arrays preserving seed order: `orderedPeople: [Person]`, `orderedGroups: [FriendGroup]`, `orderedPlans: [PushPlan]`; mutation `func setResponse(pushID: String, personID: String, response: PushResponse.Response, at date: Date)`.
  - Protocols (all methods `async throws`):
    ```swift
    protocol FriendRepository {
        func friends() async throws -> [Person]          // excludes current user, seed order
        func currentUser() async throws -> Person
        func presenceStatuses() async throws -> [PresenceStatus]
    }
    protocol GroupRepository {
        func groups() async throws -> [FriendGroup]
        func memberships() async throws -> [GroupMembership]
    }
    protocol PushRepository {
        func activePlans() async throws -> [PushPlan]    // cancelledAt == nil, seed order
        func responses() async throws -> [PushResponse]
        func setCurrentUserResponse(planID: String, response: PushResponse.Response) async throws
        func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout]
    }
    protocol ProfileRepository { func userProfile() async throws -> UserProfile }
    protocol SharingRepository { func allPolicies() async throws -> [SharingPolicy] }
    protocol FeedRepository { func events() async throws -> [FeedEvent] }
    ```
  - `Local*Repository` `@MainActor` classes wrapping the database (never throw).
  - `@MainActor final class AppDataContainer` — `static let shared = AppDataContainer(seed: .standard())`; `let database`, `let friends: FriendRepository`, `let groups: GroupRepository`, `let pushes: PushRepository`, `let profile: ProfileRepository`, `let sharing: SharingRepository`, `let feed: FeedRepository`, `var currentUserID: String`, `let referenceDate: Date`.
  - Test fake: `ThrowingFriendRepository` (in tests) proving the failure path compiles and drives `LoadState.failed`.

- [ ] **Step 1: Write failing tests** (append to `DataLayerTests.swift`; mark the class `@MainActor` and make these methods `async`):

```swift
    func testRepositoriesServeSeededData() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertEqual(friends.count, 10)
        XCTAssertFalse(friends.contains { $0.id == "manav" })
        let user = try await container.friends.currentUser()
        XCTAssertEqual(user.id, "manav")
        let groups = try await container.groups.groups()
        XCTAssertEqual(groups.map(\.id), ["india", "exec", "michigan"])
        let plans = try await container.pushes.activePlans()
        XCTAssertEqual(plans.count, 5)
    }

    func testSetCurrentUserResponseUpsertsRow() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.pushes.setCurrentUserResponse(planID: "food-tonight", response: .in)
        let responses = try await container.pushes.responses()
        let mine = responses.first { $0.pushID == "food-tonight" && $0.personID == "manav" }
        XCTAssertEqual(mine?.response, .in)
    }
```

- [ ] **Step 2: Run tests, expect compile failure.**

- [ ] **Step 3: Implement.** `InMemoryDatabase` builds dictionaries from the seed in `init` (`Dictionary(uniqueKeysWithValues:)` — the integrity tests guarantee uniqueness). `setResponse` replaces or appends the `(pushID, personID)` row with `respondedAt = date`, `readyState: .unknown` (or `.pending` → `respondedAt = nil`). `LocalPushRepository.setCurrentUserResponse` calls it with `database.currentUserID`. `AppDataContainer`:

```swift
import Foundation

@MainActor
final class AppDataContainer {
    static let shared = AppDataContainer(seed: .standard())

    let database: InMemoryDatabase
    let friends: FriendRepository
    let groups: GroupRepository
    let pushes: PushRepository
    let profile: ProfileRepository
    let sharing: SharingRepository
    let feed: FeedRepository
    let referenceDate: Date

    var currentUserID: String { database.currentUserID }

    init(seed: SeedData, referenceDate: Date = Date()) {
        let database = InMemoryDatabase(seed: seed)
        self.database = database
        self.referenceDate = referenceDate
        self.friends = LocalFriendRepository(database: database)
        self.groups = LocalGroupRepository(database: database)
        self.pushes = LocalPushRepository(database: database)
        self.profile = LocalProfileRepository(database: database)
        self.sharing = LocalSharingRepository(database: database)
        self.feed = LocalFeedRepository(database: database)
    }
}
```

Register: `python3 scripts/pbxproj_add.py Data/Store/InMemoryDatabase.swift Data/Repositories/Repositories.swift Data/Repositories/LocalRepositories.swift Data/AppDataContainer.swift`

- [ ] **Step 4: Run tests, expect pass.**
- [ ] **Step 5: Commit** — `feat: add in-memory database, async repositories, and data container`

---

### Task 5: VisiblePresence + policy resolution

**Files:**
- Create: `Push/Data/Derived/VisiblePresence.swift`
- Test: create `PushTests/DerivationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct VisiblePresence: Equatable {
      struct VisiblePlaceInfo: Equatable {
          let place: Place
          let isVague: Bool
          var displayName: String { isVague ? place.vagueLabel : place.shortName }
      }
      let person: Person
      let availability: FriendAvailabilityState?
      let activity: PresenceActivity?
      let statusNote: String?
      let placeInfo: VisiblePlaceInfo?
      let updatedAt: Date
      let isCurrentUser: Bool
  }
  enum VisiblePresenceBuilder {
      static func resolvedPolicy(ownerID: String, viewerID: String, sharedGroupIDs: Set<String>, policies: [SharingPolicy], now: Date) -> SharingPolicy?
      static func visiblePresence(of status: PresenceStatus, owner: Person, viewerID: String, sharedGroupIDs: Set<String>, policies: [SharingPolicy], placesByID: [String: Place], now: Date) -> VisiblePresence?
  }
  ```
- Rules: owner == viewer → sees everything. No resolvable policy or `availabilityVisibility == .hidden` → returns nil (off the board). `activityVisibility`: vague → drop statusNote; hidden → drop activity + note. `locationVisibility`: vague → `isVague: true`; hidden → no place. Specificity: friend > group (any shared group) > globalDefault; expired policies skipped.

- [ ] **Step 1: Write failing tests** — `PushTests/DerivationTests.swift` (register with `--target tests`). Cover: full-default policy passes everything through; hidden availability removes the person; vague location flips `isVague` and `displayName` returns `vagueLabel`; hidden activity drops activity and note; friend-specific policy beats globalDefault; expired friend policy falls back to default; self always sees exact. Use inline fixtures (one Person, one Place, one PresenceStatus, policies per case) — do not depend on SeedData here.
- [ ] **Step 2: Run tests, expect compile failure.**
- [ ] **Step 3: Implement** per the interface block (single file, ~90 lines).
- [ ] **Step 4: Run tests, expect pass.**
- [ ] **Step 5: Commit** — `feat: add viewer-scoped visible presence with sharing-policy resolution`

---

### Task 6: Map puck derivation

**Files:**
- Create: `Push/Data/Derived/MapContentBuilder.swift`, `Push/Data/Derived/RelativeTimeFormatter.swift`
- Modify: `Push/PuckModels.swift:94-141` (`FriendPuckData.id` becomes `String`, default `UUID().uuidString`)
- Modify: `Push/MapPuckModels.swift:18-43` (add `groupIDs: [String]` with default `[]`)
- Test: append to `PushTests/DerivationTests.swift`

**Interfaces:**
- Consumes: `VisiblePresence`, domain entities, `MapPuckData`/`FriendPuckData` presentation structs.
- Produces:
  - `RelativeTimeFormatter.label(for date: Date, now: Date, isCurrentUser: Bool) -> String` — current user → `"Now"`; < 1 min → `"Just now"`; else `"\(minutes) min ago"`.
  - `MapContentBuilder.pucks(presences: [VisiblePresence], groups: [FriendGroup], memberships: [GroupMembership], now: Date) -> [MapPuckData]`.
- Derivation rules (must reproduce today's map exactly, minus the Ram fix):
  - Only presences with `placeInfo != nil && isVague == false && availability != nil` produce pins. Group by `placeInfo.place.id`; order members by seed order (order of appearance in `presences`), current user last.
  - Kind: 1 → `.individual`; 2 → `.hangout`; ≥3 → `.friendGroup` if member ID set == active-membership set of some group, else `.cluster`.
  - Puck availability: single → the person's availability; multi → `.joinable` (being together is what makes them joinable — this keeps groups-screen canonical availabilities like ohm `.busy` intact).
  - Puck `venueStatusText`: individual → `statusNote ?? "At \(shortName)"`; hangout/friendGroup → `"At \(shortName)"`; cluster → `"Group forming near \(shortName)"`.
  - Member `FriendPuckData`: `id` = person id; `activityDisplayText` = place `shortName`; `venueStatusText` = `statusNote ?? "At \(shortName)"`; `lastUpdated` via `RelativeTimeFormatter`; `withWhom` = other members' `displayName`s (nil when alone); `locationLabel` = place `address`; `placeName` = place `name`; `availability` = `.joinable` in multi pucks, else own.
  - `.friendGroup` pucks prepend a group-avatar entry: `id: "group-\(group.id)"`, name = group name, initials, `profileImageAssetName` = group image, symbol `"person.3.fill"`, `venueStatusText: "\(group.name) is together"`.
  - Puck `id` = `"puck-\(placeID)"`; `coordinate` = place coordinate; `groupIDs`: individual → owner's group memberships; multi → groups containing **all** members; `groups` (legacy field) → `[]`.

- [ ] **Step 1: Write failing tests** (append to `DerivationTests.swift`) — build presences from `SeedData.standard()` + full-visibility policies via `VisiblePresenceBuilder`, then assert:

```swift
    func testMapBuilderReproducesCurrentPuckMix() { /* 5 pucks: 2 individual, 1 hangout, 1 cluster, 1 friendGroup */ }
    func testClusterIsRohanRyanPranayAfterRamFix() { /* puck-dolores-lawn people names == ["Rohan", "Ryan", "Pranay"] */ }
    func testFriendGroupPuckMatchesExecWithGroupAvatarFirst() { /* puck-crunch kind .friendGroup, first entry id "group-exec", current user last */ }
    func testPuckVenueTextsMatchToday() { /* "At Blue Bottle", "Near Dolores", "At Souvla", "Group forming near Dolores", "At Crunch" */ }
    func testMultiPersonPucksDeriveJoinable() { /* all multi pucks availability == .joinable */ }
    func testGroupTagsFilterLikeToday() { /* india tags on 3 pucks, michigan 1, exec 1 */ }
    func testWithWhomDerivesFromCoLocation() { /* viplove's withWhom == ["Ishan"] */ }
```

- [ ] **Step 2: Run tests, expect compile failure.**
- [ ] **Step 3: Implement.** In `Push/PuckModels.swift` change only the `id` property and init parameter:

```swift
    let id: String
    // in init signature:
    id: String = UUID().uuidString,
```

In `Push/MapPuckModels.swift` add the field with a default so `MapPuckMockData` keeps compiling until the deletion sweep:

```swift
    let groupIDs: [String]
    // add to == : && lhs.groupIDs == rhs.groupIDs
```

Give `MapPuckData` an explicit memberwise `init` with `groupIDs: [String] = []` so existing call sites in `MapPuckMockData` need no edits. Implement the two new files per the rules. Register: `python3 scripts/pbxproj_add.py Data/Derived/VisiblePresence.swift Data/Derived/MapContentBuilder.swift Data/Derived/RelativeTimeFormatter.swift` (VisiblePresence if not yet registered in Task 5).
- [ ] **Step 4: Run tests, expect pass. Run full build.**
- [ ] **Step 5: Commit** — `feat: derive map pucks from canonical presence`

---

### Task 7: Group derivations

**Files:**
- Create: `Push/Data/Derived/GroupContentBuilder.swift`
- Test: append to `PushTests/DerivationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum GroupContentBuilder {
      static func groupCards(groups: [FriendGroup], memberships: [GroupMembership], statuses: [String: PresenceStatus], plans: [PushPlan], now: Date) -> [PushGroupData]
      static func members(groupID: String, memberships: [GroupMembership], people: [String: Person], statuses: [String: PresenceStatus]) -> [PushGroupMemberData]
  }
  ```
- Rules: memberIDs/memberCount from active memberships (india 5, exec 3, michigan 5). `activeNowCount` = members co-located with ≥2 people (india 2, exec 3, michigan 5). `nearbyCount` = members with a place but solo (india 2, exec 0, michigan 0). `planCount` = non-cancelled plans per group (india 1, exec 2, michigan 2). Badge priority: `.planLive` if any `.collecting` plan starts today → michigan; else `.activeNow` if activeNowCount ≥ 2 → india, exec; else `.nearby` if nearbyCount ≥ 1; else `.freeSoon` if any member `.freeSoon`; else `.quiet`. Member rows use **canonical** availability (`statuses[personID]?.availability`) — nitin becomes `.maybeDown` (documented change; the old table said `.joinable` and contradicted the map).

- [ ] **Step 1: Write failing tests** asserting exactly the values above from `SeedData.standard()`.
- [ ] **Step 2: Run, expect compile failure.**
- [ ] **Step 3: Implement** (`python3 scripts/pbxproj_add.py Data/Derived/GroupContentBuilder.swift`).
- [ ] **Step 4: Run tests, expect pass.**
- [ ] **Step 5: Commit** — `feat: derive group cards, stats, and member rows from canonical data`

---

### Task 8: Push plans + calendar derivations

**Files:**
- Create: `Push/Data/Derived/PlansContentBuilder.swift`, `Push/Data/Derived/PushTimingFormatter.swift`
- Test: append to `PushTests/DerivationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PushTimingFormatter {
      static func label(for plan: PushPlan, now: Date) -> String
  }
  enum PlansContentBuilder {
      static func planData(plans: [PushPlan], responses: [PushResponse], groupsByID: [String: FriendGroup], placesByID: [String: Place], peopleByID: [String: Person], currentUserID: String, now: Date) -> [PlanData]
      static func calendarDays(hangouts: [PastHangout], peopleByID: [String: Person], month: Date) -> [CalendarDayData]
      static func mostActiveGroup(hangouts: [PastHangout], memberships: [GroupMembership], groupsByID: [String: FriendGroup]) -> String
  }
  ```
- Timing rules: `.happening` or `startsAt <= now` → `"now"`; `!hasExplicitTime` → weekday name (`"Saturday"`); same day → `"h:mm a"` with `"~"` prefix when approximate (`"~7:45 PM"`); else `"EEEE, h:mm a"` (`"Friday, 9:00 PM"`).
- Social proof (counts exclude the current user): happening + 1 in → `"{Name} is there"` (+ `" · {Name} maybe"` if exactly 1 maybe); 1 in + 1 maybe → `"{In} in · {Maybe} maybe"`; 0 maybe → `"{n} going"`; else `"{n} in · {m} maybe"`. Reproduces all five of today's strings exactly.
- Pill mapping from my response: pending → `.pending`, in → `.joined`, maybe → `.open`, out → `.waiting`. `isOwner` = `creatorID == currentUserID`. `participants` = `.in` responders excluding the current user, as `HangoutPerson`. `locationHint` = `placeIsSuggested ? "Suggested: \(place.name)" : place.name`.
- Calendar: group hangouts by day; `hangouts` (entries) = `didHappen` rows mapped to `DayHangoutEntry` (note → `activityNote`, timeRange → `duration`); `pushCount` = didHappen count; `hadPlan` = any `cameFromPush`; `almostHappened` = any `!didHappen`. `mostActiveGroup` = group whose members appear most across didHappen hangouts (ties → seed order) — must return `"Michigan"`.

- [ ] **Step 1: Write failing tests**: five exact `timeSignal` strings, five exact `socialProof` strings, pills `[.pending, .joined, .open, .pending, .waiting]`, owners `gym-later`/`drinks-friday`, gym-later participants count 4, drinks-friday 2, calendar day 5 has 3 entries/pushCount 3/hadPlan true, day 14 almostHappened true with 0 entries, `mostActiveGroup == "Michigan"`.
- [ ] **Step 2: Run, expect compile failure.**
- [ ] **Step 3: Implement** (`python3 scripts/pbxproj_add.py Data/Derived/PlansContentBuilder.swift Data/Derived/PushTimingFormatter.swift`). Keep `PlansContentBuilder` under 400 lines by extracting the social-proof formatter as a private enum inside the file.
- [ ] **Step 4: Run tests, expect pass.**
- [ ] **Step 5: Commit** — `feat: derive push cards, social proof, and calendar from canonical data`

---

### Task 9: MapViewModel + ContentView rewire

**Files:**
- Create: `Push/MapViewModel.swift`
- Modify: `Push/ContentView.swift:12-24` (state + filtering), `Push/ContentView.swift:169-270` (dropdown types)
- Test: append to `PushTests/DerivationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct GroupFilterItem: Identifiable, Equatable {
      static let allFriendsID = "all"
      let id: String
      let title: String
  }
  @MainActor final class MapViewModel: ObservableObject {
      @Published private(set) var loadState: LoadState<[MapPuckData]>
      @Published private(set) var filters: [GroupFilterItem]   // ["All Friends", "India", "Exec", "Michigan"]
      @Published var selectedFilterID: String                  // defaults to allFriendsID
      init(container: AppDataContainer = .shared)
      func load() async
      var filteredPucks: [MapPuckData] { get }
  }
  ```
- `load()` sets `.loading`, pulls repositories, computes shared-group IDs per friend from memberships, builds `VisiblePresence` per status (viewer = current user), then `MapContentBuilder.pucks`, sets `.loaded`. Wrap repository calls in `do/catch` → `.failed(error)`. `init` fires `Task { await load() }`. `filteredPucks`: `selectedFilterID == allFriendsID` → all, else `pucks.filter { $0.groupIDs.contains(selectedFilterID) }`.

- [ ] **Step 1: Write failing tests**: `MapViewModel(container:)` + `await vm.load()` → 5 pucks loaded; filters titles `["All Friends", "India", "Exec", "Michigan"]`; setting `selectedFilterID = "india"` → 3 filtered pucks; a `ThrowingFriendRepository` fake (define in test file, all methods `throw URLError(.badServerResponse)`) drives `loadState` to `.failed` (add an `init(container:friendsOverride:)` seam or construct a container-like init taking repositories — simplest: `init(friends: FriendRepository, groups: GroupRepository, sharing: SharingRepository, currentUserID: String, referenceDate: Date)` as the designated init, with the `container` convenience init delegating to it).
- [ ] **Step 2: Run, expect compile failure.**
- [ ] **Step 3: Implement `MapViewModel.swift`** (`python3 scripts/pbxproj_add.py MapViewModel.swift`) and rewire `ContentView`:
  - Replace `@State private var selectedFriendGroup: FriendGroupFilter = .allFriends` and the `filteredPucks` computed property (lines 14, 19-24) with `@StateObject private var viewModel = MapViewModel()`; `StyledMapView(pucks: viewModel.filteredPucks, …)`.
  - `FriendGroupDropdown(selectedGroup: $selectedFriendGroup)` → `FriendGroupDropdown(items: viewModel.filters, selectedID: $viewModel.selectedFilterID)`.
  - `FriendGroupDropdown`/`FriendGroupDropdownRow` (lines 169-270): swap `FriendGroupFilter` for `GroupFilterItem` — `Binding<String> selectedID`, `ForEach(items)`, `selectedGroup.title` → `items.first { $0.id == selectedID }?.title ?? "All Friends"`, row compares `item.id == selectedID`. Do NOT delete the `FriendGroupFilter` enum yet (MapPuckMockData still references it until Task 14).
- [ ] **Step 4: Run tests + full app build, expect pass.**
- [ ] **Step 5: Commit** — `feat: drive map screen from MapViewModel and dynamic group filters`

---

### Task 10: GroupsViewModel rewire

**Files:**
- Modify: `Push/GroupsModels.swift:49-91` (`GroupsViewModel`)
- Modify: `Push/GroupDetailView.swift:324-328` (preview)
- Test: rewrite `PushTests/GroupsTests.swift`

**Interfaces:**
- Produces: `GroupsViewModel` gains designated `init(container: AppDataContainer = .shared)` that fires `Task { await load() }`; `func load() async` builds cards via `GroupContentBuilder.groupCards` and a `membersByGroupID: [String: [PushGroupMemberData]]` via `GroupContentBuilder.members`; `@Published private(set) var loadState: LoadState<[PushGroupData]>`; `members(for:)` reads the dictionary. Keep `init(groups: [PushGroupData])` as a preview/test seam (sets `.loaded`, empty members). Selection/detail methods unchanged.

- [ ] **Step 1: Rewrite `PushTests/GroupsTests.swift`** — same test intents, correct derived values, async where loading:

```swift
import XCTest
@testable import Push

@MainActor
final class GroupsTests: XCTestCase {

    private func loadedViewModel() async -> GroupsViewModel {
        let viewModel = GroupsViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        return viewModel
    }

    func testGroupCardsDeriveFromCanonicalData() async throws {
        let viewModel = await loadedViewModel()
        XCTAssertEqual(viewModel.groups.map(\.name), ["India", "Exec", "Michigan"])
        XCTAssertEqual(viewModel.groups.map(\.memberCount), [5, 3, 5])
        XCTAssertEqual(viewModel.groups.map(\.status), [.activeNow, .activeNow, .planLive])
        XCTAssertEqual(viewModel.groups.map(\.activeNowCount), [2, 3, 5])
        XCTAssertEqual(viewModel.groups.map(\.nearbyCount), [2, 0, 0])
        XCTAssertEqual(viewModel.groups.map(\.planCount), [1, 2, 2])
    }

    func testGroupMembersUseCanonicalAvailability() async throws {
        let viewModel = await loadedViewModel()
        let india = try XCTUnwrap(viewModel.groups.first)
        let members = viewModel.members(for: india)
        XCTAssertEqual(members.map(\.name), ["Chitty", "Nitin", "Ishan", "Viplove", "Roh"])
        XCTAssertEqual(members.first { $0.id == "nitin" }?.availability, .maybeDown)
        XCTAssertEqual(members.first { $0.id == "ohm" }?.availability, nil) // ohm not in india
    }

    func testGroupsViewModelSelectionAndDetail() async throws {
        let viewModel = await loadedViewModel()
        let michigan = try XCTUnwrap(viewModel.groups.last)
        XCTAssertEqual(viewModel.selectedGroupID, "india")
        viewModel.select(michigan)
        XCTAssertEqual(viewModel.selectedGroupID, "michigan")
        viewModel.openDetail(for: michigan)
        XCTAssertEqual(viewModel.presentedGroupID, "michigan")
        viewModel.closeDetail()
        XCTAssertNil(viewModel.presentedGroupID)
    }
}
```

- [ ] **Step 2: Run, expect failure** (no `init(container:)`, wrong derived values).
- [ ] **Step 3: Implement** the view model changes; update the `GroupDetailView` preview to a hardcoded fixture (`PushGroupData(id: "india", name: "India", memberCount: 5, memberIDs: [], status: .activeNow, activeNowCount: 2, nearbyCount: 2, planCount: 1, imageAssetName: nil, fallbackSymbol: "I", fallbackInitials: "I")` with `members: []`). `GroupsMockData`/`SeededGroupFriends` stay untouched until Task 14 (StartPush still uses them).
- [ ] **Step 4: Run tests + build, expect pass.**
- [ ] **Step 5: Commit** — `feat: load groups screen through repositories and derived stats`

---

### Task 11: PlansViewModel rewire

**Files:**
- Modify: `Push/PlansViewModel.swift` (full rewrite below)
- Modify: `PushTests/PlansViewModelTests.swift` (async loading + seed-derived expectations)

**Interfaces:**
- Produces:
  ```swift
  @MainActor final class PlansViewModel: ObservableObject {
      @Published private(set) var loadState: LoadState<[PlanData]>
      // existing published properties and computed vars keep their names:
      // plans, calendarDays, monthLabel, totalPushesThisMonth, mostActiveGroup,
      // yourPushes, activePushes, activeCount, needsResponseCount,
      // plansNeedingResponse, sortedPlans, selectedDay, isReviewDeckPresented,
      // isStartPushPresented, isYourPushesPresented, managedPlan,
      // openManage(plan:), respond(to:with:)
      init(container: AppDataContainer = .shared, referenceDate: Date = Date())
      init(plans: [PlanData], referenceDate: Date = Date())   // preview/test seam, no repo writes
      func load() async
  }
  ```
- `respond(to:with:)` maps right → `.in`, left → `.out`, up → `.maybe`; updates the local `plans` pill exactly as today (`.joined`/`.waiting`/`.open`) synchronously, then `Task { try? await container?.pushes.setCurrentUserResponse(…) }` writes through when a container exists. `totalPushesThisMonth` = sum of derived `pushCount`. `monthLabel` unchanged.

- [ ] **Step 1: Update `PlansViewModelTests.swift`.** Keep all pure-logic tests (sorting, needsResponse, respond, managedPlan) on the `init(plans:)` seam — they compile unchanged. Replace the three data-driven tests:

```swift
    @MainActor
    func testSeededPlansMatchTodayContent() async throws {
        let vm = PlansViewModel(container: AppDataContainer(seed: .standard()))
        await vm.load()
        XCTAssertEqual(vm.plans.map(\.id), ["food-tonight", "gym-later", "coffee", "drinks-friday", "poker-night"])
        XCTAssertEqual(vm.plans.map(\.status), [.pending, .joined, .open, .pending, .waiting])
        XCTAssertEqual(vm.plans.map(\.socialProof), [
            "3 in · 2 maybe", "4 going", "Chitty is there · Ishan maybe", "2 in · 1 maybe", "Ram in · Ohm maybe"
        ])
        XCTAssertEqual(vm.yourPushes.map(\.id), ["gym-later", "drinks-friday"])
        XCTAssertEqual(vm.yourPushes.first?.participants.count, 4)
        XCTAssertEqual(vm.mostActiveGroup, "Michigan")
    }

    @MainActor
    func testCalendarDerivesFromHangouts() async throws {
        let vm = PlansViewModel(container: AppDataContainer(seed: .standard()))
        await vm.load()
        XCTAssertEqual(vm.calendarDays.count,
                       Calendar.current.range(of: .day, in: .month, for: Date())?.count)
        XCTAssertEqual(vm.totalPushesThisMonth, 19)
        let day14 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 14 }
        XCTAssertEqual(day14?.almostHappened, true)
        XCTAssertEqual(day14?.hangouts.count, 0)
    }
```

Also update `testActiveCount_matchesInvitedPlans`, `testMonthLabel_matchesCurrentMonth`, `testCalendarDays_countMatchesDaysInMonth`, `testTotalPushesThisMonth_sumsPushCounts`, `testYourPushes_ownedPlansHaveParticipants` to use the seam or the container per above (delete duplicates the two new tests replace). Remove `PlansMockData` references.

- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement the view model rewrite.** `load()` reads `pushes.activePlans()/responses()/pastHangouts(…)`, `groups.groups()`, `friends`, places via `container.database.placesByID` — no: keep the view model repository-only. Add `func places() async throws -> [Place]` to `PushRepository`? No — add `placesByID` exposure via a small `func allPlaces() async throws -> [Place]` on `PushRepository` (plans reference places). Update `Repositories.swift`/`LocalRepositories.swift` accordingly in this task. Then build `PlanData` via `PlansContentBuilder`.
- [ ] **Step 4: Run tests + build, expect pass.**
- [ ] **Step 5: Commit** — `feat: load pushes screen through repositories with derived cards and calendar`

---

### Task 12: ProfileViewModel rewire

**Files:**
- Create: `Push/Data/Derived/ProfileContentBuilder.swift`
- Modify: `Push/ProfileViewModel.swift:26-38` (init + load)
- Test: profile tests in `PushTests/PushTests.swift:227-390` updated

**Interfaces:**
- Produces:
  ```swift
  enum ProfileContentBuilder {
      static func profileData(profile: UserProfile, person: Person, presence: VisiblePresence?) -> ProfileData
  }
  ```
  - `placeTitle` derives from presence: `"Near \(place.vagueLabel)"` (soft-places preference is on) → **"Near North Beach"** (documented change from the stored "Near Hayes Valley", which contradicted the map). `availability` = `profile.chosenAvailability`; `activityTitle` = its `.title`; name/initials/image from `Person`.
  - `ProfileViewModel` gains `init(container: AppDataContainer = .shared)` + `func load() async` + `@Published private(set) var loadState: LoadState<ProfileData>`; keeps `init(profile: ProfileData)` seam. `load()` populates the same published fields the seam init sets today (`Push/ProfileViewModel.swift:26-38`).

- [ ] **Step 1: Update the profile tests** — `testProfileMockDataExposesCurrentUserIdentity` becomes `testProfileDataDerivesFromCanonicalUser` (async, loads via container, asserts name "Manav", initials "MK", handle "@manav", image `assets/profile/manav.jpeg`, availability `.maybeDown`, activityTitle "Maybe down", **placeTitle "Near North Beach"**, visibilityNote unchanged); `testProfileMockDataExposesAvailabilityOptions` loads the same way (options `[.freeNow, .maybeDown, .busy]`, statusOptions titles incl. Ghost Mode). Behavior tests (`select`, ghost mode, routes, toggles, connectors) keep the `init(profile:)`/default-init seam — change default `ProfileViewModel()` construction to `await` a loaded container VM where they asserted seeded content; pure-behavior ones stay sync by constructing `ProfileViewModel(profile:)` with a locally-built `ProfileData` fixture.
- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement** builder + view-model init (`python3 scripts/pbxproj_add.py Data/Derived/ProfileContentBuilder.swift`). `ProfileMockData` stays until Task 14.
- [ ] **Step 4: Run tests + build, expect pass.**
- [ ] **Step 5: Commit** — `feat: derive profile screen from canonical user and presence`

---

### Task 13: StartPush rewire

**Files:**
- Modify: `Push/StartPushModels.swift:24-115` (`StartPushViewModel`)
- Modify: `Push/StartPushStep4View.swift:10-11,66-117` (suggested-responder rows)
- Test: append to `PushTests/DerivationTests.swift`

**Interfaces:**
- Produces: `StartPushViewModel` gains `init(container: AppDataContainer = .shared)` firing `Task { await load() }`; `groups`/`friends` become `@Published private(set) var` built in `load()` from `GroupRepository`/`FriendRepository` (same `PushRecipientItem` mapping as today, `id` prefixes `group_`/`friend_` unchanged); new published `likelyFreeNow: [PushRecipientItem]` (canonical availability `.freeNow` or `.joinable`) and `mightBeInterested: [PushRecipientItem]` (`.maybeDown` or `.freeSoon`); `func recipient(withFriendID id: String) -> PushRecipientItem?`.
- `StartPushStep4View`: delete the hardcoded `likelyFreeIDs`/`mightBeInterestedIDs` (lines 10-11); `responseCard` uses `viewModel.likelyFreeNow` / `viewModel.mightBeInterested` with derived counts (`"\(items.count) likely free now"` etc.) and `RecipientAvatarView(imageAssetName: item.imageAssetName, initials: item.initials, …)`. Documented change: counts become 4/4 (previously hardcoded 3/5) and derive from availability.

- [ ] **Step 1: Write failing tests**: loaded `StartPushViewModel` has 3 groups + 10 friends; `likelyFreeNow` ids == `["friend_chitty", "friend_ishan", "friend_rohan", "friend_viplove"]` (seed order); `mightBeInterested` ids == `["friend_nitin", "friend_pranay", "friend_ram", "friend_ryan"]`; `toggleRecipient`/`primaryRecipientLabel` behavior unchanged.
- [ ] **Step 2: Run, expect failure.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests + build, expect pass.**
- [ ] **Step 5: Commit** — `feat: drive Start Push recipients and suggestions from repositories`

---

### Task 14: PuckLab fixtures made self-contained

**Files:**
- Modify: `Push/PuckModels.swift:178-377` (rename `PuckLabMockData` → `PuckLabFixtures`, add local factory)
- Modify: `Push/PuckLabView.swift:42` (`PuckLabFixtures.scenarios`)
- Modify: `PushTests/PushTests.swift:102-175` (references)

**Interfaces:**
- Produces: `enum PuckLabFixtures { static let scenarios; static let singleFriendScenarios }` — design-lab fixtures, intentionally NOT part of the data layer (they cover edge cases the seed doesn't).

- [ ] **Step 1: Rename and inline the factory.** Replace every `RealWorldMockData.friendPuck("slug", …)` call with a private local helper inside the fixtures enum:

```swift
private static func labFriend(
    _ firstName: String,
    activity: String,
    symbolName: String,
    displayText: String,
    availability: FriendAvailabilityState,
    venueStatusText: String
) -> FriendPuckData {
    FriendPuckData(
        name: firstName.prefix(1).uppercased() + firstName.dropFirst(),
        avatarPlaceholder: String(firstName.prefix(2)).uppercased(),
        profileImageAssetName: "assets/friends/\(firstName).png",
        activity: activity,
        activitySymbolName: symbolName,
        activityDisplayText: displayText,
        availability: availability,
        venueStatusText: venueStatusText
    )
}
```

and the one `groupPuck("india", …)` call with an inline `FriendPuckData(name: "India", avatarPlaceholder: "I", profileImageAssetName: "assets/groups/India/chitty.png", activity: "Gym", activitySymbolName: "person.3.fill", activityDisplayText: "Crunch", availability: .joinable, venueStatusText: "India is together")`. Update `PuckLabView.swift:42` and the test references (`PuckLabMockData` → `PuckLabFixtures`).
- [ ] **Step 2: Run tests + build, expect pass.**
- [ ] **Step 3: Commit** — `refactor: make PuckLab fixtures self-contained design fixtures`

---

### Task 15: Delete the old mock layer

**Files:**
- Delete: `Push/RealWorldMockData.swift`, `Push/ProfileMockData.swift`
- Modify: `Push/MapPuckModels.swift` (delete `MapPuckMockData` enum + legacy `groups: [FriendGroupFilter]` field), `Push/MainMapModels.swift:10-29` (delete `FriendGroupFilter`), `Push/GroupsModels.swift:93-158` (delete `GroupsMockData` + `SeededGroupFriends`), `Push/PlansModels.swift:69-247` (delete `PlansMockData`)
- Modify: `PushTests/PushTests.swift` (delete/replace stale tests), `Push.xcodeproj/project.pbxproj` (remove the two deleted file references — delete their PBXBuildFile, PBXFileReference, group child, and Sources entries by matching the file name)

- [ ] **Step 1: Delete in one sweep.** Also remove from `PushTests/PushTests.swift`: `testFriendGroupFiltersExposeMockDropdownOptions` (48-55), `testMapPuckMockDataContainsRequiredPuckMix` (192-202), `testMapPuckMockDataUsesAvailableAssetNames` (204-225), `testMapPuckMockDataExposesGroupTags` (392-399), `testGroupFilterReturnsPucksForSelectedGroup` (401-416), and the two `ProfileMockData` content tests if not already rewritten in Task 12. Their intents are covered by `DerivationTests` (puck mix, group tags, filtering) and Task 12's profile tests. Add one asset-path test to `DerivationTests`:

```swift
    func testSeedImageAssetPathsMatchBundledAssets() {
        let seed = SeedData.standard()
        let expected = Set(seed.people.compactMap(\.imageAssetPath) + seed.groups.compactMap(\.imageAssetPath))
        XCTAssertTrue(expected.contains("assets/friends/chitty.png"))
        XCTAssertTrue(expected.contains("assets/profile/manav.jpeg"))
        XCTAssertTrue(expected.contains("assets/groups/Exec/ram.png"))
        XCTAssertTrue(expected.allSatisfy { $0.hasPrefix("assets/") })
    }
```

- [ ] **Step 2: Grep for stragglers.**

Run: `grep -rn "RealWorldMockData\|ProfileMockData\|MapPuckMockData\|GroupsMockData\|SeededGroupFriends\|PlansMockData\|FriendGroupFilter\|PuckLabMockData" Push PushTests`
Expected: no matches.

- [ ] **Step 3: Run tests + full build, expect pass.**
- [ ] **Step 4: Commit** — `refactor: delete scattered mock data enums in favor of the data layer`

---

### Task 16: Documentation + final validation

**Files:**
- Create: `docs/data-architecture.md`
- Modify: `tasks/todo.md` (append a completed section), `tasks/lessons.md` (only if new gotchas surfaced)

- [ ] **Step 1: Write `docs/data-architecture.md`** covering:
  - Layer map (Domain → Seed → Store → Repositories → Container → view-model builders → views) with file paths.
  - How to add: a person, group + memberships, place, presence status, sharing policy, push + responses, past hangout, feed event (each: which SeedData function, required fields, integrity tests that guard it).
  - Derivation rules reference (puck grouping/kind, joinable-when-together, social proof, timing labels, group stats/badges, calendar aggregates, visible-presence resolution).
  - **Documented content changes** vs. the old mocks: (1) Ram single location — Dolores cluster is now Rohan/Ryan/Pranay; (2) nitin groups-screen availability joinable → maybeDown; (3) exec group badge nearby → activeNow and group stats now derive (india 2/2/1, exec 3/0/2, michigan 5/0/2); (4) profile placeTitle "Near Hayes Valley" → "Near North Beach"; (5) Step-4 suggested-responder counts 3/5 → 4/4, derived from availability; (6) `withWhom` now includes everyone co-located (e.g. Ram's includes Manav); (7) member ordering in pucks is deterministic seed order.
  - Supabase swap path: implement the six repository protocols against Supabase tables mirroring the domain structs; seed becomes SQL migrations; `AppDataContainer` swaps implementations; view models and views untouched.
- [ ] **Step 2: Final validation.** Run the full build and the test suite (or build-for-testing fallback). Launch check if the environment allows: `scripts/run-ios-sim.sh` (see repo scripts) and confirm map, Pushes, Groups, Profile, Start Push render with seeded data.
- [ ] **Step 3: Update `tasks/todo.md`** with a "Data architecture standardization (issue #15)" completed checklist and any verification caveats (e.g. simctl blocker).
- [ ] **Step 4: Commit** — `docs: document the local data architecture and seed workflow`

---

## Self-Review Results

- **Spec coverage:** entities (T2), identity language (T2 comments), seed + corrections (T3), store/repos/container + async throws (T4), LoadState (T2, wired T9-13), visible presence + policy resolution (T5), derivations (T6-8), view-model/UI rewires incl. the two view-layer leaks (T9-13), PuckLab fixtures (T14), deletions (T15), tests throughout, docs + Supabase path (T16). Feed events: modeled + seeded (T2/T3), read via `FeedRepository` (T4) — no UI, per spec.
- **Type consistency:** `PushRepository.allPlaces()` added in Task 11 — flagged there explicitly. `FriendPuckData.id` default keeps old call sites compiling until their deletion.
- **Ordering:** every commit keeps the build green; shared mocks die only after their last consumer is rewired (T15).
