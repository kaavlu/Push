# Stable Local App-State Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Push's stable product actions (create a push, respond, edit profile/status/privacy) mutate shared local state through the existing repository seam, with cross-screen refresh.

**Architecture:** `InMemoryDatabase` becomes an `ObservableObject` that bumps a `revision` counter after every mutation; view models observe it and reload idempotently. Start Push and profile/status/privacy edits gain atomic store mutations behind new repository methods. No Supabase/auth/networking; extend the current local data layer only.

**Tech Stack:** Swift, SwiftUI, Combine, MVVM, XCTest, MapKit. iOS 17+.

## Global Constraints

- MVVM strictly: ViewModels own state/logic; Views stay dumb.
- Mock everything — no real network/location. All data via the local data layer.
- Files ≤ 400 lines; functions ≤ 40 lines, single responsibility.
- No magic numbers — named constants only. Comments explain WHY.
- All store mutation and revision publishing happen on `@MainActor` (single serialized path). Revision is emitted ONLY after mutations, never during load/read. Reads never write back to the store.
- Feed slice is OUT of scope (no Feed screen, no feed-event writes). Ghost Mode stays UI-only.
- Register every new `.swift` file: app target `python3 scripts/pbxproj_add.py <path-relative-to-Push>`; test target `python3 scripts/pbxproj_add.py --target tests <name>`.
- Run tests: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO`. If the runner drops (`DTXProxyChannel`/`-308`): `xcrun simctl shutdown all` then kill `CoreSimulatorService`.
- Commit after each task. Do NOT add `[skip ci]` (that flag is only for auto-generated doc commits).

---

## File Structure

- `Push/Data/Store/InMemoryDatabase.swift` — add `ObservableObject` + `revision` + `didMutate()`; new atomic `createPush`, `updatePerson`, `updateProfile`, `setAvailability` mutations.
- `Push/Data/AppDataContainer.swift` — expose `storeRevision` + `onStoreChange` helper.
- `Push/Data/Domain/PushPlan.swift` — `groupID`/`placeID` optional; add `locationText`.
- `Push/Data/Seed/SeedData+Plans.swift` — seed builder passes `locationText: nil`.
- `Push/Data/Derived/PlansContentBuilder.swift` — handle nil `groupID`/`placeID`.
- `Push/Data/Repositories/Repositories.swift` — new protocol methods + `PushDraft`.
- `Push/Data/Repositories/LocalRepositories.swift` — implement new methods (recipient mapping).
- `Push/StartPushModels.swift` — `StartPushViewModel.submit()`.
- `Push/StartPushFlowView.swift` — call `submit()` when advancing 3→4.
- `Push/ProfileViewModel.swift` — write-through on basics/availability/toggles.
- `Push/PlansViewModel.swift`, `Push/ProfileViewModel.swift`, `Push/GroupsModels.swift`, `Push/MapViewModel.swift`, `Push/FriendsViewModel.swift` — subscribe to `onStoreChange` and reload.
- Tests: `PushTests/DataLayerTests.swift` (store/repo write paths), `PushTests/PlansViewModelTests.swift` (refresh).

---

## Task 1: Store revision broadcaster

**Files:**
- Modify: `Push/Data/Store/InMemoryDatabase.swift`
- Modify: `Push/Data/AppDataContainer.swift`
- Test: `PushTests/DataLayerTests.swift`

**Interfaces:**
- Consumes: existing `InMemoryDatabase(seed:)`, `AppDataContainer(seed:)`.
- Produces:
  - `InMemoryDatabase: ObservableObject`, `@Published private(set) var revision: Int` (starts 0), `private func didMutate()` (increments `revision`). Existing `setResponse(...)` now calls `didMutate()` at its end.
  - `AppDataContainer.storeRevision: Int` (reads `database.revision`).
  - `AppDataContainer.onStoreChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable` — fires on each post-mutation revision change.

- [ ] **Step 1: Write the failing test**

Add to `PushTests/DataLayerTests.swift`:

```swift
@MainActor
func test_setResponse_bumpsRevision() throws {
    let container = AppDataContainer(seed: .standard())
    let before = container.storeRevision
    container.database.setResponse(
        pushID: "food-tonight",
        personID: container.currentUserID,
        response: .in,
        at: Date()
    )
    XCTAssertEqual(container.storeRevision, before + 1)
}

