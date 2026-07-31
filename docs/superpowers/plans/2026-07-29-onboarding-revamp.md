# Onboarding Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Spec: `docs/superpowers/specs/2026-07-29-onboarding-revamp-design.md`. Audit: `docs/superpowers/specs/2026-07-29-onboarding-revamp-audit.md`.

**Goal:** Replace the post-auth first-run flow so new live users get a short teach → required location hard-gate → Ghost + Pushes/Moments teach → optional notifications/contacts → soft find-people path, then the map — with the prepare-time location prompt race fixed.

**Architecture:** Keep auth gate as-is. Evolve `PostAuthOnboardingViewModel` into a linear state machine matching Approach 2. Gate location authorization requests behind onboarding (or completed users) so `installPreparedLive` never shows the OS dialog early. Apply exact+activity sharing defaults + presence publishing on only after location Allow. `complete_onboarding` only when location is authorized. Contacts matching is a later phase with a protocol seam.

**Tech Stack:** SwiftUI iOS 17+, existing `LocationSession` / `LocationProviding`, `UNUserNotificationCenter`, `SharingRepository` / `ProfileRepository` / `FriendRepository`, lab onboarding chrome (`OnboardingLab*`), XCTest doubles — no new third-party SDKs. Contacts (Phase 3): `Contacts` framework behind a protocol.

## Global Constraints

- Spec is **law**: `docs/superpowers/specs/2026-07-29-onboarding-revamp-design.md` (Approved).
- **Location required** — no “Not now”; deny/restricted → hard gate; no `complete_onboarding`; no `.app` / `ContentView`.
- **Ghost teach-only** — default presence publishing **on**; no Ghost toggle / privacy multi-picker in onboarding.
- **Teaching sections ≤ 1 screen each** (Value, Ghost, Coordinate combined Pushes+Moments). Optional action steps = 1 screen each.
- **Do not** invent invite-link onboarding in v1.
- MVVM: Views dumb; no Supabase in Views; repos via `AppDataContainer`.
- Files ≤ 400 lines; functions ≤ 40 lines; named constants only.
- Register new Swift files: `python3 scripts/pbxproj_add.py <path relative to Push/>`; tests with `--target tests`.
- Visual: extend lab shell (`OnboardingLabColor`, `OnboardingHeader`, `OnboardingCTAButton`, mini-map) — no new glass recipes.
- Mock mode: `needsPostAuthOnboarding` stays `false`; never show post-auth flow.
- Tests via `scripts/test.sh suite …` (worktree-labeled sim). Scoped suites; `full` before PR.
- Do not commit secrets, DerivedData, or `xcuserdata`.
- Auth gate screens stay; only post-auth + location gating + RootView fail-closed change.

## File map

| File | Responsibility |
|---|---|
| `Push/Data/Domain/LocationProtocols.swift` | Optional: document/extend session APIs if prompt gating needs a method |
| `Push/Data/Domain/LocationSession.swift` | Support “refresh auth state without requesting” and/or explicit request-only path used by onboarding |
| `Push/Data/Domain/LocationTestDoubles.swift` | Doubles for authorization request counting / forced deny |
| `Push/Data/AppDataContainer.swift` | `installPreparedLive` must **not** call `startIfEligible` when onboarding incomplete; completed/mock OK |
| `Push/RootView.swift` | Fail-closed needs-onboarding; enter app only after complete; location start rules |
| `Push/Auth/PostAuthOnboardingViewModel.swift` | New screen enum + transitions + permission orchestration + completion guards |
| `Push/Auth/PostAuthOnboardingView.swift` | Router + progress + back chrome for new screens |
| `Push/Auth/PostAuthOnboardingScreens.swift` | Split/replace screens (value, location, blocked, ghost, coordinate, notif, contacts, friends, done) |
| `Push/Auth/OnboardingPrivacyOption.swift` | Keep for lab/mapping tests if still used by DEBUG lab; production onboarding stops selecting it — defaults applied in VM |
| `Push/Auth/OnboardingPermissionPrimer.swift` (new, if needed) | Shared primer layout to stay ≤400 lines per file |
| `Push/Data/Domain/ContactsProviding.swift` (Phase 3) | Protocol + null/mock doubles |
| `Push/Data/Contacts/DeviceContactsProvider.swift` (Phase 3) | Live `CNContactStore` wrapper |
| `Push/Info.plist` (Phase 3) | `NSContactsUsageDescription` |
| `docs/app-store-privacy.md` (Phase 3) | Contacts disclosure |
| `PushTests/PostAuthOnboardingTests.swift` | State machine, completion, skip removal |
| `PushTests/LocationSessionContainerTests.swift` / new suite | Prompt race / install gating |
| `PushTests/AuthBootstrapTests.swift` | Fail-closed prepare if needed |
| `Agents.md` / `Claude.md` | Durable post-auth flow bullets after ship |

