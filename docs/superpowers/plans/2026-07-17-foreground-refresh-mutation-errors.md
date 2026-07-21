# Foreground Refresh & Mutation Errors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-warm the live session snapshot on foreground and pull-to-refresh, and make covered mutations fail visibly with rollback + retry.

**Architecture:** `LiveDataStore.refresh()` clears session caches, re-runs `warm()`, and bumps one revision. `AppDataContainer.refreshSession()` is the app entry point (live only; mock no-ops). `ContentView` watches `scenePhase` with skip-first-active + debounce. Friends / Alerts / Groups mode / Pushes call a ViewModel `refresh()`. Covered mutations use `ActionErrorState` + shared banner with Retry; optimistic RSVP/cancel/delete roll back on failure.

**Tech Stack:** SwiftUI, Combine, async/await, existing `LiveDataStore` / repository MVVM seam, XCTest via `scripts/test.sh`.

## Global Constraints

- iOS 17+ SwiftUI; MVVM; no Supabase imports in Views/ViewModels
- Files ≤ 400 lines; functions ≤ 40 lines; named constants only
- Register new Swift files with `python3 scripts/pbxproj_add.py <path>` (relative to `Push/`; `--target tests` for tests)
- Prefer `scripts/test.sh` scoped suites; worktree sim via `ensure-booted-udid`
- User-facing copy: Push/Pushes; calm recoverable error tone
- Spec: `docs/superpowers/specs/2026-07-17-foreground-refresh-mutation-errors-design.md`
- Do not add realtime/subscriptions
- Group create cache invalidation already exists (`notifyGroupsChanged`); verify only

## File map

| File | Responsibility |
|------|----------------|
| `Push/Data/Supabase/LiveDataStore.swift` | `refresh()`: coalesce, debounce, clear caches, `warm()`, one revision |
| `Push/Data/AppDataContainer.swift` | `refreshSession()` live vs mock |
| `Push/Data/SessionRefreshConstants.swift` | Named interval constant |
| `Push/ActionErrorState.swift` | Shared error presentation model |
| `Push/ActionErrorBanner.swift` | Inline banner UI (message, Retry, dismiss) |
| `Push/ContentView.swift` | `scenePhase` → live `refreshSession` |
| `Push/PlansViewModel.swift` | Mutation rollback + `refresh()` + action error |
| `Push/PlansView.swift` | `.refreshable` + banner host |
| `Push/FriendsViewModel.swift` | `refresh()`, action error + retry remove |
| `Push/FriendsView.swift` | `.refreshable` + banner (replace toast-only path) |
| `Push/AlertsViewModel.swift` | Soft load, action errors, `refresh()` |
| `Push/AlertsView.swift` | `.refreshable` + banner |
| `Push/AddGroupViewModel.swift` | Align create error with `ActionErrorState` |
| `Push/AddGroupFlowView.swift` / review step | Host shared banner if not already |
| `PushTests/LiveDataStoreTests.swift` | Refresh / coalesce / failure tests |
| `PushTests/PlansViewModelTests.swift` | Mutation failure/rollback/retry |
| `PushTests/AlertsTests.swift` | Soft load + action failure keeps rows |
| `PushTests/Friends*` or extend existing | Remove failure + retry |
| `tasks/spec.md`, `tasks/todo.md`, `docs/data-architecture.md` | Contract + durable refresh note |

---

### Task 1: LiveDataStore.refresh + AppDataContainer.refreshSession

**Files:**
- Create: `Push/Data/SessionRefreshConstants.swift`
- Modify: `Push/Data/Supabase/LiveDataStore.swift`
- Modify: `Push/Data/AppDataContainer.swift`
- Test: `PushTests/LiveDataStoreTests.swift`

**Interfaces:**
- Consumes: existing `warm()`, cache fields, `revisionSubject`
- Produces:
  - `SessionRefreshConstants.minimumInterval: TimeInterval` (= `2`)
  - `LiveDataStore.refresh() async throws`
  - `AppDataContainer.refreshSession() async throws`

- [ ] **Step 1: Write failing tests for refresh**

Add to `LiveDataStoreTests.swift`:

```swift
func testRefreshClearsCachesAndRefetchesOnce() async throws {
    let loader = LiveDataLoaderSpy()
    loader.pushRows = [Self.samplePushRow(id: "push-1", creator: "self")]
    let store = LiveDataStore(loader: loader)
    try await store.warm()
    XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1])

    loader.pushRows = [
        Self.samplePushRow(id: "push-1", creator: "self"),
        Self.samplePushRow(id: "push-2", creator: "friend")
    ]
    var revisions: [Int] = []
    let sub = store.onChange { revisions.append($0) }

    try await store.refresh()

    let pushes = try await store.pushes()
    XCTAssertEqual(pushes.map(\.id), ["push-1", "push-2"])
    XCTAssertEqual(loader.loadCounts, [2, 2, 2, 2, 2, 2])
    XCTAssertEqual(revisions, [1])
    XCTAssertEqual(store.revision, 1)
    _ = sub
}

func testConcurrentRefreshSharesOneInFlight() async throws {
    let loader = LiveDataLoaderSpy()
    let store = LiveDataStore(loader: loader)
    try await store.warm()
    loader.loadCounts = [0, 0, 0, 0, 0, 0]

    async let a: Void = store.refresh()
    async let b: Void = store.refresh()
    _ = try await (a, b)

    XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1])
    XCTAssertEqual(store.revision, 1)
}

func testFailedRefreshLeavesCacheAndRevisionUntouched() async throws {
    let loader = LiveDataLoaderSpy()
    loader.pushRows = [Self.samplePushRow(id: "push-1", creator: "self")]
    let store = LiveDataStore(loader: loader)
    try await store.warm()
    let before = store.revision
    loader.shouldFailLoads = true // add flag on spy if missing; throw on next load*

    do {
        try await store.refresh()
        XCTFail("expected throw")
    } catch {
        // expected
    }

    loader.shouldFailLoads = false
    let pushes = try await store.pushes()
    XCTAssertEqual(pushes.map(\.id), ["push-1"])
    XCTAssertEqual(store.revision, before)
}

func testRefreshSessionOnPreparedContainerRefetches() async throws {
    let loader = LiveDataLoaderSpy()
    let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")
    XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1])
    try await container.refreshSession()
    XCTAssertEqual(loader.loadCounts, [2, 2, 2, 2, 2, 2])
}

func testRefreshSessionOnMockIsNoOp() async throws {
    let container = AppDataContainer(seed: .standard())
    let before = container.storeRevision
    try await container.refreshSession()
    XCTAssertEqual(container.storeRevision, before)
}
```

If the spy has no fail-all flag, add:

```swift
var shouldFailLoads = false
// at start of each load*(index:): if shouldFailLoads { throw TestFailure.expected }
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
scripts/test.sh suite LiveDataStoreTests
```

Expected: compile error or missing `refresh` / `refreshSession`.

- [ ] **Step 3: Implement constants + store refresh + container API**

`Push/Data/SessionRefreshConstants.swift`:

```swift
import Foundation

enum SessionRefreshConstants {
    /// Minimum time after a successful session re-warm before another
    /// *scheduled* refresh starts new network work.
    static let minimumInterval: TimeInterval = 2
}
```

On `LiveDataStore`, add private state + method:

```swift
private var refreshTask: Task<Void, Error>?
private var lastSuccessfulRefreshAt: Date?

/// Clears all session caches, re-warms, and publishes one revision on success.
/// Concurrent callers await the same in-flight task. A new refresh started
/// within `SessionRefreshConstants.minimumInterval` of a successful one is a no-op.
func refresh() async throws {
    if let refreshTask {
        try await refreshTask.value
        return
    }
    if let lastSuccessfulRefreshAt,
       Date().timeIntervalSince(lastSuccessfulRefreshAt) < SessionRefreshConstants.minimumInterval {
        return
    }
    let task = Task { try await performRefresh() }
    refreshTask = task
    do {
        try await task.value
        refreshTask = nil
    } catch {
        refreshTask = nil
        throw error
    }
}

private func performRefresh() async throws {
    clearAllSessionCaches()
    try await warm()
    lastSuccessfulRefreshAt = Date()
    revisionSubject.value += 1
}

private func clearAllSessionCaches() {
    profileRows = nil
    groupRows = nil
    membershipRows = nil
    policyRows = nil
    pushRows = nil
    responseRows = nil
    profilesTask = nil
    groupsTask = nil
    membershipsTask = nil
    policiesTask = nil
    pushesTask = nil
    responsesTask = nil
}
```