@MainActor
func test_onStoreChange_firesAfterMutation() throws {
    let container = AppDataContainer(seed: .standard())
    var received: Int?
    let sub = container.onStoreChange { received = $0 }
    container.database.setResponse(
        pushID: "food-tonight",
        personID: container.currentUserID,
        response: .maybe,
        at: Date()
    )
    XCTAssertEqual(received, container.storeRevision)
    sub.cancel()
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests -parallel-testing-enabled NO`
Expected: FAIL — `storeRevision`/`onStoreChange` not members.

- [ ] **Step 3: Add revision + didMutate to the store**

In `Push/Data/Store/InMemoryDatabase.swift`, change the class declaration and add the counter. Update the class line:

```swift
final class InMemoryDatabase: ObservableObject {
    let currentUserID: Person.ID

    /// Bumped once after every mutation so view models can reload. Emitted only
    /// after a write completes — never during reads — to avoid reload loops.
    @Published private(set) var revision: Int = 0
```

Add this private method (place it just above `setResponse`):

```swift
    private func didMutate() {
        revision += 1
    }
```

At the end of `setResponse(...)`, after the `if let index ... else { responses.append(row) }` block, add:

```swift
        didMutate()
```

- [ ] **Step 4: Expose revision + change helper on the container**

In `Push/Data/AppDataContainer.swift`, add `import Combine` under `import Foundation`, and add these members inside the class (after `var currentUserID`):

```swift
    /// The store's current mutation revision.
    var storeRevision: Int { database.revision }

    /// Fires with the new revision after each store mutation. `dropFirst()`
    /// skips the initial published value so only real mutations notify.
    func onStoreChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable {
        database.$revision.dropFirst().sink(receiveValue: handler)
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests -parallel-testing-enabled NO`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Push/Data/Store/InMemoryDatabase.swift Push/Data/AppDataContainer.swift PushTests/DataLayerTests.swift
git commit -m "feat: store revision broadcaster for cross-screen refresh"
```

---

## Task 2: PushPlan optional group/place + locationText

**Files:**
- Modify: `Push/Data/Domain/PushPlan.swift`
- Modify: `Push/Data/Seed/SeedData+Plans.swift:68-85`
- Modify: `Push/Data/Derived/PlansContentBuilder.swift:29,33`
- Test: `PushTests/DerivationTests.swift`

**Interfaces:**
- Consumes: existing `PlansContentBuilder.planData(...)`.
- Produces: `PushPlan.groupID: FriendGroup.ID?`, `PushPlan.placeID: Place.ID?`, new `PushPlan.locationText: String?` (last stored property). Builder renders nil group as a neutral label and nil place via `locationText`.

- [ ] **Step 1: Write the failing test**

Add to `PushTests/DerivationTests.swift`:

```swift
func test_planData_handlesNilGroupAndPlace_usesLocationText() {
    let now = Date()
    let plan = PushPlan(
        id: "p1", title: "Coffee run", groupID: nil, creatorID: "me",
        createdAt: now, updatedAt: now, startsAt: now,
        hasExplicitTime: true, isApproximateTime: false,
        expiresAt: now.addingTimeInterval(3600), cancelledAt: nil,
        placeID: nil, placeIsSuggested: false, state: .collecting,
        audience: .inviteesOnly, note: nil, locationText: "Blue Bottle, Hayes"
    )
    let cards = PlansContentBuilder.planData(
        plans: [plan], responses: [], groupsByID: [:], placesByID: [:],
        peopleByID: [:], currentUserID: "me", now: now
    )
    XCTAssertEqual(cards.count, 1)
    XCTAssertEqual(cards[0].locationHint, "Blue Bottle, Hayes")
    XCTAssertEqual(cards[0].group, "")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DerivationTests -parallel-testing-enabled NO`
Expected: FAIL to compile — `PushPlan` has no `locationText`, `groupID`/`placeID` not optional.

- [ ] **Step 3: Make PushPlan fields optional + add locationText**

In `Push/Data/Domain/PushPlan.swift`, change the two properties and add one. Replace:

```swift
    let groupID: FriendGroup.ID
```

with:

```swift
    /// nil for friends-only (inviteesOnly) pushes with no backing group.
    let groupID: FriendGroup.ID?
```

Replace:

```swift
    let placeID: Place.ID
```

with:

```swift
    /// nil when the creator typed a free-text location instead of picking a Place.
    let placeID: Place.ID?
```

Add, immediately after the `note` property (keep it the last stored property):

```swift
    /// Free-text location captured by Start Push when placeID is nil.
    let locationText: String?
```

- [ ] **Step 4: Fix the seed builder**

In `Push/Data/Seed/SeedData+Plans.swift`, in the `PushPlan(` construction (ends around line 85), add `locationText: nil,` immediately after the `note: note` line:

```swift
            state: state,
            audience: .group,
            note: note,
            locationText: nil
        )
```

- [ ] **Step 5: Fix the builder to accept optional keys**

In `Push/Data/Derived/PlansContentBuilder.swift`, replace line 29:

```swift
            let place = placesByID[plan.placeID]
```

with:

```swift
            let place = plan.placeID.flatMap { placesByID[$0] }
```

Replace line 33:

```swift
                group: groupsByID[plan.groupID]?.name ?? plan.groupID,
```

with:

```swift
                group: plan.groupID.flatMap { groupsByID[$0]?.name } ?? "",
```

Replace line 39 (the `locationHint:` argument) to fall back to `locationText` when there is no place:

```swift
                locationHint: locationHint(
                    place: place, isSuggested: plan.placeIsSuggested,
                    fallback: plan.locationText
                ),
```

Then update the `locationHint` helper (starts line 68) to accept the fallback:

```swift
    private static func locationHint(place: Place?, isSuggested: Bool, fallback: String?) -> String {
        guard let place else { return fallback ?? "" }
        return isSuggested ? "Suggested: \(place.name)" : place.name
```

- [ ] **Step 6: Run the full suite to catch other PushPlan constructions**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO`
Expected: PASS. If any test file constructs `PushPlan(...)` directly, add `locationText: nil` as its final argument and re-run. (`GroupContentBuilder` comparisons like `plan.groupID == group.id` compile unchanged — Swift promotes the non-optional side.)

- [ ] **Step 7: Commit**

```bash
git add Push/Data/Domain/PushPlan.swift Push/Data/Seed/SeedData+Plans.swift Push/Data/Derived/PlansContentBuilder.swift PushTests/DerivationTests.swift
git commit -m "feat: optional group/place + free-text location on PushPlan"
```

---

## Task 3: Atomic createPush store mutation + repository

**Files:**
- Modify: `Push/Data/Store/InMemoryDatabase.swift`
- Modify: `Push/Data/Repositories/Repositories.swift`
- Modify: `Push/Data/Repositories/LocalRepositories.swift`
- Test: `PushTests/DataLayerTests.swift`

**Interfaces:**
- Consumes: `didMutate()` (Task 1); optional `PushPlan` fields (Task 2).
- Produces:
  - `InMemoryDatabase.createPush(plan: PushPlan, responses: [PushResponse])` — appends the plan to `plansByID` + `orderedPlans`, appends all `responses`, then `didMutate()` ONCE.
  - `struct PushDraft` (in `Repositories.swift`): `title: String`, `recipientIDs: Set<String>` (the flow's `group_<id>`/`friend_<id>` tokens), `startsAt: Date`, `locationText: String`, `notes: String`, `creatorID: Person.ID`.
  - `PushRepository.createPush(_ draft: PushDraft) async throws -> PushPlan.ID`.

- [ ] **Step 1: Write the failing tests**

Add to `PushTests/DataLayerTests.swift`:

```swift
@MainActor
func test_createPush_friendsOnly_insertsPlanAndPendingResponses() async throws {
    let container = AppDataContainer(seed: .standard())
    let me = container.currentUserID
    let friends = try await container.friends.friends()
    let a = friends[0].id
    let b = friends[1].id
    let draft = PushDraft(
        title: "Coffee run",
        recipientIDs: ["friend_\(a)", "friend_\(b)"],
        startsAt: Date(), locationText: "Blue Bottle", notes: "", creatorID: me
    )
    let id = try await container.pushes.createPush(draft)

    let plans = try await container.pushes.activePlans()
    let plan = try XCTUnwrap(plans.first { $0.id == id })
    XCTAssertNil(plan.groupID)
    XCTAssertEqual(plan.audience, .inviteesOnly)
    XCTAssertEqual(plan.locationText, "Blue Bottle")

    let responses = try await container.pushes.responses().filter { $0.pushID == id }
    let mine = responses.filter { $0.personID == me }
    XCTAssertEqual(mine.count, 1)
    XCTAssertEqual(mine.first?.response, .in)
    XCTAssertEqual(Set(responses.filter { $0.response == .pending }.map(\.personID)), [a, b])
    XCTAssertFalse(responses.contains { $0.personID == me && $0.response == .pending })
}

@MainActor
func test_createPush_singleGroup_setsGroupAudience() async throws {
    let container = AppDataContainer(seed: .standard())
    let groups = try await container.groups.groups()
    let group = groups[0]
    let draft = PushDraft(
        title: "Group hang", recipientIDs: ["group_\(group.id)"],
        startsAt: Date(), locationText: "", notes: "", creatorID: container.currentUserID
    )
    let id = try await container.pushes.createPush(draft)
    let plan = try XCTUnwrap(try await container.pushes.activePlans().first { $0.id == id })
    XCTAssertEqual(plan.groupID, group.id)
    XCTAssertEqual(plan.audience, .group)
}

@MainActor
func test_createPush_bumpsRevisionOnce() async throws {
    let container = AppDataContainer(seed: .standard())
    let before = container.storeRevision
    _ = try await container.pushes.createPush(PushDraft(
        title: "X", recipientIDs: ["friend_\(try await container.friends.friends()[0].id)"],
        startsAt: Date(), locationText: "", notes: "", creatorID: container.currentUserID
    ))
    XCTAssertEqual(container.storeRevision, before + 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests -parallel-testing-enabled NO`
Expected: FAIL — `PushDraft` / `createPush` do not exist.

- [ ] **Step 3: Add the atomic store mutation**

In `Push/Data/Store/InMemoryDatabase.swift`, add after `setResponse(...)`:

```swift
    /// Atomic: inserts the plan and all its initial responses together, then
    /// notifies once, so no observer can see a plan without its responses.
    func createPush(plan: PushPlan, responses newResponses: [PushResponse]) {
        plansByID[plan.id] = plan
        orderedPlans.append(plan)
        self.responses.append(contentsOf: newResponses)
        didMutate()
    }
```

- [ ] **Step 4: Add PushDraft + protocol method**

In `Push/Data/Repositories/Repositories.swift`, add above `protocol PushRepository`:

```swift
/// Start Push flow output. `recipientIDs` are the flow's tokens
/// ("group_<id>" / "friend_<id>").
struct PushDraft {
    let title: String
    let recipientIDs: Set<String>
    let startsAt: Date
    let locationText: String
    let notes: String
    let creatorID: Person.ID
}
```

Inside `protocol PushRepository`, add:

```swift
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID
```

- [ ] **Step 5: Implement recipient mapping in the local repo**

In `Push/Data/Repositories/LocalRepositories.swift`, add to `LocalPushRepository` (after `setCurrentUserResponse`):

```swift
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID {
        let groupIDs = draft.recipientIDs.compactMap { token in
            token.hasPrefix("group_") ? String(token.dropFirst("group_".count)) : nil
        }
        let friendIDs = draft.recipientIDs.compactMap { token in
            token.hasPrefix("friend_") ? String(token.dropFirst("friend_".count)) : nil
        }
        let singleGroupOnly = groupIDs.count == 1 && friendIDs.isEmpty
        let planID = "push-\(UUID().uuidString)"
        let now = Date()

        // Invitees: selected friends plus members of any selected groups,
        // deduped, with the creator excluded (they get an explicit .in below).
        let groupMemberIDs = database.memberships
            .filter { $0.membershipStatus == .active && groupIDs.contains($0.groupID) }
            .map(\.personID)
        var invitees = Set(friendIDs).union(groupMemberIDs)
        invitees.remove(draft.creatorID)

        let plan = PushPlan(
            id: planID,
            title: draft.title,
            groupID: singleGroupOnly ? groupIDs[0] : nil,
            creatorID: draft.creatorID,
            createdAt: now,
            updatedAt: now,
            startsAt: draft.startsAt,
            hasExplicitTime: true,
            isApproximateTime: false,
            expiresAt: draft.startsAt.addingTimeInterval(CreatePushConstants.expiryWindow),
            cancelledAt: nil,
            placeID: nil,
            placeIsSuggested: false,
            state: .collecting,
            audience: singleGroupOnly ? .group : .inviteesOnly,
            note: draft.notes.isEmpty ? nil : draft.notes,
            locationText: draft.locationText.isEmpty ? nil : draft.locationText
        )

        let creatorResponse = PushResponse(
            id: "\(planID)-\(draft.creatorID)", pushID: planID,
            personID: draft.creatorID, response: .in,
            respondedAt: now, readyState: .unknown
        )
        let inviteeResponses = invitees.map { personID in
            PushResponse(
                id: "\(planID)-\(personID)", pushID: planID,
                personID: personID, response: .pending,
                respondedAt: nil, readyState: .unknown
            )
        }
        database.createPush(plan: plan, responses: [creatorResponse] + inviteeResponses)
        return planID
    }
```

Add this constant enum at the bottom of the file (outside any type):

```swift
private enum CreatePushConstants {
    /// Pushes expire six hours after their start, matching seed plans.
    static let expiryWindow: TimeInterval = 6 * 60 * 60
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests -parallel-testing-enabled NO`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Push/Data/Store/InMemoryDatabase.swift Push/Data/Repositories/Repositories.swift Push/Data/Repositories/LocalRepositories.swift PushTests/DataLayerTests.swift
git commit -m "feat: atomic createPush mutation with recipient mapping"
```

---

## Task 4: Start Push submits a real push

**Files:**
- Modify: `Push/StartPushModels.swift`
- Modify: `Push/StartPushFlowView.swift:33-34,92-95`
- Test: `PushTests/DataLayerTests.swift`

**Interfaces:**
- Consumes: `PushRepository.createPush(_:)` (Task 3).
- Produces: `StartPushViewModel.submit() async` — builds a `PushDraft` from published state and calls the repo; no-op when `container` is nil. `StartPushViewModel` exposes `currentUserID` via its container for the draft.

- [ ] **Step 1: Write the failing test**

Add to `PushTests/DataLayerTests.swift`:

```swift
@MainActor
func test_startPushViewModel_submit_createsPush() async throws {
    let container = AppDataContainer(seed: .standard())
    let vm = StartPushViewModel(container: container)
    await vm.load()
    let friend = try await container.friends.friends()[0]
    vm.pushText = "Taco night"
    vm.location = "El Farolito"
    vm.toggleRecipient("friend_\(friend.id)")

    let before = try await container.pushes.activePlans().count
    await vm.submit()
    let after = try await container.pushes.activePlans()
    XCTAssertEqual(after.count, before + 1)
    XCTAssertTrue(after.contains { $0.title == "Taco night" && $0.locationText == "El Farolito" })
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests/test_startPushViewModel_submit_createsPush -parallel-testing-enabled NO`
Expected: FAIL — `submit()` does not exist.

- [ ] **Step 3: Add submit() to the view model**

In `Push/StartPushModels.swift`, add to `StartPushViewModel` (after `editFromConfirmation()`):

```swift
    /// Submits the draft into shared local state. Called when the flow advances
    /// from step 3 to the confirmation step, so the push exists before step 4.
    func submit() async {
        guard let container, !hasSubmitted else { return }
        let draft = PushDraft(
            title: pushText.trimmingCharacters(in: .whitespacesAndNewlines),
            recipientIDs: selectedRecipientIDs,
            startsAt: selectedTime,
            locationText: location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            creatorID: container.currentUserID
        )
        do {
            _ = try await container.pushes.createPush(draft)
            hasSubmitted = true
        } catch {
            // Local repo never throws; a real backend would surface this.
        }
    }
```

Add the guard flag near the other stored `@Published` properties (it does not need to be published):

```swift
    private var hasSubmitted = false
```

- [ ] **Step 4: Trigger submit when advancing 3 → 4**

In `Push/StartPushFlowView.swift`, change the step-3 case (line ~33) to use a dedicated handler:

```swift
                    case 3:
                        StartPushStep3View(viewModel: viewModel, onNext: submitAndAdvance)
```

Add this method next to `advance()` (line ~92):

```swift
    private func submitAndAdvance() {
        movingForward = true
        Task {
            await viewModel.submit()
            viewModel.advance()
        }
    }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests/test_startPushViewModel_submit_createsPush -parallel-testing-enabled NO`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Push/StartPushModels.swift Push/StartPushFlowView.swift PushTests/DataLayerTests.swift
git commit -m "feat: Start Push flow submits a real push"
```

---

## Task 5: Cross-screen refresh subscription

**Files:**
- Modify: `Push/PlansViewModel.swift`
- Modify: `Push/ProfileViewModel.swift`
- Modify: `Push/GroupsModels.swift`
- Modify: `Push/MapViewModel.swift`
- Modify: `Push/FriendsViewModel.swift`
- Test: `PushTests/PlansViewModelTests.swift`

**Interfaces:**
- Consumes: `AppDataContainer.onStoreChange(_:)` + `storeRevision` (Task 1).
- Produces: each listed VM reloads via `load()` when the store mutates, guarded by `lastSeenRevision` so a matching revision does not double-reload.

**Pattern (apply per VM):** add `private var storeChangeSub: AnyCancellable?` and `private var lastSeenRevision = 0`; at the end of `load()` set `lastSeenRevision = container.storeRevision`; where the VM has its `container`, subscribe. Every listed VM already `import`s Combine except confirm each file does.

- [ ] **Step 1: Write the failing test**

Add to `PushTests/PlansViewModelTests.swift`:

```swift
@MainActor
func test_plansViewModel_reloadsWhenPushCreated() async throws {
    let container = AppDataContainer(seed: .standard())
    let vm = PlansViewModel(container: container)
    await vm.load()
    let before = vm.plans.count

    _ = try await container.pushes.createPush(PushDraft(
        title: "New hang",
        recipientIDs: ["friend_\(try await container.friends.friends()[0].id)"],
        startsAt: Date(), locationText: "", notes: "", creatorID: container.currentUserID
    ))
    // Let the change subscription's reload Task run.
    try await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertEqual(vm.plans.count, before + 1)
    XCTAssertTrue(vm.plans.contains { $0.title == "New hang" })
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/PlansViewModelTests/test_plansViewModel_reloadsWhenPushCreated -parallel-testing-enabled NO`
Expected: FAIL — `vm.plans.count` stays at `before` (no reload).

- [ ] **Step 3: Wire PlansViewModel**

In `Push/PlansViewModel.swift`, add stored properties near the top of the class:

```swift
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0
```

In the container-based `init` (the one taking `container: AppDataContainer = .shared`), after `Task { await load() }`, add:

```swift
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
```

At the end of `load()`, inside the `do` block after `loadState = .loaded(cards)`, add:

```swift
            lastSeenRevision = container.storeRevision
```

- [ ] **Step 4: Wire ProfileViewModel, GroupsViewModel (same shape)**

In `Push/ProfileViewModel.swift`: add the same two stored properties; in `init(container:)` after `Task { await load() }` add the same `storeChangeSub = container.onStoreChange { ... }` block; at the end of `load()` after `loadState = .loaded(data)` add `lastSeenRevision = container.storeRevision`.

In `Push/GroupsModels.swift` (`GroupsViewModel`): add the same two stored properties; in `init(container:)` after its `Task { await load() }` add the same subscription block; at the end of `load()`'s success path add `lastSeenRevision = container.storeRevision`. (`container` is `AppDataContainer?` here — the subscription block is already inside code where `container` is non-nil in the container init; if the init references `container` as optional, unwrap with `if let container` around the subscribe call.)

- [ ] **Step 5: Wire MapViewModel + FriendsViewModel (container in convenience init)**

`MapViewModel` and `FriendsViewModel` take individual repositories in their designated init and a container in a `convenience init`. Add to each class:

```swift
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0
```

In each `convenience init(container:)`, after `self.init(...)`, add:

```swift
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
```

In each `load()` success path, add `lastSeenRevision = container.storeRevision` — but these VMs hold repos, not a container. Instead track revision from the repo path is unavailable, so set it via the store indirectly: add a stored `private let storeRevisionProvider: () -> Int` defaulted to `{ 0 }`, set in the convenience init to `{ [weak database] in ... }`. SIMPLER: in the convenience init, also capture the container:

```swift
        self.containerForRefresh = container
```

Add `private let containerForRefresh: AppDataContainer?` initialized to `nil` in the designated init and set in the convenience init. Then in `load()` success add:

```swift
        lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
```

Confirm both files `import Combine` (add it if missing).

- [ ] **Step 6: Run the test + full suite**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO`
Expected: PASS (including the new reload test and all existing tests).

- [ ] **Step 7: Commit**

```bash
git add Push/PlansViewModel.swift Push/ProfileViewModel.swift Push/GroupsModels.swift Push/MapViewModel.swift Push/FriendsViewModel.swift PushTests/PlansViewModelTests.swift
git commit -m "feat: view models reload on store mutation"
```

---

## Task 6: Profile / status / privacy persistence

**Files:**
- Modify: `Push/Data/Store/InMemoryDatabase.swift`
- Modify: `Push/Data/Repositories/Repositories.swift`
- Modify: `Push/Data/Repositories/LocalRepositories.swift`
- Modify: `Push/ProfileViewModel.swift`
- Test: `PushTests/DataLayerTests.swift`

**Interfaces:**
- Consumes: `didMutate()` (Task 1); revision subscription (Task 5).
- Produces:
  - Store: `updatePerson(id:firstName:)`, `updateProfile(handle:activityVisibility:mapPreferences:closeFriends:)`, `setAvailability(_:)` — each applies its table edits then `didMutate()` once. `setAvailability` rewrites the current user's `PresenceStatus.availability` with `source: .manualOverride` and mirrors `UserProfile.chosenAvailability`.
  - `ProfileRepository.updateBasics(displayName:handle:)`, `ProfileRepository.updatePrivacy(activityVisibility:mapPreferences:closeFriends:)`.

> **Person model note:** `Person` stores only `firstName` + `imageAssetPath`; `displayName` and `initials` are COMPUTED (`firstName.prefix(1).uppercased() + dropFirst`, and `firstName.prefix(2).uppercased()`). So profile-basics persistence updates `firstName` (from the typed display name); typed initials are ignored because they derive.
  - `FriendRepository.setCurrentUserAvailability(_:)`.
  - `ProfileViewModel` save actions write through the repos.

- [ ] **Step 1: Write the failing tests**

Add to `PushTests/DataLayerTests.swift`:

```swift
@MainActor
func test_setAvailability_persistsToPresenceAndProfile() async throws {
    let container = AppDataContainer(seed: .standard())
    try await container.friends.setCurrentUserAvailability(.freeNow)
    let status = try await container.friends.presenceStatuses()
        .first { $0.personID == container.currentUserID }
    XCTAssertEqual(status?.availability, .freeNow)
    XCTAssertEqual(status?.source, .manualOverride)
    let profile = try await container.profile.userProfile()
    XCTAssertEqual(profile.chosenAvailability, .freeNow)
}

@MainActor
func test_updateBasics_persistsFirstNameAndHandle() async throws {
    let container = AppDataContainer(seed: .standard())
    try await container.profile.updateBasics(displayName: "Manny", handle: "@manny")
    let user = try await container.friends.currentUser()
    // displayName is computed from firstName.
    XCTAssertEqual(user.displayName, "Manny")
    XCTAssertEqual(try await container.profile.userProfile().handle, "@manny")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests -parallel-testing-enabled NO`
Expected: FAIL — methods do not exist.

- [ ] **Step 3: Add store mutations**

In `Push/Data/Store/InMemoryDatabase.swift`, add after `createPush(...)`. (`Person` stores only `id`/`firstName`/`imageAssetPath`; `displayName`/`initials` are computed. Construct a fresh copy with the new `firstName`.):

```swift
    func updatePerson(id: Person.ID, firstName: String) {
        guard let existing = peopleByID[id] else { return }
        let updated = Person(
            id: existing.id, firstName: firstName, imageAssetPath: existing.imageAssetPath
        )
        peopleByID[id] = updated
        if let index = orderedPeople.firstIndex(where: { $0.id == id }) {
            orderedPeople[index] = updated
        }
        didMutate()
    }

    func updateProfile(
        handle: String,
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) {
        profile = UserProfile(
            personID: profile.personID, handle: handle,
            chosenAvailability: profile.chosenAvailability,
            visibilityNote: profile.visibilityNote,
            availabilityOptions: profile.availabilityOptions,
            activityVisibility: activityVisibility,
            mapPreferences: mapPreferences,
            closeFriends: closeFriends,
            connectors: profile.connectors
        )
        didMutate()
    }

    func setAvailability(_ availability: FriendAvailabilityState) {
        if let status = statusesByPersonID[currentUserID] {
            statusesByPersonID[currentUserID] = PresenceStatus(
                id: status.id, personID: status.personID, availability: availability,
                activity: status.activity, placeID: status.placeID,
                statusNote: status.statusNote, confidence: status.confidence,
                observedAt: status.observedAt, updatedAt: Date(),
                expiresAt: status.expiresAt, source: .manualOverride
            )
        }
        profile = UserProfile(
            personID: profile.personID, handle: profile.handle,
            chosenAvailability: availability, visibilityNote: profile.visibilityNote,
            availabilityOptions: profile.availabilityOptions,
            activityVisibility: profile.activityVisibility,
            mapPreferences: profile.mapPreferences,
            closeFriends: profile.closeFriends, connectors: profile.connectors
        )
        didMutate()
    }
```

> Note for the implementer: match the exact `UserProfile` / `PresenceStatus` initializer parameter lists from the domain files; adjust the constructions above if any field differs.

- [ ] **Step 4: Add repository methods**

In `Push/Data/Repositories/Repositories.swift`, add to `protocol ProfileRepository`:

```swift
    func updateBasics(displayName: String, handle: String) async throws
    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws
```

Add to `protocol FriendRepository`:

```swift
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws
```

In `Push/Data/Repositories/LocalRepositories.swift`, add to `LocalProfileRepository`:

```swift
    func updateBasics(displayName: String, handle: String) async throws {
        database.updatePerson(id: database.currentUserID, firstName: displayName)
        database.updateProfile(
            handle: handle,
            activityVisibility: database.profile.activityVisibility,
            mapPreferences: database.profile.mapPreferences,
            closeFriends: database.profile.closeFriends
        )
    }

    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws {
        database.updateProfile(
            handle: database.profile.handle,
            activityVisibility: activityVisibility,
            mapPreferences: mapPreferences,
            closeFriends: closeFriends
        )
    }
```

Add to `LocalFriendRepository`:

```swift
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        database.setAvailability(availability)
    }
```

- [ ] **Step 5: Run store/repo tests to verify they pass**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests/DataLayerTests -parallel-testing-enabled NO`
Expected: PASS.

- [ ] **Step 6: Write-through from ProfileViewModel**

In `Push/ProfileViewModel.swift`, make the save actions persist. Replace `setProfileBasics(name:handle:initials:)`:

```swift
    func setProfileBasics(name: String, handle: String, initials: String) {
        displayName = name
        self.handle = handle
        self.initials = initials
        guard let container else { return }
        // initials derive from firstName, so only name + handle persist.
        Task { try? await container.profile.updateBasics(displayName: name, handle: handle) }
    }
```

Replace `select(_ option: ProfileAvailabilityOption)`:

```swift
    func select(_ option: ProfileAvailabilityOption) {
        selectedAvailability = option.availability
        selectedStatusID = ProfileStatusOption.availability(option).id
        guard let container else { return }
        Task { try? await container.friends.setCurrentUserAvailability(option.availability) }
    }
```

Add persistence to the three toggle methods — each mutates local state, then writes the current toggle arrays. Replace `toggleActivityVisibility`, `toggleMapPreference`, `toggleCloseFriend` bodies to call a shared private `persistPrivacy()` after toggling:

```swift
    func toggleActivityVisibility(id: String) {
        activityVisibility.toggleItem(id: id)
        persistPrivacy()
    }

    func toggleMapPreference(id: String) {
        mapPreferences.toggleItem(id: id)
        persistPrivacy()
    }

    func toggleCloseFriend(id: String) {
        closeFriends.toggleItem(id: id)
        persistPrivacy()
    }

    private func persistPrivacy() {
        guard let container else { return }
        Task {
            try? await container.profile.updatePrivacy(
                activityVisibility: activityVisibility,
                mapPreferences: mapPreferences,
                closeFriends: closeFriends
            )
        }
    }
```

- [ ] **Step 7: Run the full suite**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Push/Data/Store/InMemoryDatabase.swift Push/Data/Repositories/Repositories.swift Push/Data/Repositories/LocalRepositories.swift Push/ProfileViewModel.swift PushTests/DataLayerTests.swift
git commit -m "feat: persist profile, status, and privacy to shared local state"
```

---

## Task 7: Build verification + final report

**Files:** none (verification only).

- [ ] **Step 1: Clean build**

Run: `xcodebuild build -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Full test run**

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO`
Expected: all tests pass, 0 failures.

- [ ] **Step 3: Manual smoke (optional, via the run skill)**

Launch the app; create a push via Start Push → confirm it appears in the Pushes tab; swipe a response → confirm it persists across tab switches; change availability + a privacy toggle in Profile → confirm they survive leaving and returning to Profile.

- [ ] **Step 4: Write the final report**

Summarize per the issue: what works end-to-end, which files changed, what state is now shared/persistent locally, what remains mocked (Feed, Add Friend/Group, invites, Ask to Join, Ping Group, full Manage Push, notifications, Supabase, auth, realtime location, Ghost Mode), compromises (PushPlan optionals + free-text location), and the recommended next slice (generate `pushCreated` FeedEvents + build the Feed screen, then map/friend Add flows).

---

## Self-Review Notes

- **Spec coverage:** Slice 1 → Task 1 + Task 5. Slice 2 → Tasks 2–4. Slice 3 (responses shared) → Task 1 (`didMutate` on `setResponse`) + Task 5 (reload test). Slice 4 → Task 6. Feed slice intentionally omitted.
- **Atomicity:** `createPush` inserts plan + responses with a single `didMutate()` (Task 3, Step 3).
- **Revision discipline:** emitted only in `didMutate()` (post-mutation); VMs guard on `lastSeenRevision` (Task 5). Reads never mutate.
- **Recipient rules:** dedupe, exclude creator, creator `.in` once (Task 3, Step 5; asserted in Task 3, Step 1).
- **Type consistency:** `PushDraft`, `createPush(_:)`, `storeRevision`, `onStoreChange(_:)`, `setCurrentUserAvailability(_:)`, `updateBasics(...)`, `updatePrivacy(...)` used identically across tasks. Implementer must confirm `Person`/`UserProfile`/`PresenceStatus` initializer signatures when constructing fresh copies (flagged inline in Task 6).
