# Push Design System — Agent Catalog

**Status:** Waves 0–8 complete (through tokens & motion).  
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

Feature code **must** pick a named API — no local glass/cream/gradient recipes (DS-016).

| Surface | Named API | Use when |
|---|---|---|
| Generic control glass | `pushControlGlass` (`pushGlassBackground` shim) | Circular buttons, bottom nav, create menu, toasts, map empty overlay |
| Map control glass | `pushMapControlGlass(treatment:)` | Map top profile / filter pill / dropdown panel |
| Map sheet glass | `MapPopupSheetBackground` | Friend detail / day-detail map popups |
| Puck glass | `pushPuckGlass` (`puckGlassBackground` shim) | Map annotations only |
| Plans card glass | `pushPlansCardGlass` (`plansGlassCard` shim) | Push cards & calendar on cream pages |
| Review deck glass | `pushReviewDeckGlass` (`reviewGlassCard` shim) | Review swipe deck over gradient only |
| Ivory page | `PushIvoryPageBackground` | Persistent destinations |
| Solid cream card | `pushSolidCreamCard` | Dense list rows/banners on ivory |
| Modal gradient | `PushModalBackground` | Focused full-screen flows |
| Onboarding/auth | domain glass only | Auth domain (temporary — DS-016) |

**Tokens:** solid cream → `PushCreamTokens`; Plans/Review glass cream → `PushGlassCreamTokens` (do not flatten Plans glass into solid cream).

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

### Availability, chips, avatars, pucks (Wave 5)

| Pattern | Named API | When to use |
|---|---|---|
| Availability colors (DS-043) | `PushAvailabilityTokens` + `FriendAvailabilityState.accentColor` / `chipFillColor` / `chipTextColor` | All rings, chips, badges, live dots |
| Availability chip (DS-044) | `PushAvailabilityChip` (`.compact` / `.sheet`) | Cream lists + friend-detail headers |
| Map activity badge (DS-044) | `ActivityBadge` | Map pucks only — not list trailing chips |
| Brand sunbeam pill (DS-045) | `PushBrandSunbeamPill` / `StatusPill` / `YourPushTimeChip` / `PushGroupStatusPill` | Non-availability labels |
| Plan status pill (DS-046) | `PlanStatusPill` | Plan/RSVP state on plan cards only |
| Live dot + time (DS-047) | Person-row trailing accessory | Uses availability accent |
| Person avatar (DS-050) | `PushPersonAvatar` (fallback `.dark` / `.sunbeam`) | All person faces; shims: `ProfilePhotoAvatar`, `RecipientAvatarView` |
| Map puck family (DS-052) | `FriendPuck`, `FriendClusterPuck` / group pucks, `RegionalActivityPuck`, `SelfPuckView` | **No DIY map pucks** |
| Avatar stack / strip (DS-053) | `AvatarStack` / plan-card strips / `PushHistoryAvatarStack` | Offset stack vs linear strip |

### Selectors, navigation & sheets (Wave 6)

| Pattern | Named API | When to use |
|---|---|---|
| Ivory segmented switch (DS-035) | `PushIvorySegmentedControl` | Cream multi-mode (Friends\|Groups) |
| Ivory filter chips (DS-036) | `PushIvoryFilterChipRow` | Walnut-selected filters on ivory (not sunbeam) |
| Single-select row (DS-037) | `PushSingleSelectRow` | Sunbeam+check row; map dropdown consumes it |
| Modal choice pill (DS-039) | `PushModalChoicePill` | AM/PM and compact modal choices |
| Date/time pickers (DS-039) | `PushDatePicker` / `PushTimeClicker` | Modal timing fields |
| Settings checkmark rows (DS-040) | `ProfileToggleRow` | Modal settings binaries only |
| Cream page header (DS-060) | `PushCreamPageHeader` | Ivory title + trailing circular actions |
| Modal flow chrome (DS-061) | `PushModalCloseButtonBar` | FullScreenCover close row |
| Map bottom sheet (DS-064) | `PushMapBottomSheetChrome` / drag indicator | Custom map sheets (not system `.sheet`) |
| Text link (DS-062) | `Text.pushTextLinkStyle()` | Secondary text actions on cream |
| Bottom nav (DS-057) | `BottomNavigationBar` | Map shell only |
| System menus (DS-066) | `Menu` / `confirmationDialog` | Overflow and destructive confirms |

### Plan cards (Wave 7)

| Pattern | Named API | Notes |
|---|---|---|
| Plans-glass family (DS-024) | `PushPlansPlanCard` (`.owner` / `.invited`) | Shims: `YourPushCard`, `ActivePlanCard` |
| Review deck card (DS-025) | `PushReviewPlanCard` | Separate glass family; shim `ReviewPushCard` |
| Plan status pill (DS-046) | `PushPlanStatusPill` | Shared by Plans + Review |
| Avatar strip (DS-053) | `PushPlanAvatarStrip` | Horizontal faces + overflow |
| Weekly calendar (DS-026) | `PlansCalendarView` module | **Leave whole** — no redesign |

---

## Tokens (Wave 8)

| Domain | Module / API | Rules |
|---|---|---|
| Brand accents | `PushColorPalette` | Semantic only in features |
| Text hierarchy | `PushControlColors` | No black text |
| Availability | `PushAvailabilityTokens` | Single color path |
| Cream | `PushCreamTokens` / `PushGlassCreamTokens` | Don't flatten glass into solid cream |
| Motion | **`PushMotion`** | selection, expand, sheet, press, mapPulse — no new spring literals |
| Opacity / min scale | **`PushOpacityTokens`** | disabled, inactive, scrim, minimumTextScale |
| Radii | **`PushRadiusTokens`** + `layout.cardCornerRadius` | Continuous corners; role-based |
| Typography helpers | **`PushTypographyTokens`** / `pushSectionLabelStyle()` | SF semantic first; rounded for initials only |
| Spacing | `PushAdaptiveLayout` | Cross-screen padding/spacing |

**Never black text or black shadows.** New shared values → token or DS decision (DS-083).

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
| 4 | Named surfaces + cream tokens | Done |
| 5 | Availability, chips, avatars, pucks | Done |
| 6 | Selectors, headers, sheets | Done |
| 7 | Plan cards & subcomponents | Done |
| 8 | Tokens & motion | Done |
| 9 | Docs polish | Pending |

Update `tasks/design-system-handoff.md` when a wave finishes.