**Out of scope files:** Auth sign-up/sign-in views (unless a one-line handoff comment), Moment/Push feature code, invite deep links.

---

### Task 1: Location prompt race — do not request auth during incomplete onboarding install

**Files:**
- Modify: `Push/Data/AppDataContainer.swift` (`installPreparedLive`)
- Modify: `Push/RootView.swift` (`prepare`, `enter`)
- Modify: `Push/Data/Domain/LocationSession.swift` and/or `LocationProtocols.swift` if a `refreshAuthorizationState()` (no prompt) is cleaner than overloading `startIfEligible`
- Modify: `Push/Data/Domain/LocationTestDoubles.swift` — ensure `requestAuthorizationCount` stays accurate
- Test: `PushTests/LocationSessionContainerTests.swift` and/or `PushTests/PostAuthOnboardingTests.swift`

**Interfaces:**
- Consumes: `LocationSessioning.startIfEligible()`, `provider.authorizationState`, `ProfileRepository.needsPostAuthOnboarding()`
- Produces: Install path that starts presence Realtime but **does not** call `requestAuthorization` when the installed user still needs onboarding

**Design choice (implement this):**

```swift
// AppDataContainer.installPreparedLive
static func installPreparedLive(
    _ container: AppDataContainer,
    startLocationIfEligible: Bool = true
) {
    shared.shutdownLocationSession()
    shared.stopPresenceRealtimeBridge()
    shared = container
    Task {
        if startLocationIfEligible {
            await container.locationSession?.startIfEligible()
        }
        await container.presenceRealtimeBridge?.start()
    }
}
```

`RootView.prepare`:

```swift
let needsOnboarding: Bool
do {
    needsOnboarding = try await container.profile.needsPostAuthOnboarding()
} catch {
    // Fail closed: do not enter .app without knowing completion (Task 2 expands UX).
    PushLog.bootstrap.error("needsPostAuthOnboarding failed: …")
    enter(.preparationFailed(user, /* safe message */))
    return
}
AppDataContainer.installPreparedLive(container, startLocationIfEligible: !needsOnboarding)
// photo upload…
if needsOnboarding {
    enter(.onboarding(user))
} else {
    enter(.app(user))
}
```

`enter(.app)` may still call `startIfEligible()` for completed users / mock — that is correct **after** onboarding or when already complete.

- [ ] **Step 1: Write failing test** — installing live container for an “incomplete onboarding” path must not request authorization.

Use existing test doubles. Pattern:

```swift
@MainActor
func testInstallPreparedLiveSkipsLocationPromptWhenFlagFalse() async {
    let provider = AuthorizationRecordingLocationProvider(authorizationState: .notDetermined)
    // Build a live-ish container with a LocationSession wrapping `provider`
    // OR use FakeLocationSessioning that records startIfEligibleCount.
    let session = FakeLocationSessioning()
    // Wire container.locationSession = session via test helper / existing container seams.
    AppDataContainer.installPreparedLive(container, startLocationIfEligible: false)
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(session.startIfEligibleCount, 0)
}
```

If `FakeLocationSessioning` lacks a counter, add `startIfEligibleCount` (already present on the domain fake in `LocationTestDoubles.swift` — reuse).

- [ ] **Step 2: Run test — expect FAIL** (current `installPreparedLive` always starts location).

```bash
scripts/test.sh suite LocationSessionContainerTests
# or the suite you add the test to
```

- [ ] **Step 3: Implement `startLocationIfEligible` parameter + RootView wiring** as above. Do **not** change onboarding screens yet.

