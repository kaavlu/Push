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
- **Data:** Local in-memory store + async throwing repository protocols (mock backend seam for Supabase later; no networking yet). Layout: `Push/Data/` — Domain, Seed, Store, Repositories, Derived, `AppDataContainer`. Guides: `docs/data-architecture.md` (seed workflow, derivations, tests), `docs/superpowers/specs/2026-07-05-data-architecture-design.md`.
- **Maps:** MapKit — live map base layer is satellite imagery (`MKImageryMapConfiguration`), not muted standard

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

- Backend or authentication
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

**Glass + accents:** Brand colors live in `Push/PushColorPalette.swift` — walnut for foreground/text, sunbeam for active fills. Use `PushControlColors` text hierarchy (`textEspresso`, `textPrimary`, `textSecondary`, `textTertiary`); do not use black or system primary. Reuse `PushGlassStyle`, `PushControlColors`, and `PushControlStyle` for all glass controls; do not one-off material values. Prefer native `glassEffect` on iOS 26+; iOS 17 uses the shared material fallback in `pushGlassBackground`.

**Design reference (`Design/`):** Handoff bundle for visual work — `PushDesignBrief.md`, `PushThemeAudit.md`, verbatim snapshots in `CoreDesignFiles/`, copied imagery in `Assets/`. Read-only references; implement changes in `Push/`, not in `Design/`.

---

## Coding Standards

See `coding-standards.md` for the full reference. Key rules for this project:

- **MVVM strictly.** ViewModels own state and logic; Views are dumb.
- **Mock everything.** No real network calls, no real location. All data is injected via mock services.
- **Mock images:** Store under `assets/friends/`, `assets/groups/`, `assets/profile/`; reference as path strings (e.g. `"assets/friends/chitty.png"`) and load via `PushImageAssets.image(named:)`.
- **Seed data:** Single canonical source in `Push/Data/Seed/SeedData` (scattered `*MockData` / `RealWorldMockData` deleted — do not recreate for app screens). Opaque `String` IDs (seed may use readable slugs; never couple identity to display names). Group membership via `GroupMembership` rows, not stored `memberIDs`. Stats, social proof, timing labels, calendar rows, and map pucks are **derived** — never stored in seed. PuckLab keeps isolated design fixtures (`PuckLabFixtures`), not app data.
- **Repositories:** All protocols are `async throws` (local impls never throw); ViewModels take repos via init (default from shared `AppDataContainer`) and expose primary content via `LoadState<Value>`. Derived builders produce presentation structs from canonical domain data — presence builders use **`VisiblePresence`** (sharing-policy–filtered), never raw `PresenceStatus`. Views must not read mock enums or seed directly.
- **Live map:** `MapViewModel` owns puck `LoadState`, group filters (`GroupFilterItem`), `filteredPucks`, `selfPuck`, and `renderPucks(for:)`; `ContentView` tracks `mapSpan` and is render-only. Two-stage derivation: `MapContentBuilder` → exact-place `MapPuckData`; `MapDisplayPuckBuilder` → zoom-aware `MapPuckRenderModel` (`.friend`, `.smallGroup`, `.selfPuck`, `.regionalCluster`). Close zoom (`latitudeDelta` ≤ 0.22) shows exact pucks; wider zoom clusters into `RegionalActivityPuck`. Vague-presence people use `Place.vagueCoordinate` for regional sources only. Regional cluster tap sets `MapFocusRequest` to zoom in (no detail sheet). `MapPuckKind` drives `FriendDetailSheet` layout; multi-person pucks use `.joinable` availability. Filter by `groupIDs`; `FriendPuckData.id` is `String`.
- **Friends screen:** `MainMapRoute.groups` presents `FriendsView` (bottom nav "Friends"; route id still `groups`). Friends mode: `FriendsViewModel` + `FriendsContentBuilder` — one row per direct friend via `VisiblePresence`; no visible presence → "Hidden right now" row (never dropped). Reuses `FriendPuckData` / `FriendDetailSheet`. Groups mode reuses `GroupsViewModel` + `GroupDetailView`. Cream page styling (`FriendsColor`, `friendsCard`), not map glass. DEBUG launch: `--friends`.
- **Friend Groups:** `GroupContentBuilder` (`Push/Data/Derived/`) derives `PushGroupData` cards and `PushGroupMemberData` rows from memberships + `PresenceStatus` (counts, badges, member availability) — never stored in seed; canonical presence wins over legacy group-table values. Group cards in `FriendsView` Groups mode use the same derived data.
- **Pushes tab cards:** `PlansContentBuilder` (`Push/Data/Derived/`) derives `PlanData`, hangout calendar, and most-active-group from `PushPlan`/`PushResponse`/`PastHangout`; timing via `PushTimingFormatter`. Card status pills reflect the viewer's `PushResponse`, not `PushPlan.state`. Also derives `participants`, `maybeParticipants`, creator `note`, place `address`, and `distanceLabel` (great-circle miles from self presence place — not real GPS).
- **Profile:** `ProfileContentBuilder` (`Push/Data/Derived/`) derives `ProfileData` from `UserProfile`, `Person`, and self-scoped `VisiblePresence`; toggles/connectors load from canonical `UserProfile`. Place line uses vague label (`Near …`), not exact venue.
- **Current user on map:** Inside exact/group pucks when `isCurrentUser: true`; otherwise `SelfPuckView` at close zoom. No standalone `UserLocationPin` on the live map.
- **Map attribution:** Set `MKMapView.layoutMargins` via `StyledMapView.mapLayoutMargins` (`MapAttributionLayout` in `ContentView`) for Apple logo and legal text only; compass is a manually placed `MKCompassButton` in `StyledMapView` (`CompassLayout`). Update insets when top/bottom UI changes.
- **Pushes tab:** `PlansView` splits owned vs invited pushes — `PlanData.isOwner`; `PlansViewModel.yourPushes` / `activePushes`. Weekly recap card (`PlansCalendarView` + `PlansWeeklyRecapDayTile`) shows a Monday-first week with `moveWeek` navigation; day taps open detail only when `pushCount > 0` or `almostHappened`. Use `plansGlassCard` / `PlansColor` for Pushes tab glass cards. Owned preview uses `YourPushCard` ("Manage →" opens `ManagePushView` via `isManagePushPresented` / `managedPlan`); invited tab preview uses `ActivePlanCard`; full swipe deck in `ReviewPushesView` uses `ReviewPushCard` with `reviewGlassCard` / `ReviewGlassStyle`.
- **Start Push flow:** `StartPushViewModel` loads groups/friends from `AppDataContainer` repos with `LoadState`; Step 4 suggestion buckets (`likelyFreeNow`, `mightBeInterested`) derive from canonical `PresenceStatus` availability (`.freeNow`/`.joinable` vs `.maybeDown`/`.freeSoon`) — never hardcode recipient IDs.
- **Feature files:** Flat under `Push/` — split by suffix: `*Models`, `*View`, `*ViewModel`, `*Style`. App data flows through repos + derived builders, not `*MockData` files. Multi-step flows add `*FlowView` (container), `*StepNView`, and shared `*Style`; register on `MainMapRoute`.
- **Xcode registration:** Register every new Swift file in `Push.xcodeproj` via `python3 scripts/pbxproj_add.py <path>` (paths relative to `Push/`; `--target tests` for `PushTests/`). Idempotent — safe to re-run.
- **Tests:** After seed changes, run `DataLayerTests` (referential integrity). Map puck display: `MapRenderTests`. Full suite: `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO` — parallel testing intermittently drops the simulator runner in this environment.
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

Read: `CLAUDE.md` → `tasks/lessons.md` → `tasks/todo.md` → `git log --oneline -5`

Do not ask the user to re-explain context that is in these files.

---

## Status Language

Status copy should feel **natural, casual, and socially safe.** When confidence is high, be specific. When confidence is lower, soften the wording. Never make it feel like surveillance.

User-facing coordination copy uses **Push/Pushes** (not Plan/Plans). Internal types and files may still use `Plan*`/`Plans*` prefixes until refactored.