**Important:** `warm()` only loads when caches are nil — clearing first is required. Do **not** bump revision on failure. Successful path bumps **once** after warm (even though `notify*` methods also bump on writes — this is refresh-only).

On `AppDataContainer`:

```swift
/// Live: re-warm the session snapshot. Mock: no-op success.
func refreshSession() async throws {
    guard let liveStore else { return }
    try await liveStore.refresh()
}
```

Register new file:

```bash
python3 scripts/pbxproj_add.py Data/SessionRefreshConstants.swift
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
scripts/test.sh suite LiveDataStoreTests
```

- [ ] **Step 5: Commit**

```bash
git add Push/Data/SessionRefreshConstants.swift Push/Data/Supabase/LiveDataStore.swift Push/Data/AppDataContainer.swift PushTests/LiveDataStoreTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: session refresh re-warms live snapshot (issue #33)"
```

---

### Task 2: Foreground refresh on ContentView

**Files:**
- Modify: `Push/ContentView.swift`
- Test: prefer a small pure helper test if extracted; otherwise manual + store tests cover debounce

**Interfaces:**
- Consumes: `AppDataContainer.shared.refreshSession()`, `AppEnvironment.current` or mode via refresh no-op in mock
- Produces: scenePhase-driven refresh with skip-first-active

- [ ] **Step 1: Add scenePhase wiring**

In `ContentView`:

```swift
@Environment(\.scenePhase) private var scenePhase
@State private var hasEnteredBackground = false

// on body:
.onChange(of: scenePhase) { newPhase in
    handleScenePhase(newPhase)
}
```

```swift
private func handleScenePhase(_ phase: ScenePhase) {
    switch phase {
    case .background:
        hasEnteredBackground = true
    case .active:
        guard hasEnteredBackground else { return }
        hasEnteredBackground = false
        Task {
            try? await AppDataContainer.shared.refreshSession()
        }
    default:
        break
    }
}
```

Notes:
- Mock `refreshSession` no-ops — safe always.
- Foreground failures are silent (`try?`).
- Debounce lives in `LiveDataStore.refresh()`.

Deployment target uses single-parameter `onChange` if required by project lessons; match existing `ContentView` / codebase style (`onChange(of:) { new in }` vs two-param). Prefer the form already used in `FriendsView` / `ContentView`.

- [ ] **Step 2: Build**

```bash
scripts/test.sh build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Push/ContentView.swift
git commit -m "feat: re-warm live session when returning to foreground"
```

---

### Task 3: ActionErrorState + ActionErrorBanner

**Files:**
- Create: `Push/ActionErrorState.swift`
- Create: `Push/ActionErrorBanner.swift`
- Register both via `pbxproj_add.py`

**Interfaces:**
- Produces:
  - `struct ActionErrorState: Equatable { let message: String }`
  - `struct ActionErrorBanner: View` with `message`, `onRetry: () -> Void`, `onDismiss: () -> Void`

- [ ] **Step 1: Implement model + banner**

`ActionErrorState.swift`:

```swift
import Foundation

struct ActionErrorState: Equatable {
    let message: String
}
```

`ActionErrorBanner.swift` — cream-page inline banner using existing color hierarchy (`PushControlColors`, walnut/sunbeam), not black:

```swift
import SwiftUI

struct ActionErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    @Environment(\.pushLayout) private var layout

    var body: some View {
        HStack(alignment: .center, spacing: ActionErrorBannerLayout.spacing) {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry", action: onRetry)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(ActionErrorBannerLayout.padding)
        .background(
            RoundedRectangle(cornerRadius: ActionErrorBannerLayout.cornerRadius(layout), style: .continuous)
                .fill(FriendsColor.cardFill) // or existing cream card fill token
                .overlay(
                    RoundedRectangle(cornerRadius: ActionErrorBannerLayout.cornerRadius(layout), style: .continuous)
                        .strokeBorder(PushColorPalette.Accent.walnut.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

enum ActionErrorBannerLayout {
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 14
    static func cornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.cardCornerRadius // or named fallback if unavailable
    }
}
```