- [ ] **Step 4: Run tests — expect PASS** for container suite; run `LocationSessionTests` smoke if session API changed.

```bash
scripts/test.sh suite LocationSessionContainerTests
scripts/test.sh suite LocationSessionTests
```

- [ ] **Step 5: Commit**

```bash
git add Push/Data/AppDataContainer.swift Push/RootView.swift Push/Data/Domain/Location*.swift PushTests/*.swift
git commit -m "fix(onboarding): do not request location during incomplete live prepare"
```

---

### Task 2: Fail-closed onboarding gate + completion requires authorized location

**Files:**
- Modify: `Push/RootView.swift` (`prepare` error path — finished in Task 1 if not done)
- Modify: `Push/Auth/PostAuthOnboardingViewModel.swift` — `finishOnboarding` / `continueFromFriends` must check location auth
- Modify: `Push/Data/Domain/LocationProtocols.swift` / session — expose read of `authorization` / `allowsWhenInUseUpdates` to the VM without UIKit
- Test: `PushTests/PostAuthOnboardingTests.swift`

**Interfaces:**
- Consumes: `locationSession` authorization state (`LocationAuthorizationState.allowsWhenInUseUpdates`)
- Produces: `completeOnboarding()` only when `allowsWhenInUseUpdates == true`

- [ ] **Step 1: Failing tests**

```swift
func testFinishOnboardingBlockedWithoutLocationAuthorization() async {
    let container = AppDataContainer(seed: .standard())
    // Inject session double with authorization .denied
    let vm = PostAuthOnboardingViewModel(container: container, locationSession: deniedSession, …)
    await vm.continueFromFriends() // or finishOnboarding()
    XCTAssertNotEqual(vm.screen, .done)
    XCTAssertNotNil(vm.errorMessage)
}

func testFinishOnboardingSucceedsWhenLocationAuthorized() async {
    // session .whenInUse → complete → .done
}
```

Note: mock `completeOnboarding` is no-op but VM should still advance to `.done` only when auth allows.

- [ ] **Step 2: Run — FAIL**

```bash
scripts/test.sh suite PostAuthOnboardingTests
```

- [ ] **Step 3: Implement guard**

```swift
private var hasRequiredLocationAuthorization: Bool {
    // Prefer injected LocationSessioning; fall back to container.locationSession
    let auth = locationSession?.authorizationState /* or tracking state */
    return auth?.allowsWhenInUseUpdates == true
}

private func finishOnboarding() async {
    guard !isBusy else { return }
    guard hasRequiredLocationAuthorization else {
        errorMessage = Copy.locationRequired
        screen = .locationBlocked // or stay; prefer blocked
        return
    }
    // existing completeOnboarding RPC…
}
```

Add VM dependency injection:

```swift
init(
    container: AppDataContainer? = nil,
    notificationCenter: UNUserNotificationCenter = .current(),
    locationSession: LocationSessioning? = nil
)
```

