# Push — Project Guide

## What is Push

Push is a private live map for real friends. The core value prop: **know the move before the group chat does.**

It helps close friends understand what's happening around them — where people are, what they're doing, who they're with, and whether something social is forming — without needing to text everyone.

Push is **not** a tracking app, not a generic map app, and not a chat app. It should feel like a premium Apple-native social layer for real life.

---

## Stack

- **Platform:** iOS
- **Framework:** SwiftUI
- **Target:** iOS 17+
- **Architecture:** MVVM
- **Data:** Parallel mock/live via `AppDataContainer` (mock `init(seed:)`; live `prepareLive`/`installPreparedLive`). `RootView` owns session bootstrap — mock skips auth; live restores session or `AuthGateView`, warms a session-scoped `LiveDataStore` (profiles/groups/memberships/policies/pushes/responses), then installs `.shared` before `ContentView` ViewModels init. Sync `.live(...)` remains for isolated no-network tests. Live has no `InMemoryDatabase` (`database` nil). Live client: `supabase-swift` SPM (`Supabase` product, ≥2.0) — `import Supabase` only in auth/repo layer, not Views. Client credentials: committed `Push/Config/Supabase.xcconfig` (project URL + anon key only — never service-role); partial `Push/Info.plist` merges those keys with `GENERATE_INFOPLIST_FILE=YES` (Xcode does not inject arbitrary custom `INFOPLIST_KEY_*`). Read via `SupabaseConfig`; use `SupabaseClientProvider.shared` in `Push/Data/Supabase/`. DEBUG defaults mock; `--live` opts in; Release always live. Day-1 live social graph reads (friends, groups, sharing policies) plus profile **self-writes** and **push coordination** (`SupabasePushRepository` — create/edit/cancel/delete, RSVP; tables `pushes`/`push_responses`, migrations 0006–0008) — presence/feed return empty in live mode (no mock data leaks); friend requests are live via SupabaseAlertRepository + 0009; remove friend via `FriendRepository.removeFriend` + `0010`. Layout: `Push/Data/` — Domain, Seed, Store, Repositories, Derived, `AppDataContainer`. Spec: `tasks/spec.md` (Issue #27). Guides: `docs/data-architecture.md`, `docs/superpowers/specs/2026-07-05-data-architecture-design.md`, `docs/superpowers/plans/2026-07-12-supabase-migration-day1.md`. Supabase (`supabase/README.md`): `migrations/` (apply via MCP), idempotent `seed.sql` for public graph (test users via real Auth — never SQL into `auth.users`; `@pushapp.dev` emails, Confirm email OFF); use `.claude/skills/supabase*` skills. `group_memberships` is membership-only (no visibility column; `sharing_policies` is the sole visibility source per spec R3). `SECURITY DEFINER` RLS helpers (e.g. `private.is_friend`, `private.is_group_member`, `private.shares_group`) live in non-API-exposed `private` schema — not `public` — so policies can call them without PostgREST RPC exposure.
- **Maps:** MapKit — live map base layer is satellite imagery (`MKImageryMapConfiguration`, flat elevation), not muted standard

This is a **high-fidelity prototype** that can become production later.

---

## MVP Features

1. **Live Map** — center of the app; friends shown with immediate social context
2. **Friend Status** — live status per friend (place, activity, availability, who they're with)
3. **Friend Detail** — tap a friend to see more; lightweight, not a full profile
4. **Feed** — real-life social activity (arrivals, availability shifts, groups forming)
5. **Who's Down** — quick answer to "is anything happening right now?"
6. **Pull Up** — low-pressure signal of social intent (faster than starting a group chat); creation UX is the 4-step **Start Push** flow (`StartPushFlowView`); launch from map create menu (`MainMapRoute.startPush`) or Pushes tab (`PlansView`).
7. **Friend Groups** — real-world circles with member statuses, activity, pushes
8. **Push Cards** — shared coordination objects (not chat threads)
9. **Privacy Controls** — simple visibility settings per activity

### Availability States
`Free now` · `Free soon` · `Maybe down` · `Busy` · `Joinable` · `Driving / ETA`

---

## What NOT to Build Yet

- Live writes to social graph (friends/groups/sharing), realtime/subscriptions — profile self-writes (basics, toggles, availability, photo), push coordination (create/edit/cancel/delete, RSVP), and friend-request coordination (search/send/accept/deny via `0009`; remove via `0010`) are allowed
- Real-time location sharing
- Real activity inference
- Push notifications
- iMessage extension
- Ghost Mode
- Large groups
- Weekly recap history (History › stub)
- Dating / social graph features

---

## Design Direction

**Feel:** Premium, Apple-native, social, lightweight, clear, calm, trustworthy, high-fidelity.

**Avoid:** Generic map app feel, surveillance dashboard feel, chat app feel, social media clone feel, enterprise dashboard feel.

**Glass + accents:** Brand colors live in `Push/PushColorPalette.swift` — walnut for foreground/text, sunbeam for active fills. Use `PushControlColors` text hierarchy (`textEspresso`, `textPrimary`, `textSecondary`, `textTertiary`); do not use black or system primary. Reuse `PushGlassStyle`, `PushControlColors`, and `PushControlStyle` for all glass controls; do not one-off material values. Prefer native `glassEffect` on iOS 26+ (layered with warm tint, stroke, shadow); iOS 17 uses the shared material fallback in `pushGlassBackground`. Hero map top controls use `ContentView`'s `topControlBackground` (material + warm tint), not `pushGlassBackground`.

**Adaptive layout:** `PushAdaptiveLayout` tiers by container width (compact <380, standard <420, large ≥420). `PushAdaptiveLayoutReader` at app root injects `@Environment(\.pushLayout)`; `*Style` helpers take `PushAdaptiveLayout` and use shared metrics (`pageHorizontalPadding`, `cardCornerRadius`, `puckScale`, etc.) — not one-off spacing constants. DEBUG previews: `PushPreviewMatrix` — wrap `*_Previews` in `#if DEBUG` so Release builds compile.

**Design reference (`Design/`):** Handoff bundle for visual work — `PushDesignBrief.md`, `PushThemeAudit.md`, verbatim snapshots in `CoreDesignFiles/`, copied imagery in `Assets/`. Read-only references; implement changes in `Push/`, not in `Design/`.

---

## Coding Standards

See `coding-standards.md` for the full reference. Key rules for this project:

- **MVVM strictly.** ViewModels own state and logic; Views are dumb.
- **Mock by default.** DEBUG uses mock unless `--live`; Release uses Supabase. No direct Supabase/network from Views or application ViewModels — injected repos only; auth via `AuthService` (`SupabaseAuthService` / `FakeAuthService` in `Push/Data/Supabase/AuthService.swift`; app layer uses `AuthViewModel` only). With supabase-swift, session user maps as unqualified `User`, not `Auth.User`. No real location.
- **Profile images:** Seed/mock use bundle paths under `assets/friends|groups|profile|onboarding/`; live photos upload to Supabase Storage `avatars` (`0012`) with the public URL on `profiles.image_asset_path`. Resolve via `AvatarImageLoader` (bundle, local file, or HTTPS) — not `PushImageAssets` alone; avatar views use initials fallback when nil.
- **Seed data:** Single canonical source in `Push/Data/Seed/SeedData` (scattered `*MockData` / `RealWorldMockData` deleted — do not recreate for app screens). Opaque `String` IDs (seed may use readable slugs; never couple identity to display names). Group membership via `GroupMembership` rows, not stored `memberIDs`. Stats, social proof, timing labels, calendar rows, and map pucks are **derived** — never stored in seed. PuckLab and Onboarding Lab keep isolated design fixtures (`PuckLabFixtures`, `OnboardingLabFixtures`), not app data.
- **Repositories:** All protocols are `async throws` (local impls never throw); ViewModels take repos via init with optional `container: AppDataContainer? = nil` resolved as `?? .shared` in the init body (not `= .shared` in the default — mutable MainActor static). Expose primary content via `LoadState<Value>`. User-initiated edits persist via repo write methods (store + `didMutate()`), not ViewModel-local state only. Derived builders produce presentation structs from canonical domain data — presence builders use **`VisiblePresence`** (sharing-policy–filtered), never raw `PresenceStatus`. Views must not read mock enums or seed directly.
- **Supabase UUID strings:** PostgREST returns lowercase UUIDs; `SupabaseAuthService` lowercases `AuthedUser.id` into `AppDataContainer.currentUserID` — do not compare DB-sourced id strings against raw `UUID.uuidString` (uppercase).
- **Supabase row mapping:** PostgREST DTOs in `Push/Data/Supabase/Rows/` use snake_case properties matching table columns (no `CodingKeys`); map to domain via `*Row.*()` helpers. `timestamptz` columns decode as `String` and parse via ISO8601 (fractional seconds first) — not `Date`; default `JSONDecoder` date strategy fails on PostgREST strings. DB snake_case enums that don't match Swift `rawValue:` need explicit mapping — e.g. `profiles.availability_choice` (`free_now` → `FriendAvailabilityState`), `sharing_policies.audience_type` (`global_default` → `.globalDefault`). Profile toggle/connectors copy comes from `ProfileScaffolding`; live persists per-id enabled overrides in `settings_*` `jsonb` (`0005_profile_settings`), merged in `ProfileRow`. `GroupMembershipRow` sets `sharingLevel: .full` (R3). Live reads map from `LiveDataStore` (not per-call PostgREST); `SupabaseLiveDataLoader` owns network I/O. Initial warm fetches six tables concurrently with in-flight coalescing; one profiles response feeds current user, friends, and profile — current-user/`UserProfile` via `LiveDataStore.profile(userID:)` (case-insensitive match on `currentUserID`), never `profiles().first` (response order is undefined). `prepareLive` verifies that row exists before installing the container. `SupabaseFriendRepository` excludes self (RLS scopes friends/co-members; do not query `friendships`); `SupabaseGroupRepository` reads groups/memberships; `SupabaseSharingRepository` reads policies. Day-1 feed: `EmptyLiveFeedRepository` — empty reads. Alerts: live `SupabaseAlertRepository` (pending friendships); `EmptyLiveAlertRepository` remains for inert tests. Pushes: `SupabasePushRepository` via `LiveDataStore` (session-cached like the social graph; `notifyPushesChanged()` clears cache and bumps once per logical write); `PushRow`/`PushResponseRow` + `PushDateFormatting`; recipient tokens via shared `PushRecipientResolver`. Other live repo writes throw `SupabaseRepositoryError.writeNotSupported` except profile: `SupabaseProfileRepository.updateBasics`/`updatePrivacy`/`updateProfilePhoto`/`removeProfilePhoto` (Storage via `ProfilePhotoStoring`; rollback orphan uploads on profile-write failure), `SupabaseFriendRepository.setCurrentUserAvailability` (Ghost Mode stays UI-only), and `SupabaseFriendRepository.removeFriend`.
- **Store refresh:** Mock: `InMemoryDatabase` bumps `@Published revision` via `didMutate()` after every write (never on reads). Live: `LiveDataStore` bumps revision on successful profile/availability write-through (PostgREST returned row replaces cache; failed writes leave cache/revision unchanged), on `notifyPushesChanged()` after push writes, and on `notifyFriendshipsChanged()` after friend-request writes (accept/remove clear profile warm cache so the Friends list refreshes). Unprepared sync `.live(...)` falls back to a no-op subject for isolated tests. ViewModels subscribe via `AppDataContainer.onStoreChange`, guard on `lastSeenRevision` (stamp at end of `load()` to avoid reload loops), and call `load()` on change; reloads preserve last loaded value while refreshing. New mock mutating store methods must call `didMutate()`. Multi-row writes that must appear together (e.g. `createPush`, `updatePush` plan + responses) use a dedicated atomic store method with one `didMutate()`.
- **Live map:** `MapViewModel` owns puck `LoadState`, group filters (`GroupFilterItem`), `filteredPucks`, `selfPuck`, and `renderPucks(for:)`; `ContentView` tracks `mapSpan`, owns filter-dropdown expansion, and is render-only. Two-stage derivation: `MapContentBuilder` → exact-place `MapPuckData`; `MapDisplayPuckBuilder` → zoom-aware `MapPuckRenderModel` (`.friend`, `.smallGroup`, `.selfPuck`, `.regionalCluster`). Close zoom (`latitudeDelta` ≤ 0.22) shows exact pucks; wider zoom clusters into `RegionalActivityPuck`. Vague-presence people use `Place.vagueCoordinate` for regional sources only. Regional cluster tap sets `MapFocusRequest` to zoom in (no detail sheet). Puck tap presents `FriendDetailBottomSheet` (custom bottom overlay, not SwiftUI `.sheet`); `FriendDetailSheet` is content-only — chrome, height, drag dismiss, and background live in `FriendDetailBottomSheet`. `MapPuckKind` drives content layout; multi-person pucks use `.joinable` availability. Filter by `groupIDs`; `FriendPuckData.id` is `String`. `StyledMapView` diffs puck annotations by ID — remove/add only stale entries.
- **Friends screen:** `MainMapRoute.groups` presents `FriendsView` (bottom nav "Friends"; route id still `groups`). Friends mode: `FriendsViewModel` + `FriendsContentBuilder` — one row per direct friend via `VisiblePresence`; no visible presence → "Hidden right now" row (never dropped). Friends list rows use `ExpandableFriendRow` (`FriendRowCard` inside) on the cream surface; tap expands inline for Directions / Start push / Remove — not `FriendDetailBottomSheet` (map puck tap still uses that sheet). Remove via `FriendsViewModel.removeFriend` → `FriendRepository.removeFriend`. Group member rows still use `FriendRowCard` directly. Groups mode reuses `GroupsViewModel` + `GroupDetailView`. Cream page styling (`FriendsColor`, `friendsCard`), not map glass. DEBUG launch: `--friends`.
- **Alerts:** Map hero bell (`MainMapRoute.alerts`, unread dot) presents full-screen `AlertsView`; incoming `FriendRequest`s only — `FriendRowCard` with Accept/Deny instead of availability. `AlertsViewModel` + `AlertRepository`; mock `LocalAlertRepository` resolves via store (accept adds accepted friend IDs, no presence synthesis); live `SupabaseAlertRepository` (pending `friendships` + `resolve_friend_request` RPC). Replaces `MKCompassButton`; map attribution unchanged. Cream Friends-page styling (`AlertsStyle`).
- **Add Friends:** Full-screen `AddFriendsView` (cream Friends treatment) from map create menu (`MainMapRoute.addFriend`) and Friends “+”. Search/send via `FriendRepository.searchPeople` / `sendFriendRequest`; accept/deny reuse `AlertRepository`. Mock: `acceptedFriendIDs` + discoverable seed people (austin/jordan). Live: `search_profiles` / `send_friend_request` RPCs (`0009_friend_requests`); store invalidates profile cache on accept so Friends list refreshes.
- **Onboarding Lab:** DEBUG-only 12-screen signup primer in `Push/OnboardingLab/`; `OnboardingLabViewModel` + screen splits (`*IntroScreens`, `*AuthScreens`, `OnboardingSignInScreen`, etc.), static `OnboardingLabFixtures` only — no repos/auth/backend in the lab. Parallel returning-user entry: welcome ↔ `.signIn` (`OnboardingAuthSwitchLink`). The theme + components (`OnboardingLabTheme`, `OnboardingLabComponents`, `OnboardingAuthComponents`) are promoted out of `#if DEBUG` for production reuse; the lab screens, fixtures, keypad flow, setup, and mock `completeSignIn()` stay `#if DEBUG`. DEBUG launch: `--onboardinglab`; jump to one screen with `--screen=<rawValue>` (e.g. `--onboardinglab --screen=signIn`).
- **Production auth:** `PushApp` → `RootView` (not `ContentView` directly); live unauthenticated users see `AuthGateView`, which routes welcome ⇄ sign-in via `AuthViewModel.screen` (`AuthWelcomeView` / `AuthSignInView`) using promoted onboarding components (`OnboardingAuthComponents`, `OnboardingHeader`, `OnboardingCTAButton`); email/password sign-in is live-wired; sign-up/social buttons surface "coming soon" via `requestUnavailable()`. Fresh sign-in and restored session enter `.preparing` until snapshot warm completes (Retry/Sign Out on failure). `AuthFormModel` is the shared form-binding seam for production vs lab view models.
- **Friend Groups:** `GroupContentBuilder` (`Push/Data/Derived/`) derives `PushGroupData` cards and `PushGroupMemberData` rows (availability, venue/status text, activity symbol, relative last-updated) from memberships + `PresenceStatus` + `Place` — never stored in seed; canonical presence wins over legacy group-table values. Group cards in `FriendsView` Groups mode use the same derived data.
- **Pushes tab cards:** `PlansContentBuilder` (`Push/Data/Derived/`) derives `PlanData`, hangout calendar, and most-active-group from `PushPlan`/`PushResponse`/`PastHangout`; timing via `PushTimingFormatter`. Card status pills reflect the viewer's `PushResponse`, not `PushPlan.state`. Also derives `participants`, `maybeParticipants`, creator `note`, place `address`, and `distanceLabel` (great-circle miles from self presence place — not real GPS). `PushPlan.groupID` and `placeID` are optional — nil for invitees-only pushes (no group) or Start Push free-text location (`locationText` → `locationHint` when `placeID` is nil).
- **Profile:** `ProfileContentBuilder` derives `ProfileData` from `UserProfile`, `Person`, and self-scoped `VisiblePresence`; toggle/connectors copy from `ProfileScaffolding` (mock seed and live `ProfileRow` share this source). `ProfileViewModel` write-through: availability → `FriendRepository.setCurrentUserAvailability`; basics → `ProfileRepository.updateBasics`; privacy toggles → `updatePrivacy` (id→enabled maps only — copy stays client-side); photo → `ProfileRepository.updateProfilePhoto`/`removeProfilePhoto` after `ProfilePhotoProcessor` resize/compress (PhotosPicker in view). Place line uses vague label (`Near …`), not exact venue.
- **Current user on map:** Inside exact/group pucks when `isCurrentUser: true`; otherwise `SelfPuckView` at close zoom. No standalone `UserLocationPin` on the live map.
- **Map attribution:** Set `MKMapView.layoutMargins` via `StyledMapView.mapLayoutMargins` (`MapAttributionLayout` in `ContentView`) for Apple logo and legal text only (`showsCompass = false`; no manual compass — hero bell is in `ContentView`). Keep bottom insets low so attribution sits discreetly at the screen edge, not above the floating nav. Update insets when top/bottom UI changes.
- **Pushes tab:** Cream Friends-page treatment (`FriendsBackground`, `FriendsLayout` header spacing), not `PushModalBackground`. `PlansView` splits owned vs invited pushes — `PlanData.isOwner`; `PlansViewModel.yourPushes` / `activePushes`. Weekly recap card (`PlansCalendarView` + `PlansWeeklyRecapDayTile`) shows a Monday-first week with `moveWeek` navigation; day taps open detail only when `pushCount > 0` or `almostHappened`. Calendar and push cards use `plansGlassCard` / `PlansColor` with walnut borders matching Friends cards; Start Push CTA uses `pushGlassBackground` with walnut rim. Owned preview uses `YourPushCard` ("Manage →" opens `StartPushFlowView(context: .edit(plan:))` via `managedPlan`); `YourPushesListView` uses the same edit cover locally; invited tab preview uses `ActivePlanCard`; full swipe deck in `ReviewPushesView` uses `ReviewPushCard` with `reviewGlassCard` / `ReviewGlassStyle`.
- **Start Push flow:** `StartPushFlowView(context:)` accepts optional `StartPushLaunchContext` to pre-fill recipient tokens, location hint, and starting step (friend/group/map puck → skip to details when recipients are known). Present via dedicated `fullScreenCover` after dismissing friend/group sheets (`ContentView`, `FriendsView`, `GroupsView`); blank context from map create menu (`MainMapRoute.startPush` / `.startPlan`) or Pushes tab. Edit owned pushes via `.edit(plan:)` (immediate `PlanData` prefill) or `.edit(planID:)` (repo load); edit starts at recipients, submit title is "Save changes", and `goBack` from confirmation resets `hasSubmitted`. `StartPushViewModel` loads groups/friends from `AppDataContainer` repos with `LoadState`; Step 4 suggestion buckets (`likelyFreeNow`, `mightBeInterested`) derive from canonical `PresenceStatus` availability (`.freeNow`/`.joinable` vs `.maybeDown`/`.freeSoon`) — never hardcode recipient IDs. `submit()` runs on step 3→4 (`StartPushFlowView.submitAndAdvance`), before confirmation; idempotent via `hasSubmitted` claimed before `await` (not after repo write returns). Submit via `PushRepository.createPush(_:)` or `updatePush(planID:with:)` when `editPlanID` is set, using `PushDraft` (`recipientIDs` are flow tokens `"group_<id>"` / `"friend_<id>"`); single selected group → `audience: .group` + `groupID`, otherwise `.inviteesOnly`; creator gets `.in`, deduped invitees `.pending` (creator excluded). Edit recipient prefill prefers visible `.in` people over the stored group token.
- **Feature files:** Flat under `Push/` — split by suffix: `*Models`, `*View`, `*ViewModel`, `*Style`. App data flows through repos + derived builders, not `*MockData` files. Multi-step flows add `*FlowView` (container), `*StepNView`, and shared `*Style`; register on `MainMapRoute`.
- **Xcode registration:** Register every new Swift file in `Push.xcodeproj` via `python3 scripts/pbxproj_add.py <path>` (paths relative to `Push/`; `--target tests` for `PushTests/`). Idempotent — safe to re-run.
- **Repo hygiene:** Do not commit `DerivedData/`, `build/`, `*.xcresult`, or local IDE state — covered by `.gitignore`.
- **Tests:** Prefer `scripts/test.sh` (separate `DerivedData-Tests/`). Destination defaults to the worktree visual sim via `run-ios-sim.sh ensure-booted-udid` (`Push - main - iPhone 17` on primary checkout — **not** stock unlabeled `iPhone 17`, which opens a second flaky Simulator). Override with `PUSH_TEST_DESTINATION`. Scoped by area — do **not** run the full suite after every file edit. Seed/domain: `scripts/test.sh suite DataLayerTests`. Live/mock isolation: `LiveContainerIsolationTests`. Auth bootstrap: `AuthBootstrapTests`. Live snapshot: `LiveDataStoreTests`. Map pucks: `MapRenderTests`. Layout: `AdaptiveLayoutTests`. Supabase mapping: `SupabaseMappingTests`. Live push repo: `SupabasePushRepositoryTests`. Alerts: `AlertsTests`. Add Friends: `AddFriendsTests`. Profile photos: `ProfilePhotoTests`. Build-only: `scripts/test.sh build`. Before commit/PR or cross-cutting changes: `scripts/test.sh full` (serial; parallel testing intermittently drops the simulator runner). Do not run `PushUITests` unless asked. SourceKit may false-positive on `Supabase` imports — trust `xcodebuild` / `scripts/test.sh` (see `tasks/lessons.md`).
- **iOS Simulator:** `scripts/run-ios-sim.sh [run|stop|restart|status|list|prune|reload-if-booted|ensure-booted-udid] [--iphone-17|--iphone-17-pro-max|--all] [-- app args…]`. Primary checkout always uses label `main` → visual sim `Push - main - iPhone 17` (stable across feature branches). Orca worktrees under `…/orca/workspaces/Push/<name>` use that name. Default `run` reloads booted worktree sims or creates iPhone 17; stop-hook uses `reload-if-booted` (no create). `ensure-booted-udid` create/boots the preferred worktree sim and prints its UDID (used by `scripts/test.sh`). `list` / `prune` manage Push-prefixed devices. Pass DEBUG launch args after `--` (e.g. `scripts/run-ios-sim.sh -- --friends`).
- **Stop hook:** `.claude/settings.local.json` Stop → `scripts/stop-hook-run.sh`. Modes in `.claude/run-mode`: `live` (default), `mock`, `off`. Locks + 45s debounce; skips when no Swift/project changes; only reloads if `Push - main - iPhone 17` is already Booted.
- **Files ≤ 400 lines.** Split by responsibility.
- **Functions ≤ 40 lines, single responsibility.**
- **No magic numbers.** Named constants only.
- **Comments explain WHY, not WHAT.**
- **Spec before code** for non-trivial features. Write `tasks/spec.md` first.
- **Commit frequently.** At least after each logical component.

### Task Files

| File | Purpose |
|---|---|
| `tasks/todo.md` | Current plan and progress tracking |
| `tasks/spec.md` | Active feature spec (write before implementation) |
| `docs/data-architecture.md` | Seed workflow, derivation rules, test suites, Supabase migration seam |
| `docs/superpowers/specs/*.md` | Dated design specs per feature; read the relevant file before implementing |
| `docs/superpowers/plans/*.md` | Step-by-step implementation plans for multi-task rollouts; follow task-by-task |
| `tasks/lessons.md` | Project-specific learnings and gotchas |

### Session Resume Protocol

Read: `CLAUDE.md` → `tasks/lessons.md` → `tasks/todo.md` → `git log --oneline -5`. Supabase/backend work: also read `supabase/README.md`, `tasks/spec.md` (Issue #27), and repo Supabase skills.

Do not ask the user to re-explain context that is in these files.

---

## Status Language

Status copy should feel **natural, casual, and socially safe.** When confidence is high, be specific. When confidence is lower, soften the wording. Never make it feel like surveillance.

User-facing coordination copy uses **Push/Pushes** (not Plan/Plans). Internal types and files may still use `Plan*`/`Plans*` prefixes until refactored.
