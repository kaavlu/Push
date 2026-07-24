# Push Design System

**Status: operational (Waves 0–9).**

**Agent entry point.** Canonical catalog: [`docs/design-system.md`](../../docs/design-system.md).  
Decisions: [`tasks/design-system-decision-log.md`](../../tasks/design-system-decision-log.md) (DS-001–DS-090).  
Spec: [`docs/superpowers/specs/2026-07-21-push-design-system-specification.md`](../../docs/superpowers/specs/2026-07-21-push-design-system-specification.md).  
Handoff (history): [`tasks/design-system-handoff.md`](../../tasks/design-system-handoff.md).  
Pre-system visual extraction (read-only): [`Design/PushThemeAudit.md`](../../Design/PushThemeAudit.md) — **catalog + decisions override** on conflict.

## Rules (short)

1. Open `docs/design-system.md` before adding UI chrome.
2. Choose a **named surface**, then a **catalog component**.
3. Prefer variant/slot over a new type.
4. No local glass/cream recipes, no third primary CTA, no DIY pucks.
5. Use `PushMotion` / opacity / radius / availability tokens — no ad-hoc shared magic numbers.
6. Preserve approved appearance — extract/rename, do not redesign.

## Layout

```
DesignSystem/
  README.md
  Tokens/          # availability, motion, opacity, radius, typography
  Surfaces/        # control / map / puck / plans / review glass, cream, modal
  Components/
    Buttons/
    Rows/
    Cards/
    Chips/
    Avatars/
    Navigation/
    Sheets/
    EmptyStates/
    Selectors/
    Dialogs/       # confirmation (DS-090)
```

## Wave status

| Wave | Focus | Status |
|---|---|---|
| 0–8 | Scaffold → tokens | Done |
| 9 | Docs polish | Done |

Full component inventory and **do-not-recreate** tables live in `docs/design-system.md`.

## Quick “use this, not that”

| Need | Use |
|---|---|
| Glass button / floating chrome | `pushControlGlass` / `PushCircleIconButton` |
| Primary CTA | `PushSolidSunbeamButton` or `PushGlassRimButton` |
| Ivory page / list card | `PushIvoryPageBackground` / `pushSolidCreamCard` |
| Person list | `PushPersonRow` (+ optional expand) |
| Empty / load fail | `EmptySurfaceView` / `EmptySurfaceStateView` |
| Mutation error | `ActionErrorBanner` |
| Destructive confirmation | `.pushConfirmation` / `PushConfirmationDialog` |
| Map empty | `MapEmptyOverlay` |
| Availability color / chip | `PushAvailabilityTokens` / `PushAvailabilityChip` |
| Person face | `PushPersonAvatar` |
| Plan preview card | `PushPlansPlanCard` (or shims) |
| Review swipe card | `PushReviewPlanCard` |
| Motion | `PushMotion.selection` / `.expand` / `.sheet` / … |

Temporary typealiases (`FriendsCircleButton`, `FriendRowCard`, `StartPushPrimaryButton`, …) keep legacy call sites compiling during renames.
