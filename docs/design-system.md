# Push Design System — Agent Catalog

**Status:** Waves 0–3 complete (scaffold, buttons, cream lists, empty/loading/error).  
**Decisions:** `tasks/design-system-decision-log.md` (DS-001–DS-089) — product law.  
**Spec:** `docs/superpowers/specs/2026-07-21-push-design-system-specification.md`.  
**Code home:** `Push/DesignSystem/` (+ temporary typealiases at legacy call sites).  
**Handoff:** `tasks/design-system-handoff.md`.

Open this file **before** creating UI chrome. Discover → reuse → extend → only then propose a new family (DS-086).

---

## Principles

1. **Preserve approved appearance** — extraction and renames, not restyles.
2. **Named surfaces only** — no freeform tint/stroke/shadow knobs in feature code (DS-016).
3. **Semantic components** — person row, group row, request card stay separate (DS-023).
4. **Onboarding/auth is domain-local** until a future alignment pass (DS-006).

---

## Hard bans (DS-088)

- No new glass / material / cream recipes in feature files
- No `.borderedProminent` as product chrome (use branded CTAs — DS-002 / DS-003)
- No second person-row, circular utility button, or full empty/error implementation
- No raw color hex/RGB in feature views once tokens land (prefer `PushControlColors` / palette roles)
- No third primary CTA treatment
- No DIY live-map pucks
- No custom popover/action panels (use system `Menu` / `contextMenu` / `confirmationDialog`)
- No secondary tab bars on ivory screens

---

## Named surfaces (select first)

| Surface | Use when | Status |
|---|---|---|
| Generic control glass | Circular buttons, bottom nav, create menu, toasts, map empty overlay, lightweight floating chrome | API still `pushGlassBackground` (Wave 4 rename) |
| Map glass family | Map top controls, filter pills, profile control, map popup sheets | Feature-local today (Wave 4) |
| Puck glass | Map annotations only | Feature-local (Wave 4) |
| Plans card glass | Push cards & calendar shell on cream pages | `plansGlassCard` (Wave 4/7) |
| Review deck glass | Review swipe deck over gradient | `reviewGlassCard` (Wave 4/7) |
| Ivory page | Persistent destinations (Friends, Plans, Alerts, …) | `PushIvoryPageBackground` (`FriendsBackground` shim) |
| Solid cream card | Dense list cards on ivory | `pushSolidCreamCard` (`friendsCard` shim) |
| Modal gradient | Focused full-screen flows (Start Push, Profile, Review, …) | `PushModalBackground` |
| Onboarding/auth | Auth domain only | `OnboardingLab*` / auth components |

**Background rule (DS-015):** Ivory = browse/persist; modal gradient = enter → complete → exit.

---

## Components — Buttons (Wave 1)

| Component | When to use | Do not recreate |
|---|---|---|
| **`PushCircleIconButton`** (DS-001) | Same-size generic circular utility: close, header +, search clear-adjacent headers, trash icon circle | Custom 44pt glass circle for nav/utility |
| **`PushSolidSunbeamButton`** (DS-002) | Multi-step flow primary (Start Push, Add Group); empty/error recovery CTAs (DS-003) | Local solid sunbeam capsule; `.borderedProminent` product chrome |
| **`PushGlassRimButton`** (DS-002) | Strong primary without solid fill (Plans “Start Push”) | Local glass + walnut-rim capsule primary |
| **`PushCreateMenuIconCircle`** (DS-007) | Sunbeam-filled icon circle inside action-menu rows only | Reusing as generic circular button |
| **`AlertActionButton` + `AlertAddedBadge`** (DS-004) | Request accept/deny lifecycle | Parallel accept/deny capsules |
| Bottom nav center **+** (DS-005) | Map bottom nav only | Folding into `PushCircleIconButton` |
| Onboarding/auth primary (DS-006) | Auth domain only | Using inside main app |

### Typealiases (migration shims)

- `FriendsCircleButton` → `PushCircleIconButton`
- `PushModalIconButton` → wrapper over `PushCircleIconButton`
- `StartPushPrimaryButton` → `PushSolidSunbeamButton`

### Out of scope for circle family

Map profile control, bottom-nav raised +, product circles with intentionally different size/role, text+chevron “Back” capsules (not pure icon circles).

---

## Components — Cream lists & people (Wave 2)

| Component | When to use | Do not recreate |
|---|---|---|
| **`PushIvoryPageBackground`** (DS-014/015) | Persistent ivory destinations | Local cream page fills |
| **`pushSolidCreamCard`** (DS-014/017) | Dense list rows/banners on ivory | Local cream fill + walnut stroke recipes |
| **`PushPersonRow`** (DS-018/027) | Default flat person lists | Parallel person cards; `BlockedPersonRow` forks |
| **`PushExpandablePersonRow` + rail** (DS-028/008) | Multi-action expand under person row | Baking expand into base person row |
| **`PushGroupRow`** (DS-019) | Group list identity cards | Forcing groups into person-row |
| **`PushHistoryRow`** (DS-021) | Plans history list | DIY cream history chrome |
| **`PushListSectionHeader`** (DS-034) | Alerts/Friends section titles + counts | One-off section header chrome |
| **`ActionErrorBanner`** (DS-022) | Inline mutation recovery on cream foundation | Full-page `.failed` for mutation errors |
| Request cards (DS-020) | Friend request via person-row + Accept/Deny; group via `GroupRequestCard` | New request chrome families |