Resolve `locationSession ?? container.locationSession`.

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "fix(onboarding): fail closed without location; gate complete_onboarding"
```

---

### Task 3: New onboarding screen enum + state machine (no full UI yet)

**Files:**
- Modify: `Push/Auth/PostAuthOnboardingViewModel.swift`
- Modify: `PushTests/PostAuthOnboardingTests.swift`
- Possibly split: `Push/Auth/PostAuthOnboardingViewModel+Location.swift` if main file exceeds 400 lines

**Interfaces:**
- Produces:

```swift
enum PostAuthOnboardingScreen: Equatable {
    case value
    case locationPrimer
    case locationBlocked
    case ghost
    case coordinate
    case notifications
    case contacts
    case findPeople
    case done
}
```

Progress mapping (example — 7 steps excluding blocked/done):

| Screen | progressStep (1-based) | showsBack |
|---|---|---|
| value | 1 | false |
| locationPrimer | 2 | true |
| locationBlocked | 2 | false |
| ghost | 3 | true |
| coordinate | 4 | true |
| notifications | 5 | true |
| contacts | 6 | true |
| findPeople | 7 | true |
| done | 0 / hide | false |

`progressTotal = 7`

Transitions (happy path):

```text
value → locationPrimer → (allow) → ghost → coordinate → notifications → contacts → findPeople → done
locationPrimer → (deny) → locationBlocked → (allow after Settings) → ghost
```

- [ ] **Step 1: Replace enum + rewrite navigation helpers; update existing tests that reference `.privacy`, `.location`, `skipLocation`.**

Delete production use of:
- `continueFromPrivacy` / privacy selection as a required step
- `skipLocation`

Keep temporary stubs if needed so the project compiles mid-task, but tests should define the new machine.

- [ ] **Step 2: Failing/updated tests for order**

```swift
func testHappyPathOrderWithLocationAllow() async {
    let vm = makeVM(auth: .whenInUse) // or notDetermined → grant on enable
    XCTAssertEqual(vm.screen, .value)
    vm.continueFromValue()
    XCTAssertEqual(vm.screen, .locationPrimer)
    await vm.enableLocation()
    XCTAssertEqual(vm.screen, .ghost)
    vm.continueFromGhost()
    XCTAssertEqual(vm.screen, .coordinate)
    vm.continueFromCoordinate()
    XCTAssertEqual(vm.screen, .notifications)
    await vm.skipNotifications()
    XCTAssertEqual(vm.screen, .contacts)
    await vm.skipContacts()
    XCTAssertEqual(vm.screen, .findPeople)
    await vm.continueFromFindPeople()
    XCTAssertEqual(vm.screen, .done)
}
```

Phase note: until Contacts UI exists, `skipContacts` can immediately advance (Task 7 implements real contacts). For Task 3, include `contacts` in the enum and advance through it.

- [ ] **Step 3: Implement transitions + back stack rules** (back from ghost returns to locationPrimer only if useful; blocked has no back into skip).

- [ ] **Step 4: `scripts/test.sh suite PostAuthOnboardingTests` PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(onboarding): Approach 2 screen state machine"
```

---

### Task 4: Location primer, enable, defaults write, hard blocked UI (VM + screens)

**Files:**
- Modify: `Push/Auth/PostAuthOnboardingViewModel.swift`
- Modify: `Push/Auth/PostAuthOnboardingScreens.swift` (replace privacy-first screens)
- Modify: `Push/Auth/PostAuthOnboardingView.swift`
- Test: `PushTests/PostAuthOnboardingTests.swift`

**Interfaces:**
- Consumes: `locationSession.startIfEligible()`, `sharing.setGlobalDefaults`, `locationSession.setPresencePublishingEnabled(true)`, `profile.updatePrivacy` (mirror exact+activity toggles — reuse logic from old `mirrorPrivacyToggles` for `.exactActivity` only)
- Produces: after Allow → defaults applied → `.ghost`; after Deny → `.locationBlocked`

- [ ] **Step 1: Tests**

```swift
func testEnableLocationDeniedGoesToBlocked() async {
    // provider/session that sets .denied on request
    await vm.enableLocation()
    XCTAssertEqual(vm.screen, .locationBlocked)
}

func testEnableLocationAllowAppliesDefaultsAndAdvances() async {
    await vm.enableLocation()
    XCTAssertEqual(vm.screen, .ghost)
    let policies = try await container.sharing.allPolicies()
    let global = policies.first { $0.audienceType == .globalDefault && $0.ownerPersonID == container.currentUserID }
    XCTAssertEqual(global?.locationVisibility, .exact)
    XCTAssertEqual(global?.activityVisibility, .full)
}

func testBlockedRetryAfterAllowAdvances() async {
    // start denied → blocked → flip auth to whenInUse → retryLocationAccess() → ghost
}
```

- [ ] **Step 2: Implement `enableLocation()`**

```swift
func enableLocation() async {
    guard !isBusy else { return }
    isBusy = true
    errorMessage = nil
    defer { isBusy = false }

    await locationSession?.startIfEligible()
    let auth = currentAuthorization
    state.authorization mirror…

    guard auth.allowsWhenInUseUpdates else {
        screen = .locationBlocked
        return
    }

    do {
        try await applyDefaultSharingAndPublishing()
        screen = .ghost
    } catch {
        errorMessage = Copy.privacyFailed // rename to defaultsFailed
        // stay on primer or blocked? Stay on primer with error if auth OK but write failed.
    }
}

private func applyDefaultSharingAndPublishing() async throws {
    try await container.sharing.setGlobalDefaults(
        location: .exact,
        activity: .full,
        availability: .full
    )
    await locationSession?.setPresencePublishingEnabled(true)
    try await mirrorExactActivityPrivacyToggles()
}
```

