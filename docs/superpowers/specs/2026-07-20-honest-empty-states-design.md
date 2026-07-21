# Honest Empty States Across Live Surfaces (Issue #49)

## Goal

Replace blank, misleading, or prototype-looking live surfaces with intentional empty states that explain why no content is available and, where appropriate, direct users toward a useful next action.

This does **not** implement presence, Feed, or History backends. It makes the current Release experience honest and usable until those systems exist. Mock mode continues to show seeded data.

## Product decisions

| Decision | Choice |
|---|---|
| Map empty primary action | **Add friends only** |
| Feed deferred state | **Copy only** — no CTA |
| Calendar / History empty | Keep week strip; honest empty footer; **hide** dead `History ›` when there is nothing to open |
| Offline vs failed | No separate offline detector in this issue — network/load failures use **Failed + Retry** |

## State model

Each covered surface distinguishes presentation phases derived from existing `LoadState` plus emptiness checks. Do **not** replace or over-extend `LoadState` with empty/offline/deferred cases.

| Phase | Meaning | UI |
|---|---|---|
| **Loading** | First load in flight (or no prior value yet) | Spinner + short label (Alerts-style) |
| **Empty** | Load succeeded; nothing useful to show | Intentional empty copy + optional primary action |
| **Failed** | Repo/load error | Error icon + message + Retry — never empty-copy |
| **Content** | Has data to show | Existing populated UI |
| **Deferred** | Feature intentionally unavailable (Feed only) | Honest “not live yet / no activity” — no CTA |

**Soft reload:** When a surface already has content and refreshes, keep last content visible while refreshing (same pattern as Alerts / Friends pull-to-refresh). Do not flash Empty or Failed over good data during a refresh.

**Mock:** Seeded data still populates. Empty UI only when lists are actually empty (e.g. search no-matches remains as today).

## Surfaces

### Map

**When empty:** load succeeded and there are **no friend pucks** and no regional clusters from friends. Covers both (1) zero friends and (2) friends exist but live presence yields no map pucks. A self-only map still counts as empty of friends for this overlay.

**UI:**
- Non-blocking overlay card (map-safe glass/cream treatment) that does **not** obstruct filter chips, hero bell, create menu, or bottom navigation.
- Copy direction: friends appear when they share status (covers presence gap) / add people to get started (covers no-graph). One shared empty treatment for both cases.
- **Primary action only:** “Add friends” → existing `MainMapRoute.addFriend` / `AddFriendsView` (product decision: no “set status” CTA in this issue).
- Loading: do not show the empty overlay while loading; optional light map-safe indicator if first paint is slow.
- Failed: compact retry control — not the empty “add friends” message.

### Friends

**Zero friends (not searching):**
- Keep current empty tone (`FriendsEmptyState`).
- Add primary **“Add friends”** action → existing full-screen `AddFriendsView`.
- Prefer hiding filter chips when `friendsCount == 0` and not searching so counts do not imply missing data. Keep search + “+”.

**Search no-matches:** unchanged (“No matches”).

**Friends with no visible presence:**
- Keep friend rows usable.
- Continue honest **“Hidden right now”** language (existing `FriendsContentBuilder`).
- Never present missing presence as a network error or drop the row.

**Groups empty:** keep current empty copy; create path remains header “+”.

**Loading / failed:** switch on presentation phase (Friends today does not); match Alerts pattern.

### Feed

Replace `CreatePlaceholderView` stub with a deliberate **deferred** full-screen state.

- Prefer cream Friends-page treatment over glass modal prototype chrome.
- Copy only: communicate that there is no Feed activity yet / Feed is not live — **without** looking like a load failure.
- **No CTA.**
- Dismiss via existing route presentation chrome if needed.

### Pushes tab (cards)

Keep existing Your Pushes / Active Pushes empty cards when load succeeded and lists are empty. Existing Start Push entry points on the tab remain as today.

### Calendar / History

- Keep the weekly recap strip.
- Empty week footer: honest copy (e.g. “No hangouts this week”); **suppress** “Most active…” / “Best day…” when there is no real summary data.
- **`History ›`:** hide when there is no history story to tell (preferred over a no-op button).
- No History sheet and no historical backend in this issue.

## Architecture

### Shared kit (small)

