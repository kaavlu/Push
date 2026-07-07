# Stable Local App-State Pass — Design (issue #20)

## Goal

Move Push from mostly read-only mock UI into a real **local** app-state
prototype: the stable product actions actually mutate shared app state through
the existing repository seam. No Supabase, auth, networking, realtime location,
notifications, or production backend. Extend the current local data layer; do
not rewrite the architecture.

UI visuals stay unchanged except for the minimal wiring each slice requires.

## Scope

Four slices. The **Feed slice from the issue is intentionally dropped for now**
(no Feed screen, no feed-event writes) per product direction.

1. Shared cross-screen refresh — store revision broadcaster.
2. Start Push creates a real `PushPlan`.
3. Push responses are shared and persistent locally.
4. Profile / status / privacy settings persist locally.

### Out of scope (stays mocked)

Feed (dropped for now), Add Friend / Add Group flows, invites / link sharing,
Ask to Join, Ping Group, full Manage Push UX, production notifications, Supabase
schema, auth/session, realtime location, and **Ghost Mode behavior** (Ghost Mode
remains a UI-only option — it is on the "do not build yet" list).

## Existing architecture (context)

Data flows one direction:
`SeedData → InMemoryDatabase → Repositories → ViewModels → (builders) → Views`.

- `InMemoryDatabase` (`@MainActor`) holds normalized tables plus seed-ordered
  arrays. Today the **only** mutation is `setResponse(...)`.
- Six `async throws` repository protocols; `Local*` implementations wrap the
  database. `AppDataContainer` is the composition root (`.shared` for the app,
  isolated instances for tests).
- View models take a `container:` init, call `load()` once in `init`, and fill a
  `LoadState`. They currently do **not** reload after writes, so tab-held
  `@StateObject`s go stale.

## Slice 1 — Shared refresh via store revision broadcaster

`InMemoryDatabase` becomes the single change source of truth.

- Conform `InMemoryDatabase` to `ObservableObject`; add
  `@Published private(set) var revision: Int = 0`.
- A private `didMutate()` increments `revision`. **Every** mutating method calls
  it exactly once, at the end, after all table updates are applied.
- `AppDataContainer` exposes the database's change signal (the database itself,
  or its `objectWillChange` / `$revision` publisher) so view models can observe.

### Discipline (prevents reload loops)

- `revision` is emitted **only after a mutation**, never during `load()` / read
  paths. Reads and builders must not write back to the store.
- Each observing view model stores `private var lastSeenRevision: Int` and, on a
  change signal, reloads **only if** the store's current revision differs from
  `lastSeenRevision`; it updates `lastSeenRevision` when a load completes.
- All mutations and revision publishing happen on `@MainActor` (single
  serialized path — the database is already `@MainActor`). No background writes.

### View-model wiring

Add a small shared subscription helper (e.g. a base pattern or a tiny mixin)
that each `ObservableObject` VM invokes in `init` after its first `load()`:
subscribe to the container's change signal → guard on `lastSeenRevision` →
`Task { await load() }`. `load()` is already idempotent, so no logic rewrite.

VMs wired: `PlansViewModel`, `ProfileViewModel`, `MapViewModel`,
`GroupsViewModel` (any screen that must not stay stale after a write). The
`StartPushViewModel` is transient (modal) and does not need to observe.

## Slice 2 — Start Push creates a real PushPlan

### Domain change (targeted, not a redesign)

`PushPlan`:
- `groupID: FriendGroup.ID?` — now optional (friends-only pushes have no group).
- `placeID: Place.ID?` — now optional (free-text location may not map to a seed
  `Place`).
- Add `locationText: String?` — the creator's free-text location when there is
  no `placeID`.

Update all constructions of `PushPlan` (seed + builders + tests) and the
builders that read these fields to handle `nil` gracefully.

### PushDraft

A value type carrying the Start Push flow output:
title (from `pushText`), `selectedRecipientIDs`, `startsAt` (from
`selectedTime`), free-text `location`, `notes`, and `creatorID`.

### Recipient mapping (pragmatic)

- **One group selected and no friends** → `audience: .group`, `groupID` = that
  group, invitees = that group's active members.
- **Otherwise** → `audience: .inviteesOnly`, `groupID: nil`, invitees = selected
  friends ∪ members of any selected groups.
- **Invitee/response rules:** build the invitee set, **dedupe** it, then
  **exclude the creator**. Each remaining invitee gets a `.pending`
  `PushResponse`. Insert the creator's response as `.in` exactly once. This
  guarantees the creator never appears twice and never gets both `.pending` and
  `.in`.