`retryLocationAccess()`: call `startIfEligible` again / refresh status; if Settings changed to allow, apply defaults and go `.ghost`.

Open Settings:

```swift
func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
}
```

Prefer wrapping open-URL in a tiny `SettingsOpening` protocol for tests (optional).

- [ ] **Step 3: Screens**

**locationPrimer:** hero mini-map (self puck), header “Push runs on location.”, primary **Enable location** only (no Not now).

**locationBlocked:** header “Location is required.”, body explains, primary **Open Settings**, secondary **Try again**, optional sign-out via environment if already injected on onboarding (`RootView` already passes `signOut` on onboarding — wire a text button).

Remove `PostAuthPrivacyScreen` from production router (lab may still use `OnboardingPrivacyOption`).

- [ ] **Step 4: Tests + build**

```bash
scripts/test.sh suite PostAuthOnboardingTests
scripts/test.sh build
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(onboarding): required location primer and hard gate"
```

---

### Task 5: Teach screens — Value, Ghost, Coordinate (1 each)

**Files:**
- Modify: `Push/Auth/PostAuthOnboardingScreens.swift` (split to `PostAuthOnboardingTeachScreens.swift` if over 400 lines)
- Modify: `Push/Auth/PostAuthOnboardingView.swift` router
- Reuse: `OnboardingMiniMap`, `OnboardingLabFixtures` patterns — promote any fixture types needed out of `#if DEBUG` **only if** production teach screens need them. Prefer small production fixtures in `Push/Auth/OnboardingTeachFixtures.swift` (not DEBUG-only) with bundle assets already in the app.

**Interfaces:**
- Produces: `continueFromValue()`, `continueFromGhost()`, `continueFromCoordinate()` → next screen

Copy direction (from spec §13):

| Screen | Title | Subtitle |
|---|---|---|
| value | See what your friends are up to | Private live map for real friends — context without the group chat |
| ghost | You’re visible to friends | Go invisible anytime with Ghost in Profile |
| coordinate | Make plans. Keep moments. | Start a Push when something’s forming; share Moments from the hang |

- [ ] **Step 1: Add teach screen views + VM continue methods; start screen = `.value`.**

Value screen: static mini-map with 2–3 fixture avatars (copy asset paths from lab fixtures into production fixtures file).

Ghost: simple icon/hero + copy + Continue.

Coordinate: two compact cards or one illustration row for Push + Moment — single screen, one CTA.

- [ ] **Step 2: Manual/build check**

```bash
scripts/test.sh build
```

