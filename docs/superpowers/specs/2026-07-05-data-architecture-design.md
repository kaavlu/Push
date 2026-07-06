# Standardize Data Architecture — Design

**Issue:** [#15](https://github.com/kaavlu/Push/issues/15)
**Date:** 2026-07-05
**Status:** Approved

## Goal

Replace the six scattered mock-data enums with a single local data layer that behaves
like a mock backend: centralized normalized seed data, an in-memory store, async
repository protocols, and view models that derive screen-specific presentation models.
The UI keeps its current content and visuals. No backend, no Supabase yet — but the
repository seam is where Supabase plugs in later without touching UI or view models.

## Audit findings (current state)

Mock data sources today:

| Source | Owns | Consumed by |
|---|---|---|
| `RealWorldMockData` | Friend + group seeds, puck factory helpers | Map pucks, groups, Start Push step 4 |
| `MapPuckMockData` | 5 map pucks with coordinates | `ContentView` |
| `PlansMockData` | 5 pushes, calendar hangout history, `mostActiveGroup` | `PlansViewModel` |
| `GroupsMockData` + `SeededGroupFriends` | Group cards, per-friend availability table | `GroupsViewModel`, `GroupDetailView`, Start Push |
| `ProfileMockData` | Current user, toggles, connectors | `ProfileViewModel` |
| `PuckLabMockData` | Design-lab puck scenarios | `PuckLabView` (dev tool) |

Problems:

1. **Contradictory availability.** `SeededGroupFriends` says Ram is `.maybeDown` and
   Ohm is `.busy`; the map shows both `.joinable`. Ram appears at two places at once
   (Dolores cluster and Crunch).
2. **Five duplicate person representations** (`RealFriendSeed`, `FriendPuckData`,
   `PushGroupMemberData`, `HangoutPerson`, `PushRecipientItem`), each re-deriving
   name/initials/image path.
3. **Unstable identity.** `FriendPuckData.id` is a fresh `UUID()` per construction;
   `withWhom` references people by display-name strings.
4. **Stored values that should be derived:** group activity counts, `mostActiveGroup`,
   prebaked social proof strings ("3 in · 2 maybe").
5. **Presentation baked into data:** "8 min ago", "At Blue Bottle", "Suggested: North Park".
6. **Group names duplicated** across the `FriendGroupFilter` enum, plan `group` strings,
   and group seeds.
7. **No place entities** — coordinates live only on map pucks; venue names are free strings.
8. **View-layer leaks:** `ContentView` reads `MapPuckMockData` directly;
   `StartPushStep4View` calls `RealWorldMockData.friend(withID:)`.

## Decisions (user-approved)

- **Architecture:** in-memory store + async repository protocols (not SwiftData, not Combine).
- **Model scope:** everything current screens render, plus `FeedEvent` and `PushResponse`
  models with seed data (no speculative UI).
- **PuckLab:** keeps hand-crafted fixtures; renamed to make clear they are design
  fixtures, not app data.
- **Conflicts:** map values win; other screens re-derive from canonical status.

## Canonical domain models

All entities are plain structs with stable `String` IDs, `Codable`, `Equatable`,
in `Push/Data/Domain/`.

| Entity | Stored fields | Notes |
|---|---|---|
| `Person` | `id` (slug, e.g. `"chitty"`), `firstName`, `imageAssetPath` | `displayName`, `initials` computed once here |
| `FriendGroup` | `id`, `name`, `memberIDs: [Person.ID]`, `imageAssetPath` | counts/stats/status all derived |
| `Place` | `id`, `name`, `shortLabel`, `coordinate` | ~7 seeded places |
| `PresenceStatus` | `personID`, `availability: FriendAvailabilityState`, `activity` (name + SF symbol), `placeID?`, `statusNote?`, `updatedAt: Date` | exactly one per person; `FriendAvailabilityState` stays canonical |
| `PushPlan` | `id`, `title`, `groupID`, `creatorID`, `timing` (Date-based), `placeID`, `placeIsSuggested: Bool`, `state: .collecting/.locked/.happening` | all current location hints map to seeded places; "Suggested:" prefix derived from the flag |
| `PushResponse` | `pushID`, `personID`, `response: .in/.maybe/.out/.pending` | social proof derived from these |
| `PastHangout` | `id`, `date: Date`, `participantIDs`, `note`, `timeRange`, `cameFromPush`, `didHappen` | calendar aggregates derived |
| `UserProfile` | current user personID, handle, visibility note, availability options, toggle groups, connectors | today's `ProfileMockData` content |
| `FeedEvent` | `id`, `kind: .arrived/.becameFree/.groupForming/.pushCreated`, `actorIDs`, `placeID?`, `groupID?`, `timestamp` | seeded, no UI yet |

### Stored vs derived

Derived, never stored:

- `withWhom` — other people whose status shares the same `placeID`.
- Map pucks and kind — people sharing a place form one puck; 1 person = `.individual`,
  2 = `.hangout`, 3+ = `.cluster`, all members of a group co-located = `.friendGroup`.
- Group stats (`activeNowCount`, `nearbyCount`, `planCount`) and status badge.
- Social proof ("3 in · 2 maybe") from `PushResponse` rows.
- Relative time labels ("8 min ago") from `updatedAt`; push timing labels
  ("Friday, 9:00 PM", "now") from `timing` Dates.
- `mostActiveGroup`, calendar day aggregates (push count = hangouts that day,
  had-plan = any `cameFromPush`, almost-happened = any `!didHappen`).
- Group filter chips (replaces the hardcoded `FriendGroupFilter` enum).
- Start Push recipient lists; all initials and display names.
- Presentation `PlanStatus` pills derive from `(PushPlan.state, my PushResponse)`;
  swipe deck semantics (right = joined, left = waiting, up = open) unchanged.
- `venueStatusText` = `statusNote` if curated, else "At/Near {place.name}".

## Layers

```
Push/Data/
  Domain/            entity structs (one file per entity)
  Seed/              SeedData — the single home for all app content
  Store/             InMemoryDatabase (@MainActor, [ID: Entity] tables)
  Repositories/      protocols (async funcs) + Local* implementations
  AppDataContainer.swift   composition root
```

- Repository protocols: `FriendRepository`, `GroupRepository`, `PushRepository`,
  `ProfileRepository`, `FeedRepository`. Async APIs (`func friends() async -> [Person]`
  style) so a Supabase implementation is a drop-in.
- `AppDataContainer` owns the store and repositories; injected at app root. View models
  take repositories via init with defaults from the shared container so previews and
  tests keep working.
- View models build the **existing presentation structs** (`FriendPuckData`,
  `MapPuckData`, `PushGroupData`, `PlanData`, `HangoutPerson`, `PushRecipientItem`,
  `ProfileData`) via selector/builder functions, so views need minimal changes.
- `ContentView` gets a small `MapViewModel` (fixes direct mock access);
  `StartPushStep4View` reads recipients from its view model.
- `FriendPuckData.id` changes from `UUID` to the stable person ID (`String`).

## Seed migration + documented content changes

Seed reproduces today's screens: 10 friends + current user, 3 groups, ~7 places,
one status per person, 5 pushes with responses matching current social-proof counts,
past hangouts matching the current calendar pattern, profile settings, ~5 feed events
consistent with statuses.

Documented content corrections (canonical version chosen per "map wins"):

1. **Ram was in two places at once.** He stays at Crunch (the scene that includes the
   current user); the Michigan Dolores cluster becomes Rohan/Ryan/Pranay (3 avatars
   instead of 4).
2. **Groups-screen availabilities** re-derive from canonical statuses; where the old
   table contradicted the map (Ram, Ohm), the map value shows.
3. **Push social proof** derives from response rows; count-based copy is preserved,
   curated copy like "Chitty is there · Ishan maybe" is approximated by derived copy.

Old mock enums are deleted after rewiring: `MapPuckMockData`, `PlansMockData`,
`GroupsMockData`, `SeededGroupFriends`, `ProfileMockData`, `RealWorldMockData`.
PuckLab fixtures remain, renamed (e.g. `PuckLabFixtures`).

## Error handling

The local layer cannot fail at runtime, but the seed can be wrong at build time:
seed referential integrity (every referenced ID resolves, every asset path exists,
exactly one status per person) is enforced by unit tests rather than runtime checks.
Repository APIs return values (no throws) until a real backend introduces failure modes.

## Testing

- Rewire existing tests (`GroupsTests`, `PlansViewModelTests`, `PushTests`) to
  repositories/builders.
- New tests: seed referential integrity; single-status-per-person; derivations
  (withWhom, puck grouping/kind, group stats, social proof, calendar aggregates);
  swipe-deck response mapping.
- Xcode previews continue to work through the shared container.

## Documentation

`docs/data-architecture.md`: how to add a user, group, push, place, status, or feed
event; how derivations work; the Supabase swap path (implement the repository
protocols, convert seed to SQL seed/migrations).

## Risky areas

- `PlanStatus` split must keep the Pushes screen pills and swipe deck identical.
- Derived time labels replace stored strings; seed dates chosen so today's copy renders.
- Puck derivation must reproduce the current map exactly, apart from the Ram fix.
- `FriendPuckData.id` type change (`UUID` → `String`) ripples through views and tests.

## Out of scope

Backend, auth, Supabase, networking, persistence across launches, new product behavior,
visual redesign, Feed/Who's Down UI.