| Piece | Role |
|---|---|
| `EmptySurfaceCopy` | Static titles, messages, action labels — no magic strings in views |
| `SurfaceContentPhase` (name flexible) | Presentation enum: `loading`, `empty`, `failed`, `content`, `deferred` — derived in ViewModels |
| `EmptySurfaceView` | Cream-page centered empty (title, message, optional primary button); `PushControlColors` / Friends cream tokens |
| `MapEmptyOverlay` | Compact non-blocking map card |
| Loading / failed | Reuse Alerts-style visual language rather than a third system |

### ViewModels

| Owner | Responsibility |
|---|---|
| `MapViewModel` | Friend-presence emptiness, map surface phase, empty vs failed vs content |
| `FriendsViewModel` | List phase; empty vs search-empty vs failed; hidden presence remains **content** |
| Feed | Static deferred presentation (thin ViewModel optional for test seam; no Feed repo required for Day-1 empty) |
| `PlansViewModel` | Empty-week footer flags; `showsHistoryLink`; existing push empty flags |

Views stay dumb: render phase + call existing navigation closures. No `import Supabase` outside the data layer. No mock data leaks in live mode.

### Navigation

| Source | Action |
|---|---|
| Map empty | `presentedRoute = .addFriend` (same path as create menu) |
| Friends empty | `isAddFriendPresented = true` |
| Feed | No action; dismiss only if chrome provides it |

### Files likely touched

- New: empty-surface models/views/copy (split if needed to stay ≤400 lines)
- `MapViewModel`, `ContentView` (overlay + Feed destination)
- `FriendsView` / `FriendsComponents` / `FriendsViewModel`
- Feed destination (replace `CreatePlaceholderView` usage for Feed)
- `PlansViewModel`, `PlansCalendarView`
- Focused tests + `pbxproj` registration via `scripts/pbxproj_add.py`

`CreatePlaceholderView` may remain for other routes if still used; Feed must not use it.

## Copy principles

- Natural, casual, socially safe (project status language).
- Empty ≠ failed ≠ loading ≠ deferred — visually and in wording.
- Prefer “not yet” / “when friends share” over “error” / “unavailable.”
- User-facing coordination terms: **Push/Pushes**, not Plan/Plans.

Suggested direction (final strings live in `EmptySurfaceCopy`):

| Surface | Title direction | Message direction | Action |
|---|---|---|---|
| Map empty | Friends will show up here | When they share status — add friends to get started | Add friends |
| Friends empty | No friends yet | Add friends to see who’s around | Add friends |
| Feed deferred | No Feed activity yet | Feed isn’t live yet — check back later | — |
| Calendar empty week | (footer) No hangouts this week | Suppress most-active / best-day | — |
| Failed (generic) | Couldn’t load … | Try again in a moment | Retry |

## Testing

Add focused coverage (unit tests; not `PushUITests` unless requested):

- New account / no graph → map empty phase + add-friends intent; Friends empty + action
- Friends with no visible statuses → content rows, hidden language, not failed
- No pushes → existing empty cards still shown when loaded empty
- Empty history week → no History link; honest footer; no fake “most active”
- Feed deferred → phase/copy, not failed
- Loading vs empty vs failed per Map / Friends
- Mock seed container still yields non-empty map/friends/pushes when seed has data
- Deep link / action: empty Map and Friends open Add Friends flow (ViewModel intent or view wiring testable via flags)

Suggested suite: new `EmptySurfaceTests` and/or extensions to Map / Friends / Plans VM tests. Verify with `scripts/test.sh build` and scoped suites.

## Acceptance criteria

- Brand-new live account with no friends sees clear, intentional empty states.
- User with friends but no presence does not see a blank or broken-looking map (map empty or self-only with empty overlay; Friends list still honest).
- Feed does not look like a failed or prototype stub implementation.
- Empty History does not imply a backend error; dead History control is hidden.
- Empty states that need action open **Add friends** (Map, Friends).
- Loading, empty, failed, and deferred are visually and behaviorally distinct.
- Mock mode continues to show existing populated data.

## Out of scope

- Building the live Feed
- Building presence or map pucks
- Building historical Push / hangout data
- Removing or reorganizing navigation tabs
- Redesigning populated states
- Dedicated offline connectivity detection
- History detail sheet

## Implementation notes

- Spec before code: this document is the contract; follow with an implementation plan under `docs/superpowers/plans/`.
- Register new Swift files with `python3 scripts/pbxproj_add.py`.
- Prefer shared constants over magic numbers; reuse `PushControlColors`, cream Friends styling, and existing glass map chrome where overlays sit on the map.
- Commit after each logical component.