- [ ] **Step 3: Unit test start screen is `.value` and continue chain without location methods.**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(onboarding): value, ghost, and coordinate teach screens"
```

---

### Task 6: Notifications optional step (existing behavior, new order)

**Files:**
- Modify: `Push/Auth/PostAuthOnboardingViewModel.swift`
- Modify: `Push/Auth/PostAuthOnboardingScreens.swift` (adapt old notifications UI)
- Test: `PushTests/PostAuthOnboardingTests.swift`

**Interfaces:**
- `enableNotifications()` → request auth → advance to `.contacts`
- `skipNotifications()` → advance without request
- Never blocks completion

- [ ] **Step 1: Tests for later/deny still advancing**

```swift
func testSkipNotificationsGoesToContacts() async {
    vm.screen = .notifications // or drive via internals in tests via full happy path with stubs
    await vm.skipNotifications()
    XCTAssertEqual(vm.screen, .contacts)
}
```

Use package-visible test hooks sparingly; prefer driving from `.value` with location auto-allow double.

- [ ] **Step 2: Port UI copy; primary Turn on / secondary Maybe later**

Honest copy: do not promise rich push product if backend absent — e.g. “Get a nudge when something’s happening — you can change this in Settings.”

- [ ] **Step 3: Tests PASS + commit**

```bash
git commit -m "feat(onboarding): optional notifications step in new spine"
```

---

### Task 7: Find people step + Done + completion wiring

**Files:**
- Modify: `PostAuthOnboardingViewModel` friends APIs (rename screens `.friends` → `.findPeople`)
- Modify: screens (reuse list UI)
- Modify: `PostAuthOnboardingView` `onFinished`
- Test: completion with 0 adds; load failure still continuable

**Interfaces:**
- `loadPeople` when entering find people (from contacts skip or after contacts)
- `continueFromFindPeople()` → `complete_onboarding` if location OK → `.done`
- `openApp()` → `isFinished = true` → RootView `.app`

- [ ] **Step 1: Tests**

```swift
func testContinueFindPeopleWithZeroAddsReachesDoneWhenLocationOK() async { … }
func testOpenAppSetsFinished() { … }
```

- [ ] **Step 2: Implement load on transition into findPeople** (from `skipContacts` / `continueFromContacts`)

- [ ] **Step 3: Done screen “You’re in.” / Open Push**

- [ ] **Step 4: Tests + commit**

```bash
git commit -m "feat(onboarding): find people soft nudge and completion"
```

---

### Task 8: Contacts optional step (Phase 3 — can ship after Tasks 1–7)

**Files:**
- Create: `Push/Data/Domain/ContactsProviding.swift`
- Create: `Push/Data/Contacts/DeviceContactsProvider.swift`
- Create: mock `NullContactsProvider` / `FixedContactsProvider` for tests
- Modify: `PostAuthOnboardingViewModel` + screens
- Modify: `Push/Info.plist` — `NSContactsUsageDescription`
- Modify: `docs/app-store-privacy.md`
- Register files via `pbxproj_add.py`

**Interfaces:**

```swift
protocol ContactsProviding: AnyObject {
    func authorizationState() -> ContactsAuthorizationState
    func requestAccess() async -> Bool
    /// Display names (and optional phone digits) for match hints — no bulk upload of raw contacts to server in v1.
    func fetchMatchHints(limit: Int) async throws -> [ContactMatchHint]
}

struct ContactMatchHint: Equatable, Identifiable {
    var id: String
    var displayName: String
    var phoneDigits: String?
}
```

**v1 match strategy (secure, simple):**
1. Request Contacts access.
2. Fetch limited contacts (e.g. 50) with name + phone national digits only in memory.
3. For each non-empty display name, call existing `FriendRepository.searchPeople(query:)` (or discover + client filter) and union unique `PersonSearchResult`s excluding self/friends.
4. **Do not** POST the full address book to Supabase. If search is too noisy, ship UI with discover list + “from contacts” empty state and file a follow-up RPC issue — still request permission + show honest UX.

- [ ] **Step 1: Protocol + fake + Info.plist usage string**

Usage string direction: “Push uses your contacts to show which friends are already on Push. We don’t message them for you.”

- [ ] **Step 2: VM `enableContacts()` / `skipContacts()`**

```swift
func enableContacts() async {
    let granted = await contacts.requestAccess()
    if granted {
        // build people list from hints + search; fall back to discoverPeople
    }
    screen = .findPeople
    await loadPeopleForFindStep(preferContactMatches: granted)
}

