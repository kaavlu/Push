# Push Data Architecture

Push runs entirely on local mock data, but that data is organized like a
production data layer so a real backend (e.g. Supabase) can be swapped in
without touching the UI. This document explains the layers, how to add
content, how derivations work, and the migration path.

## Layers

```
Push/Data/
  Domain/            Canonical entity structs (one file each)
  Seed/              SeedData — the single home for all app content
  Store/             InMemoryDatabase — normalized [ID: Entity] tables
  Repositories/      Repository protocols (async throws) + Local* impls
  Derived/           Builders that turn canonical data into screen models
  LoadState.swift    idle / loading / loaded / failed
  AppDataContainer   Composition root; injected into view models
```

Data flows one direction:

```
SeedData → InMemoryDatabase → Repositories → ViewModels → (builders) → Views
```

- **Domain** (`Push/Data/Domain/`): `Person`, `FriendGroup`, `GroupMembership`,
  `Place`, `PresenceStatus`, `SharingPolicy`, `PushPlan`, `PushResponse`,
  `PastHangout`, `FeedEvent`, `FriendRequest`, `UserProfile`. All are `Codable`, `Equatable`,
  and keyed by stable **opaque `String` IDs**. Seed IDs are readable slugs
  (`"chitty"`, `"michigan"`) for convenience; production IDs will be UUID/ULID.
  Never derive identity from display names outside `SeedData`.
- **Seed** (`Push/Data/Seed/`): `SeedData.standard(now:)` builds the full graph.
  Split across `SeedData.swift` (people, groups, memberships, places, policies),
  `SeedData+Presence.swift` (statuses, profile), `SeedData+Plans.swift`
  (plans, responses), `SeedData+History.swift` (hangouts, feed events).
- **Store** (`Push/Data/Store/InMemoryDatabase.swift`): `@MainActor` class holding
  dictionary tables plus seed-ordered arrays for deterministic UI. The only
  mutation today is `setResponse(...)` (the swipe deck writes the current
  user's push response through it).
- **Repositories** (`Push/Data/Repositories/`): protocols including `FriendRepository`,
  `GroupRepository`, `PushRepository`, `ProfileRepository`, `SharingRepository`,
  `FeedRepository`, and `AlertRepository`. Every method is `async throws`. The `Local*` implementations
  never throw, but the seam already supports failure so a backend won't force a
  rewrite. View models catch errors into `LoadState.failed`.
- **Alerts**: mock accept/deny resolves `FriendRequest` rows in the store and
  bumps its revision. Live uses `EmptyLiveAlertRepository` until friendship
  writes are in scope.
- **Derived** (`Push/Data/Derived/`): pure builders — `VisiblePresenceBuilder`,
  `MapContentBuilder`, `GroupContentBuilder`, `PlansContentBuilder`,
  `ProfileContentBuilder`, plus `RelativeTimeFormatter` and `PushTimingFormatter`.
- **AppDataContainer**: owns the store and repositories. `AppDataContainer.shared`
  is the app default; tests build isolated `AppDataContainer(seed: .standard())`
  instances. View models take a `container:` init and expose a `load()` that
  fills a `LoadState`.

## Registering new Swift files

The Xcode project (objectVersion 56) does not auto-discover files. After
creating a `.swift` file, register it:

```bash
# App target (paths relative to Push/)
python3 scripts/pbxproj_add.py Data/Domain/NewEntity.swift
# Test target (paths relative to PushTests/)
python3 scripts/pbxproj_add.py --target tests NewTests.swift
```

The helper is idempotent and quotes names so `+`-containing filenames work.

## How to add content

All content lives in `SeedData`. Add it there, then run the seed-integrity
tests (`DataLayerTests`) — they fail loudly if any reference dangles.

- **A person:** add to `standardPeople()` in `SeedData.swift`. Add a
  `PresenceStatus` in `standardStatuses(now:)` (exactly one per person) and a
  full-visibility `SharingPolicy` is created automatically for every person.
  Add an image at `assets/friends/<slug>.png`.
- **A group + memberships:** add a `FriendGroup` in `standardGroups()` and a
  roster entry in `groupRosters` (first member = owner). Counts/stats/badges
  are derived — do not hand-set them.
- **A place:** add a `Place` in `standardPlaces()` with `shortName` (puck label),
  `address` (street line), and `vagueLabel` (neighborhood, used when a sharing
  policy softens location).
- **A push + responses:** add a `PushPlan` in `standardPlans(now:)` (set
  `startsAt`, `hasExplicitTime`, `isApproximateTime`, `placeIsSuggested`) and its
  `PushResponse` rows in `standardResponses(now:)`. Social proof and pills derive
  from the responses.
- **A past hangout:** add to `standardHangouts(now:)`. Set `cameFromPush` /
  `didHappen`; the calendar aggregates them.
- **A sharing policy:** add a `SharingPolicy` in `standardPolicies(...)` or a
  per-friend/per-group override. Resolution picks the most specific active one.
- **A feed event:** add to `standardFeedEvents(now:)`. Feed events are a
  materialized read model (no UI yet) — seed them to mirror the presence/plan
  facts they represent.

## Derivations (stored vs. derived)

Nothing about presentation is stored. Key rules:

- **Visible presence** (`VisiblePresenceBuilder`): raw `PresenceStatus` is
  internal-only. A viewer sees a `VisiblePresence` after applying the owner's
  most specific active `SharingPolicy` (friend → group → globalDefault).
  Location can be exact / vague (neighborhood) / hidden; activity full / vague /
  hidden; availability full / hidden (hidden = off the board). Self sees
  everything. Seeded policies are full-visibility defaults, so today's screens
  render unchanged; the vague/hidden paths are covered by `DerivationTests`.
- **Map pucks** (`MapContentBuilder`): people sharing an exact place form one
  puck. 1 person = individual, 2 = hangout, 3+ = friendGroup if the set equals a
  group's active membership, else cluster. Being together makes a multi-person
  puck `.joinable`. `withWhom` is the other co-located people. Current user
  renders last.
- **Group cards** (`GroupContentBuilder`): member lists/counts from active
  memberships; `activeNowCount` = members co-located with ≥2 people; `nearbyCount`
  = members with a place but solo; badge priority planLive → activeNow → nearby →
  freeSoon → quiet. Member rows use canonical availability.
- **Push cards** (`PlansContentBuilder`): timing labels via `PushTimingFormatter`
  ("now", "~7:45 PM", "Friday, 9:00 PM", "Saturday"); social proof from response
  counts; pill from the current user's response (in→joined, maybe→open, out→
  waiting, pending→pending). Calendar aggregates hangouts per day.
