# Push Design System

**Agent entry point.** Canonical catalog: [`docs/design-system.md`](../../docs/design-system.md).  
Decisions: [`tasks/design-system-decision-log.md`](../../tasks/design-system-decision-log.md) (DS-001–DS-089).  
Spec / waves: [`docs/superpowers/specs/2026-07-21-push-design-system-specification.md`](../../docs/superpowers/specs/2026-07-21-push-design-system-specification.md).  
Handoff: [`tasks/design-system-handoff.md`](../../tasks/design-system-handoff.md).

## Rules (short)

1. Open `docs/design-system.md` before adding UI chrome.
2. Choose a **named surface**, then a **catalog component**.
3. Prefer variant/slot over a new type.
4. No local glass/cream recipes, no third primary CTA, no DIY pucks.
5. Preserve approved appearance — extract/rename, do not redesign.

## Layout

```
DesignSystem/
  README.md                 # This file
  Tokens/                   # Color, type, spacing, motion (Wave 4+)
  Surfaces/                 # Named glass / cream / modal backgrounds (Wave 4+)
  Components/
    Buttons/                # Wave 1 — circle utility, solid sunbeam, glass rim
    Rows/                   # Wave 2+
    Cards/
    Chips/
    Avatars/
    Navigation/
    Sheets/
    EmptyStates/            # Wave 3+
    Selectors/
  Catalog/                  # Optional DEBUG previews
```

## Wave status

| Wave | Focus | Status |
|---|---|---|
| 0 | Scaffold + catalog + AGENTS links | Done |
| 1 | Buttons & primary CTAs | Done |
| 2 | Cream lists & person system | Done |
| 3 | Empty / loading / error | Done |
| 4 | Named surfaces + cream tokens | Done |
| 5 | Availability, chips, avatars, pucks | Done |
| 6–9 | See spec §8.3 | Not started |

## Migrated components

### Wave 1 — Buttons

| Type | File | Replaces |
|---|---|---|
| `PushCircleIconButton` | `Components/Buttons/PushCircleIconButton.swift` | `FriendsCircleButton`, `PushModalIconButton`, inline close/trash circles |
| `PushSolidSunbeamButton` | `Components/Buttons/PushSolidSunbeamButton.swift` | `StartPushPrimaryButton`, recovery CTAs |
| `PushGlassRimButton` | `Components/Buttons/PushGlassRimButton.swift` | Plans `StartPlanButton` |
| `PushCreateMenuIconCircle` | `Components/Buttons/PushCreateMenuIconCircle.swift` | Create-menu sunbeam icon circle |

### Wave 2 — Cream lists & person system

| Type | File | Replaces |
|---|---|---|
| `PushIvoryPageBackground` / `pushSolidCreamCard` | `Surfaces/PushCreamSurfaces.swift` | `FriendsBackground`, `friendsCard` |
| `PushPersonRow` | `Components/Rows/PushPersonRow.swift` | `FriendRowCard`; blocked fork |
| `PushExpandablePersonRow` + rail | `Components/Rows/PushExpandable*.swift` | `ExpandableFriendRow` internals |
| `PushGroupRow` | `Components/Rows/PushGroupRow.swift` | `FriendGroupCard` |
| `PushHistoryRow` | `Components/Rows/PushHistoryRow.swift` | Plans history private row |
| `PushListSectionHeader` | `Components/Rows/PushListSectionHeader.swift` | `FriendsSectionHeader` |

### Wave 3 — Empty / loading / error

| Type | File | Replaces |
|---|---|---|
| `SurfaceContentPhase` / `EmptySurfaceCopy` / layout | `Components/EmptyStates/PushEmptySurfaceModels.swift` | Feature-local empty copy forks |
| `EmptySurfaceView` / `EmptySurfaceStateView` / `FriendsEmptyState` | `Components/EmptyStates/PushEmptySurfaceView.swift` | Blocked/Alerts/AddFriends state views |
| `MapEmptyOverlay` | `Components/EmptyStates/PushMapEmptyOverlay.swift` | Map empty chrome (branded CTAs) |

Error routing: hard load → full-page/map failed; mutations → `ActionErrorBanner`; soft reload keeps content. See `docs/design-system.md`.

### Wave 4 — Named surfaces

| Type | File | Legacy shim |
|---|---|---|
| `pushControlGlass` | `Surfaces/PushControlGlass.swift` | `pushGlassBackground` |
| `pushMapControlGlass` / `MapPopupSheetBackground` | `Surfaces/PushMapGlass.swift` | ContentView `topControlBackground` |
| `pushPuckGlass` | `Surfaces/PushPuckGlass.swift` | `puckGlassBackground` |
| `pushPlansCardGlass` / `pushReviewDeckGlass` | `Surfaces/PushCardGlass.swift` | `plansGlassCard` / `reviewGlassCard` |
| `PushModalBackground` | `Surfaces/PushModalSurface.swift` | — |
| Cream tokens | `PushCreamTokens` + `PushGlassCreamTokens` | `PlansColor` cream aliases |

### Wave 5 — Availability, chips, avatars

| Type | File | Notes |
|---|---|---|
| `PushAvailabilityTokens` | `Tokens/PushAvailabilityTokens.swift` | `PuckColorTokens` typealias |
| `PushAvailabilityChip` | `Components/Chips/PushAvailabilityChip.swift` | compact + sheet density |
| `PushBrandSunbeamPill` | `Components/Chips/PushBrandSunbeamPill.swift` | profile / plan time / group status |
| `PushPersonAvatar` | `Components/Avatars/PushPersonAvatar.swift` | dark + sunbeam fallbacks |
| Map pucks | existing `FriendPuck*` / `SelfPuckView` / `RegionalActivityPuck` | catalog only — no DIY |

Temporary typealiases keep call sites compiling during renames.