Use the real card fill / radius tokens already used by Friends toasts/cards if `FriendsColor` / `FriendsLayout` fit better than inventing new ones. Keep file under 400 lines.

```bash
python3 scripts/pbxproj_add.py ActionErrorState.swift
python3 scripts/pbxproj_add.py ActionErrorBanner.swift
```

- [ ] **Step 2: Build**

```bash
scripts/test.sh build
```

- [ ] **Step 3: Commit**

```bash
git add Push/ActionErrorState.swift Push/ActionErrorBanner.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: shared action error banner for recoverable mutations"
```

---

### Task 4: PlansViewModel mutation reliability + refresh

**Files:**
- Modify: `Push/PlansViewModel.swift`
- Modify: `Push/PlansView.swift` (and review surfaces that call respond/cancel/delete if needed)
- Test: `PushTests/PlansViewModelTests.swift`

**Interfaces:**
- Consumes: `AppDataContainer.refreshSession()`, `PushRepository` set/cancel/delete
- Produces:
  - `@Published private(set) var actionError: ActionErrorState?`
  - `func dismissActionError()`
  - `func retryLastAction() async`
  - `func refresh() async`
  - `func respond(...) async` (replace fire-and-forget)
  - `func cancel(plan:) async` / `func delete(plan:) async`

- [ ] **Step 1: Write failing mutation tests**

Introduce a test double (in the test file or shared test helpers) that can fail writes:

```swift
@MainActor
final class ControllablePushRepository: PushRepository {
    var active: [PushPlan] = []
    var responseRows: [PushResponse] = []
    var shouldFailWrite = false
    var setResponseCalls: [(PushPlan.ID, PushResponse.Response)] = []
    // Implement remaining methods with empty/default; throw on write when shouldFailWrite
    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        setResponseCalls.append((planID, response))
        if shouldFailWrite { throw TestFailure.expected }
        // update responseRows
    }
    func cancelPush(planID: PushPlan.ID) async throws {
        if shouldFailWrite { throw TestFailure.expected }
        active.removeAll { $0.id == planID }
    }
    func deletePush(planID: PushPlan.ID) async throws {
        if shouldFailWrite { throw TestFailure.expected }
        active.removeAll { $0.id == planID }
    }
    // ... other protocol requirements
}
```

Alternatively inject via a custom `AppDataContainer` if the project has a package-visible test initializer — prefer the smallest seam. If constructing a full container is hard, test through mock seed + temporarily swapping is not available; then use `PlansViewModel(plans:)` only for pure UI state tests of rollback helpers, and a container-backed test with a **local** repository subclass isn't possible without DI.

**Practical approach for this codebase:** keep using `AppDataContainer(seed:)` and add a **test-only** path only if needed. Better: make `PlansViewModel` accept optional `PushRepository` override like other VMs, OR test rollback by:

1. Loading real mock container plans
2. For failure path, unit-test a package-visible helper

**Preferred DI (minimal):** change respond/cancel/delete to use `container?.pushes` as today; add internal test hook:

Actually the cleanest match to project style: create container with seed, then in tests we cannot fail LocalPushRepository. So add to `PlansViewModel`:

```swift
// already has container
```

And introduce `FailingPushRepository` wrapping another repo for tests — only if we can construct VM with custom pushes repo.

**Do this:** extend `PlansViewModel` init used in tests:

```swift
init(container: AppDataContainer? = nil, referenceDate: Date = Date(), pushes: PushRepository? = nil)
// self.pushes = pushes ?? container.pushes
```

Store `private let pushes: PushRepository?` and use it for mutations + load from container for full load when needed.

Simplest path matching existing map/friends: keep load via container; for mutation tests use injected `PushRepository` optional property:

```swift
private let pushesOverride: PushRepository?
private var pushRepo: PushRepository? { pushesOverride ?? container?.pushes }
```

Tests:

```swift
func testRespondFailureRollsBackAndSetsActionError() async throws {
    let fake = ControllablePushRepository()
    fake.shouldFailWrite = true
    let plan = seamPlan("p1", status: .pending)
    let vm = PlansViewModel(plans: [plan], pushes: fake) // extend preview init
    await vm.respond(to: plan, with: .right)
    XCTAssertEqual(vm.plans.first?.status, .pending) // rolled back from .joined/.in pill
    XCTAssertEqual(vm.actionError?.message, "Couldn't update your response. Try again.")
    fake.shouldFailWrite = false
    await vm.retryLastAction()
    XCTAssertNil(vm.actionError)
    XCTAssertEqual(fake.setResponseCalls.count, 2)
}

func testCancelFailureRestoresCard() async throws {
    // optimistic remove then restore on fail
}

func testDeleteFailureRestoresCard() async throws {
    // same
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
scripts/test.sh suite PlansViewModelTests
```

- [ ] **Step 3: Implement ViewModel mutations**

Replace silent methods with:

```swift
@Published private(set) var actionError: ActionErrorState?
private enum PendingMutation {
    case respond(planID: PlanData.ID, direction: SwipeDirection, previousStatus: PlanStatus)
    case cancel(plan: PlanData, index: Int)
    case delete(plan: PlanData, index: Int)
}
private var pendingMutation: PendingMutation?

func dismissActionError() {
    actionError = nil
    // keep pendingMutation so Retry still works, or clear both — prefer keep until success/dismiss
}

func retryLastAction() async {
    guard let pendingMutation else { return }
    switch pendingMutation {
    case .respond(let id, let direction, _):
        guard let plan = plans.first(where: { $0.id == id }) else { return }
        await respond(to: plan, with: direction)
    case .cancel(let plan, _):
        await cancel(plan: plan)
    case .delete(let plan, _):
        await delete(plan: plan)
    }
}

func respond(to plan: PlanData, with direction: SwipeDirection) async {
    guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
    let previous = plans[idx].status
    let response: PushResponse.Response = /* map direction */
    plans[idx].status = PlansContentBuilder.pill(for: response)
    do {
        try await pushRepo?.setCurrentUserResponse(planID: plan.id, response: response)
        actionError = nil
        pendingMutation = nil
        lastSeenRevision = container?.storeRevision ?? lastSeenRevision
    } catch {
        plans[idx].status = previous
        pendingMutation = .respond(planID: plan.id, direction: direction, previousStatus: previous)
        actionError = ActionErrorState(message: "Couldn't update your response. Try again.")
    }
}

func cancel(plan: PlanData) async {
    guard let idx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
    let snapshot = plans[idx]
    plans.remove(at: idx)
    do {
        try await pushRepo?.cancelPush(planID: plan.id)
        actionError = nil
        pendingMutation = nil
        lastSeenRevision = container?.storeRevision ?? lastSeenRevision
    } catch {
        let insertAt = min(idx, plans.count)
        plans.insert(snapshot, at: insertAt)
        pendingMutation = .cancel(plan: snapshot, index: insertAt)
        actionError = ActionErrorState(message: "Couldn't cancel this Push. Try again.")
    }
}

// delete: same pattern with "Couldn't delete this Push. Try again."
```

Update call sites (`ReviewPushesView`, manage UI) from `viewModel.respond(...)` to `Task { await viewModel.respond(...) }`.

```swift
func refresh() async {
    try? await container?.refreshSession()
    await load()
}
```

Soft-load already partially present (`if loadState.value == nil { loadState = .loading }`) — keep it.

- [ ] **Step 4: Wire PlansView**

Wrap scrollable content so `.refreshable` works (Plans is currently a `VStack` — wrap `pageContent` in `ScrollView` if needed, matching product layout):

```swift
ScrollView {
    pageContent
}
.refreshable {
    await viewModel.refresh()
}
.safeAreaInset(edge: .bottom) {
    if let actionError = viewModel.actionError {
        ActionErrorBanner(
            message: actionError.message,
            onRetry: { Task { await viewModel.retryLastAction() } },
            onDismiss: { viewModel.dismissActionError() }
        )
        .padding()
    }
}
```

- [ ] **Step 5: Run tests + build**