- `state: .collecting`. `hasExplicitTime`/`isApproximateTime` from the flow
  (default explicit, not approximate). `placeID: nil` + `locationText` when the
  typed location does not match a seeded place; otherwise resolve to the place.

### Store mutation (atomic)

Single public mutation:

```
func createPush(plan: PushPlan, responses: [PushResponse])
```

It inserts the plan (into `plansByID` and `orderedPlans`) **and** all initial
responses **together**, then calls `didMutate()` **once**. Private helpers may
exist internally, but the public entry point is atomic so no observer can
observe a plan without its responses.

### Repository + view model

- `PushRepository.createPush(_ draft: PushDraft) async throws -> PushPlan.ID`.
  The local impl assembles `PushPlan` + `[PushResponse]` per the mapping rules
  and calls the atomic store mutation.
- `StartPushViewModel.submit()` builds the `PushDraft` from its published state,
  calls the repo, and completes. Step 4's primary action triggers `submit()`
  (then dismiss). The revision bump makes the Pushes tab reload and show it.

### Builders

`PlansContentBuilder`: nil `groupID` → label from recipient/creator context
(e.g. primary recipient name) instead of group name; nil `placeID` → show
`locationText`, or a neutral "TBD" when both are absent.

## Slice 3 — Responses shared & persistent

Already writes via `setCurrentUserResponse` → `setResponse` (which now calls
`didMutate()`). With slice 1, a swipe / "I'm in" / "Maybe" write triggers a
revision bump; other screens showing the same push reload and reflect the new
response. Verify the review deck and Pushes cards both read the same
`responses`. No new schema; add write→reload tests.

## Slice 4 — Profile / status / privacy persist

Display **name/initials live on `Person`**; `handle` and the toggle arrays live
on `UserProfile`; availability's canonical home is
`PresenceStatus.availability`.

### Store mutations

- `updatePerson(id:displayName:initials:)` — profile basics on `Person`.
- `updateProfile(handle:activityVisibility:mapPreferences:closeFriends:)` — on
  `UserProfile`.
- `setAvailability(_:)` — updates the current user's `PresenceStatus.availability`
  with `source: .manualOverride`, and mirrors `UserProfile.chosenAvailability`.

Each is `@MainActor`, applies its table updates, then `didMutate()` once.

### Repository + view model

- New methods on `ProfileRepository` (profile basics + toggles) and
  `FriendRepository` (availability), wrapping the store mutations.
- `ProfileViewModel` save actions (`setProfileBasics`, `select(availability)`,
  the three toggle methods) write through the repo instead of mutating only
  `@Published` state. The profile reloads from the store via the revision
  broadcaster (single source of truth — no duplicate local copy drifting).

### Visibility

Map/friend visibility keeps using the existing `SharingPolicy` resolution
untouched. Availability changes flow through `PresenceStatus`, so the map
reflects the user's chosen status. Ghost Mode stays UI-only.

## Testing

Add focused tests for each new write path (isolated `AppDataContainer`):

- **createPush:** inserts the plan + `.pending` responses for deduped invitees,
  creator response is `.in` exactly once, plan appears in `activePlans()`,
  friends-only push has `groupID == nil` / `audience == .inviteesOnly`.
- **Atomicity:** after `createPush`, plan and its responses are both present
  (single revision bump).
- **Responses:** write survives a reload; other read paths see the new value.
- **Profile:** basics, availability (+ `PresenceStatus` mirror), and toggle
  writes persist and reload from the store.
- **Revision:** a mutation increments `revision`; a read/`load()` does not; a VM
  with matching `lastSeenRevision` does not double-reload.

Run: `xcodebuild test -project Push.xcodeproj -scheme Push -destination
'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests
-parallel-testing-enabled NO`. Register any new `.swift` files with
`scripts/pbxproj_add.py`.

## Migration path (unchanged)

The repository protocols remain the seam. The revision broadcaster maps onto a
Supabase realtime subscription; `createPush` / profile mutations map onto
insert/update calls. View models and builders need no further change.

## Compromises

- `PushPlan` gains two optionals + one field. Bounded change, ripples into seed
  and builders, but avoids a schema redesign and faithfully models friends-only
  and free-text-location pushes.
- Free-text location is stored as text (`locationText`) rather than promoted to
  a first-class `Place`; good enough for the prototype and a clean future
  migration (geocode → `Place` later).