- **Profile** (`ProfileContentBuilder`): header from `UserProfile` + `Person` +
  self visible presence; `placeTitle` uses the neighborhood (soft-places).
- **Relative time** (`RelativeTimeFormatter`): current user → "Now", <1 min →
  "Just now", else "N min ago".

## Documented content changes vs. the old mocks

The old scattered mocks contradicted each other. Canonical values were chosen
"map wins" and these visible changes resulted:

1. **Ram is at one place.** He was in both the Michigan Dolores cluster and the
   Exec/Crunch scene. He now stays at Crunch; the Dolores cluster is
   Rohan/Ryan/Pranay (3 avatars, was 4).
2. **Nitin's group-screen availability** is now `maybeDown` (canonical/map),
   where the old groups table said `joinable`.
3. **Group stats/badges are derived**: India 2 active / 2 nearby / 1 push,
   Exec 3 / 0 / 2, Michigan 5 / 0 / 2; Exec badge is now `activeNow`.
4. **Profile place** is "Near North Beach" (Crunch's neighborhood), was the
   stored "Near Hayes Valley".
5. **Current-user initials** are "MA" (firstName-derived, consistent with all
   friends), was the special-cased "MK".
6. **Start Push suggestions** derive from availability: 4 likely-free /
   4 might-be-interested, replacing hardcoded 3 / 5 lists.
7. **`withWhom`** now includes everyone co-located (e.g. Ram's includes Manav).
8. **Puck member order** is deterministic seed order, current user last.

## Live (Supabase) mode — implemented for Day-1 reads (Issue #27)

The repository seam is now wired to Supabase for a reads-only Day-1 social graph.
The mock path is unchanged and remains the DEBUG default.

### Session snapshot and bootstrap

Live social-graph rows are held in one memory-only, authenticated-session-scoped store. Before
`ContentView` is created, `RootView` prepares a live container by fetching `profiles`, `groups`,
`group_memberships`, and `sharing_policies` concurrently. Resource loads coalesce, so overlapping
repository callers share an in-flight request and each table is fetched at most once per session.
The one profiles response supplies the current person, friends, and `UserProfile`. Current-person
and `UserProfile` reads select the row matching the authenticated ID; response order is irrelevant.
Preparation verifies that row exists before installing the container.

Preparation is an all-or-nothing presentation boundary: the root shows branded progress while the
snapshot warms, then installs the prepared container before screen ViewModels capture `.shared`.
A failed warm-up shows Retry and Sign Out rather than a partially populated app. The cache is never
written to disk and a later authenticated session creates a new store.

Live profile/availability writes use PostgREST's returned updated row. Only a successful response
replaces the cached profile and emits one live store revision, causing active ViewModels to reload
from the same snapshot. Failed writes leave both snapshot and revision unchanged. Subsequent
ViewModel reloads keep their last loaded value visible while refreshing.

### Session re-warm (Issue #33)

`AppDataContainer.refreshSession()` re-warms the live snapshot via `LiveDataStore.refresh()`:
clear session caches, concurrent `warm()`, publish one revision on success. Concurrent callers
share one in-flight task; a new scheduled refresh within
`SessionRefreshConstants.minimumInterval` (2s) after a success is a no-op. Failed re-warms restore
the prior cache and do not bump revision. Mock `refreshSession` is a no-op. Call sites: return to
foreground from `ContentView` (skip first active; silent failure) and pull-to-refresh on Friends,
Alerts, and Pushes. User-initiated mutation failures use `ActionErrorState` + `ActionErrorBanner`
with Retry (and optimistic rollback for push RSVP/cancel/delete).

- **Mode selection** — `AppEnvironment.resolve(isDebugBuild:arguments:)`: DEBUG
  defaults to `.mock`; DEBUG opts into `.live` via the `--live` launch argument;
  Release is always `.live`.
- **Composition** — `AppDataContainer.init(seed:)` builds the mock container
  (`InMemoryDatabase` + `Local*` repos, unchanged). `AppDataContainer.live(client:currentUserID:)`
  builds an unprepared live container for isolated tests; the async preparation API warms a shared
  snapshot and `installPreparedLive(...)` swaps `.shared` at bootstrap. In
  live mode there is no `InMemoryDatabase` (reads-only), so `database` is `nil`,
  `storeRevision`/`onStoreChange` fall back to a no-op subject, and identity comes
  from the auth session.
- **Live repositories** (`Push/Data/Supabase/`) — `SupabaseProfileRepository`,
  `SupabaseFriendRepository`, `SupabaseGroupRepository`, `SupabaseSharingRepository`
  read via PostgREST behind RLS; pure `*Row` DTOs (`Rows/`) decode PostgREST JSON
  and map to domain structs. `EmptyLivePushRepository`/`EmptyLiveFeedRepository`/
  `EmptyLiveAlertRepository` return empty and friend presence is `[]` — **no mock presence/push/feed/alert leaks
  into authenticated sessions** (Day-1 scope).
- **Profile settings writes** — unlike the reads-only social graph, the profile
  screen writes to the user's own `profiles` row (`profiles_update_self` RLS):
  `SupabaseProfileRepository.updateBasics` (name/handle) and `.updatePrivacy`
  (Activity visibility / Map preferences / Close Friends toggles, stored as
  `settings_*` `jsonb` id→enabled maps — copy stays client-side in
  `ProfileScaffolding`), plus `SupabaseFriendRepository.setCurrentUserAvailability`
  (Set Status, excluding Ghost Mode, which stays UI-only/unpersisted by design).
  `ProfileRow` merges stored overrides onto `ProfileScaffolding` defaults so an
  id with no stored override still renders with its default copy and state.
- **Auth** — `SupabaseAuthService` (only it + repos touch the SDK) is driven by
  `AuthViewModel`; `RootView` shows `AuthGateView` until authenticated, then
  `ContentView` on a live container. Sessions persist via the SDK's Keychain store.
- **Visibility** — `sharing_policies` is the single source of truth;
  `GroupMembership.sharingLevel` maps to `.full` (membership carries no visibility).
- **Schema/RLS** — repo-first SQL migrations under `supabase/migrations/`
  (`SECURITY DEFINER` helpers hardened in a non-API `private` schema). See
  `supabase/README.md`.

View models, builders, and views need no changes: they already consume
repositories and already handle `LoadState.loading` / `.failed`.

## Testing

- `DataLayerTests` — domain derivations, seed referential integrity, repository
  behavior, `MapViewModel`/`StartPushViewModel` loading incl. a throwing
  repository fake driving `LoadState.failed`.
- `DerivationTests` — sharing-policy resolution, map/group/plan/calendar builders.
- `GroupsTests`, `PlansViewModelTests` — screen view models through repositories.
- `PushTests` — remaining UI/model/style coverage.

Live-mode coverage (Issue #27): `AppEnvironmentTests` (mode selection),
`AuthViewModelTests` (auth state transitions), `SupabaseMappingTests` (row→domain
DTO decoding/mapping), `LiveContainerIsolationTests` (live vs. mock isolation),
`AuthBootstrapTests` (`BootstrapState` gating). These run offline against fakes/JSON;
the authenticated RLS path is proven separately against the real backend (see
`supabase/README.md`).

Prefer the wrapper (separate `DerivedData-Tests/`, serial by default):

```bash
scripts/test.sh suite DataLayerTests   # one class
scripts/test.sh full                   # entire PushTests
scripts/test.sh build                  # compile only
```

`scripts/test.sh` resolves the worktree visual sim UDID via
`run-ios-sim.sh ensure-booted-udid` (e.g. `Push - main - iPhone 17`) and
passes `-destination platform=iOS Simulator,id=<udid>`. Do **not** use stock
`name=iPhone 17` — that opens a second unlabeled Simulator and is flaky.
Parallel testing intermittently drops the simulator runner; keep serial unless
you know it is stable.