```bash
scripts/test.sh suite PlansViewModelTests
scripts/test.sh build
```

- [ ] **Step 6: Commit**

```bash
git add Push/PlansViewModel.swift Push/PlansView.swift Push/ReviewPushesView.swift Push/YourPushesListView.swift PushTests/PlansViewModelTests.swift
git commit -m "feat: push mutation errors with rollback and pull-to-refresh"
```

---

### Task 5: Friends soft refresh + remove error banner with retry

**Files:**
- Modify: `Push/FriendsViewModel.swift`
- Modify: `Push/FriendsView.swift`
- Test: extend friends tests if present (`PushTests` friends / `DataLayerTests`); else add cases next to remove coverage

**Interfaces:**
- Produces: `actionError` (or keep `removeErrorMessage` but map to banner with retry), `refresh()`, `retryLastAction()` for remove

- [ ] **Step 1: Write failing test**

```swift
func testRemoveFriendFailureSetsErrorAndKeepsRow() async throws {
    // Use a FriendRepository fake that throws on removeFriend
    // Assert row still present, actionError set
    // Retry after shouldFail = false removes row
}
```

If constructing FriendsViewModel requires multiple repos, use `AppDataContainer(seed:)` and a test double only if DI exists — add optional `friends:` override parallel to Plans if needed.

- [ ] **Step 2: Implement**

```swift
@Published private(set) var actionError: ActionErrorState?
private var pendingRemove: FriendRowModel?

func removeFriend(_ row: FriendRowModel) async {
    guard removingFriendIDs.insert(row.id).inserted else { return }
    defer { removingFriendIDs.remove(row.id) }
    do {
        try await friends.removeFriend(row.friend.id)
        // existing success path: collapse + load
        actionError = nil
        pendingRemove = nil
        ...
        await load()
    } catch {
        pendingRemove = row
        actionError = ActionErrorState(
            message: "Couldn't remove \(row.friend.name). Try again."
        )
    }
}

func retryLastAction() async {
    if let pendingRemove {
        await removeFriend(pendingRemove)
    }
}

func refresh() async {
    try? await containerForRefresh?.refreshSession()
    await load()
}
```

Remove or deprecate `removeErrorMessage` toast auto-clear that drops retry — replace with banner.

In `FriendsView` list `ScrollView`:

```swift
.refreshable { await viewModel.refresh() }
```

Host `ActionErrorBanner` when `viewModel.actionError != nil`. Remove the `onChange(of: removeErrorMessage)` toast path for remove errors (keep toast for unrelated messages if any).

- [ ] **Step 3: Tests + build + commit**

```bash
scripts/test.sh suite DataLayerTests
# or targeted friends test suite name once added
scripts/test.sh build
git commit -m "feat: friends pull-to-refresh and remove-friend retry banner"
```

---

### Task 6: Alerts soft load + accept/deny action errors + refresh

**Files:**
- Modify: `Push/AlertsViewModel.swift`
- Modify: `Push/AlertsView.swift`
- Test: `PushTests/AlertsTests.swift`

**Interfaces:**
- Consumes: `AlertRepository`, `refreshSession`
- Produces: soft `load()`, `actionError`, `retryLastAction()`, `refresh()`

- [ ] **Step 1: Write failing tests**

```swift
func testLoadKeepsContentWhenAlreadyLoaded() async {
    // Repository that returns data then fails on second load
    // First load succeeds; second load fails; requests remain non-empty
}

func testAcceptFailureKeepsRequestAndSetsActionError() async {
    // Throwing accept after successful load
    // requests still contains item; loadState not .failed; actionError set
}

func testGroupInviteAcceptFailureKeepsInvite() async {
    // same for group invite
}
```

Extend `ThrowingAlertRepository` or add `ControllableAlertRepository` with per-method flags.

- [ ] **Step 2: Implement soft load + resolve error handling**