func skipContacts() async {
    screen = .findPeople
    await loadPeopleForFindStep(preferContactMatches: false)
}
```

- [ ] **Step 3: UI — one primer screen; no hard gate**

- [ ] **Step 4: Tests with `FixedContactsProvider`

- [ ] **Step 5: Update privacy doc; commit**

```bash
git commit -m "feat(onboarding): optional contacts match step"
```

**Ship gate:** If Contacts matching quality is blocked, ship Tasks 1–7 with `contacts` step as a **single skippable primer that always continues** (or temporarily route notifications → findPeople and leave contacts stub). Prefer keeping the step in the machine for analytics parity.

---

### Task 9: RootView / bootstrap polish + sign-out from blocked

**Files:**
- Modify: `Push/RootView.swift`
- Modify: onboarding view environment (signOut already on onboarding)
- Test: `AuthBootstrapTests` if prepare paths change

- [ ] **Step 1: Ensure onboarding incomplete users never hit `enter(.app)` without completion.**

- [ ] **Step 2: On `locationBlocked`, surface Sign Out calling existing `SignOutAction`.

- [ ] **Step 3: When completed user enters `.app`, `startIfEligible` OK.

- [ ] **Step 4: Commit**

```bash
git commit -m "fix(onboarding): bootstrap handoff and blocked sign-out"
```

---

### Task 10: Remove dead production privacy-step path + update lab notes

**Files:**
- Remove unused production privacy UI from post-auth router
- Keep `OnboardingPrivacyOption` for DEBUG lab (`OnboardingSetupScreens`) until lab is realigned (optional follow-up)
- Update tests that still expect privacy-first flow

- [ ] **Step 1: Grep for `PostAuthPrivacy`, `skipLocation`, `continueFromPrivacy` — delete production call sites**

```bash
rg "skipLocation|continueFromPrivacy|PostAuthPrivacy|case \\.privacy" Push PushTests
```

- [ ] **Step 2: Build + PostAuthOnboardingTests**

- [ ] **Step 3: Commit**

```bash
git commit -m "chore(onboarding): remove skippable location and privacy picker from production first-run"
```

---

### Task 11: Analytics event hooks (lightweight)

**Files:**
- Create: `Push/Diagnostics/OnboardingAnalytics.swift` (or `Push/Auth/OnboardingAnalytics.swift`)

```swift
enum OnboardingAnalytics {
    static func track(_ event: String, props: [String: String] = [:]) {
        #if DEBUG
        PushLog.bootstrap.debug("onboarding_event \(event) \(props.description, privacy: .public)")
        #endif
        // Future: forward to real analytics client when added.
    }
}
```

- Call at: flow start, each step view (via `onAppear` → VM `didShow(screen)`), location result, complete, open app.

- [ ] **Step 1: Add helper + VM calls (no PII — no names/emails)**

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(onboarding): funnel event hooks for first-run"
```

---

### Task 12: Documentation sync + full verification

**Files:**
- Modify: `Agents.md`, `Claude.md` — Production auth / post-auth bullet to match new spine
- Modify: `tasks/todo.md` for Issue #134 progress
- Optionally: DEBUG lab spine alignment (non-blocking)

- [ ] **Step 1: Update durable docs** (flow: value → location hard gate → ghost → coordinate → optional notif/contacts → find people → done; location not requested at prepare for incomplete users).

- [ ] **Step 2: Full test**

```bash
scripts/test.sh full
```

Expected: green. Fix any regressions in location container tests.

- [ ] **Step 3: Commit docs**

```bash
git commit -m "docs: post-auth onboarding revamp (Issue #134)"
```

---

## Manual QA checklist (before PR)

1. Fresh live account (`--live`): after prepare, **first** screen is Value — **no** OS location dialog yet.
2. Continue → Location primer → Enable → system dialog → Allow → Ghost → Coordinate → Notifications Later → Contacts Later → Find people Continue → Done → Map.
3. Deny location → blocked; Open Settings; enable; return → Try again → continues; never map before complete.
4. Zero friends → map empty Add friends overlay.
5. Returning completed user → map; location may start without onboarding.
6. Mock default launch → no post-auth flow.
7. Sign out from blocked → auth gate.

---

## PR / ship notes

- One PR is fine if Tasks 1–7 + 9–10 + 12 land together; **split Contacts (Task 8)** if matching needs more design.
- PR description should link Issue #134 and the design spec path.
- Call out: prepare location race fix, hard location gate, removed privacy picker / skip location.

---

## Spec coverage self-check

| Spec requirement | Task(s) |
|---|---|
| Approach 2 order | 3–7 |
| Location required + hard gate | 2, 4 |
| Ghost teach only / defaults exact+activity | 4, 5 |
| Coordinate one screen | 5 |
| Optional notifications | 6 |
| Optional contacts | 8 |
| Soft find people | 7 |
| Prepare race fix | 1 |
| Fail-closed needs onboarding | 1–2, 9 |
| No invite v1 | (explicit non-goal; no task) |
| Static teach | 5 |
| Lab visual | 5–6 |
| Analytics | 11 |
| Empty map after | 7 + existing MapEmptyOverlay |
| ≤1 screen per teach section | 5 |
| Tests | each task + 12 |
| App Store contacts disclosure | 8 |

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-29-onboarding-revamp.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — execute tasks in this session with checkpoints  

Which approach?