### Typealiases (Wave 2 shims)

- `FriendsBackground` → `PushIvoryPageBackground`
- `friendsCard` → `pushSolidCreamCard`
- `FriendRowCard` → `PushPersonRow`
- `FriendGroupCard` → `PushGroupRow`
- `FriendsSectionHeader` → `PushListSectionHeader`
- `HistoryListRow` → `PushHistoryRow`
- `ExpandableFriendRow` → Friends convenience over `PushExpandablePersonRow`

### Later waves

### Empty / loading / error (Wave 3)

| Pattern | Component | When to use |
|---|---|---|
| Phase model (DS-070) | `SurfaceContentPhase` | All primary surfaces |
| Full-page empty (DS-071) | `EmptySurfaceView` | Ivory/modal empty; optional message/CTA |
| Full-page loading/failed (DS-071) | `EmptySurfaceStateView` | Hard load spinner / retry |
| Friends/groups empty | `FriendsEmptyState` | Convenience over EmptySurface |
| Map empty/failed (DS-072) | `MapEmptyOverlay` | Control-glass card on map only |
| Mutation error (DS-073) | `ActionErrorBanner` | Keep content visible; Retry + dismiss |
| Deferred (DS-074) | EmptySurface + `.deferred` | Honest empty, no fake rows (Feed) |
| Inline no-results (DS-075) | EmptySurface / `FriendsEmptyState(isSearching:)` | Stays `.content` phase |
| Local busy (DS-075) | Control spinner / disabled | Never full-list spinner for one action |

#### Error routing (DS-073) — pick the channel by failure type

| Failure | Channel | Keep last content? |
|---|---|---|
| Initial / hard load fail | Full-page `EmptySurfaceStateView.failed` (or `MapEmptyOverlay` on map) | No (nothing loaded) |
| Recoverable mutation fail | `ActionErrorBanner` | **Yes** |
| Soft reload / pull-to-refresh | Stay on content; optional local refresh chrome | **Yes** |
| Silent session refresh (foreground) | Silent | **Yes** |

**Do not** use full-screen failed as the only channel for mutation errors.

### Avatars, chips, pucks (Wave 5)

| Pattern | DS |
|---|---|
| Availability tokens + compact chip | DS-043–044 |
| Brand sunbeam pill | DS-045 |
| Person avatar + rings | DS-050–051 |
| Map puck family | DS-052 — do not DIY |
| Avatar stack / strip | DS-053 |

### Navigation & sheets (Wave 6)

| Pattern | DS |
|---|---|
| Bottom nav (map shell) | DS-057 |
| Map top chrome | DS-058 |
| Cream page header | DS-060 |
| Modal flow chrome | DS-061 |
| Map bottom-sheet chrome | DS-064 |
| System Menu / confirmationDialog | DS-066 |

### Plan cards (Wave 7)

| Pattern | DS |
|---|---|
| Plans-glass plan card (owner / invited) | DS-024 |
| Review deck card (separate) | DS-025 |
| Weekly calendar module (frozen whole) | DS-026 |

---

## Tokens (Wave 8 target)

Until token modules land, use existing shared sources:

| Domain | Today | Target |
|---|---|---|
| Brand accents | `PushColorPalette` | `PushColorTokens` |
| Text hierarchy | `PushControlColors` | same roles |
| Availability | `PuckColorTokens` / state extensions | `PushAvailabilityTokens` |
| Layout metrics | `PushAdaptiveLayout` | keep + spacing tokens |
| Glass chrome | `PushGlassStyle` / `pushGlassBackground` | named surfaces |

**Never black text or black shadows.** Walnut/espresso hierarchy only.

---

## Discovery checklist (DS-086)

1. Open this catalog (+ decision log if changing a family).
2. Choose **surface** from the table above.
3. Choose **component** (or planned pattern still in feature code).
4. Prefer **variant/slot** over a new type.
5. If nothing fits → propose a design-system decision; do not ship a near-duplicate.

---

## Wave tracking

| Wave | Focus | Status |
|---|---|---|
| 0 | Scaffold + this catalog + AGENTS links | Done |
| 1 | Buttons & primary CTAs | Done |
| 2 | Cream lists & person system | Done |
| 3 | Empty / loading / error | Done |
| 4 | Named surfaces + cream tokens | Pending |
| 5 | Availability, chips, avatars, pucks | Pending |
| 6 | Selectors, headers, sheets | Pending |
| 7 | Plan cards & subcomponents | Pending |
| 8 | Tokens & motion | Pending |
| 9 | Docs polish | Pending |

Update `tasks/design-system-handoff.md` when a wave finishes.