```swift
func load() async {
    guard resolvingIDs.isEmpty else { return }
    if loadState.value == nil { loadState = .loading }
    do {
        let models = try await repository.incomingFriendRequests().map(FriendRequestAlertModel.init)
        let invites = try await repository.incomingGroupInvites()
        requests = models
        groupInvites = invites
        loadState = .loaded(models)
        lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
    } catch {
        if loadState.value == nil {
            loadState = .failed(error)
        }
        // else keep content; optional refresh error message
    }
}

// In resolve catch:
} catch {
    pendingResolve = ... // id + accepting + kind
    actionError = ActionErrorState(message: accepting
        ? "Couldn't accept. Try again."
        : "Couldn't decline. Try again.")
    // do NOT set loadState = .failed
}
```

`refresh()`:

```swift
func refresh() async {
    try? await containerForRefresh?.refreshSession()
    await load()
}
```

- [ ] **Step 3: Wire AlertsView**

```swift
ScrollView { ... }
.refreshable { await viewModel.refresh() }
// banner overlay/inset for actionError
```

- [ ] **Step 4: Tests + build + commit**

```bash
scripts/test.sh suite AlertsTests
scripts/test.sh build
git commit -m "feat: alerts soft refresh and recoverable accept/deny errors"
```

---

### Task 7: Add Group create error uses shared banner; Groups list refresh

**Files:**
- Modify: `Push/AddGroupViewModel.swift` — `errorMessage` → `ActionErrorState?` or keep string and wrap at view
- Modify: `Push/AddGroupFlowView.swift` / step 3 review for banner + Retry calling `submit()`
- Modify: `Push/FriendsView.swift` Groups mode already shares Friends `ScrollView` + `.refreshable` from Task 5
- Verify: live `createGroup` already calls `notifyGroupsChanged()` — no change if true

**Interfaces:**
- Produces: create failure message via shared banner; Retry → `submit()`

- [ ] **Step 1: Align create error UI**

```swift
// AddGroupViewModel — keep message string or:
@Published var actionError: ActionErrorState?
// on catch:
actionError = ActionErrorState(message: "Couldn't create the group. Try again.")
```

Review step shows `ActionErrorBanner` with Retry → `Task { _ = await viewModel.submit() }`.

- [ ] **Step 2: Build + commit**

```bash
scripts/test.sh build
git commit -m "feat: group create uses shared action error banner"
```

---

### Task 8: Spec/todo/docs + final verification

**Files:**
- Modify: `tasks/spec.md` (Issue #33 contract summary at top)
- Modify: `tasks/todo.md` (checklist for this issue)
- Modify: `docs/data-architecture.md` — short note under live mode: `refreshSession()` re-warms snapshot on foreground/pull-to-refresh; failed refresh leaves cache; mutations use action errors

- [ ] **Step 1: Update task docs** from design acceptance criteria (no need to paste full design).

- [ ] **Step 2: Run focused suites then full when ready for PR**

```bash
scripts/test.sh suite LiveDataStoreTests
scripts/test.sh suite PlansViewModelTests
scripts/test.sh suite AlertsTests
scripts/test.sh build
# before PR:
scripts/test.sh full
```

- [ ] **Step 3: Commit docs**

```bash
git add tasks/spec.md tasks/todo.md docs/data-architecture.md
git commit -m "docs: issue #33 refresh and mutation error contract"
```

---

## Spec coverage checklist (self-review)

| Spec requirement | Task |
|------------------|------|
| Full session re-warm API | Task 1 |
| Coalesce + debounce ~2s | Task 1 |
| Foreground trigger + skip first active | Task 2 |
| Pull-to-refresh Friends/Alerts/Groups/Pushes | Tasks 4–6 (Groups via Friends) |
| Keep content while refreshing | Tasks 4–6 soft load |
| Silent foreground refresh failure | Task 2 `try?` |
| Action error banner + Retry | Task 3 + consumers |
| RSVP/cancel/delete rollback | Task 4 |
| Friend remove error + retry | Task 5 |
| Group create error | Task 7 |
| Friend + group invite accept/deny errors | Task 6 |
| Group create cache invalidation | Task 7 verify existing |
| Tests + docs | Tasks 1,4–6,8 |

## Placeholder / consistency notes

- `ActionErrorState.message` is the only stored error field; retry payloads are private per VM.
- `refreshSession()` is the only app-level refresh entry; VMs call it inside `refresh()`.
- Copy strings are fixed in this plan — do not invent alternate wording without updating tests.

