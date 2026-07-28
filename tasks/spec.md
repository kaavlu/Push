# Issue #109 — Surface Inferred Activity Across Push

## Goal

Display the canonical presence activity (`activity_name` / `activity_symbol`) consistently across live friend surfaces, without re-deriving activity composition in Views or ViewModels.

## Source of truth

| Field | Role |
|---|---|
| `PresenceStatus.activity` / `VisiblePresence.activity` | Friend-visible activity label + SF symbol |
| `statusNote` | Optional curated / place note (set equal to `At {place}` by #105 composition) |
| `availability` | Independent free/busy chip — never conflated with activity |

Supported labels from the presence pipeline:

- `At {place}`
- `Chilling`
- `Walking`
- `Driving`
- `Moving`
- `Nearby`

## Design

### Shared presentation (pure)

`PresenceActivityPresentation` in `Push/Data/Derived/` maps presence fields → surface fields:

| Output | Use |
|---|---|
| `activityName` | Raw activity string for models / search |
| `activitySymbolName` | SF symbol for list rows, pucks, detail cards |
| `activityDisplayText` | Compact map badge (strip leading `At ` when present) |
| `venueStatusText` | List / detail status line |

**Status line priority**

1. Non-empty `statusNote` (preserves curated seed notes + `At {place}` notes)
2. Non-empty `activity.name` (Walking / Chilling / … when note is empty)
3. Place: `At {displayName}` or `Near {displayName}` when vague
4. Availability title, else `"Around"`

Never prefix `"At "` onto an activity name (avoids live `"At Walking"` when synthetic place name mirrors activity).

**Missing activity:** empty name + default symbol `mappin`; fall through status priority above.

**Hidden / unpublished:** builders keep existing hidden rows (`"Hidden right now"`, moon symbol). Group member rows treat `!isEffectivelyPublished` as hidden. No stale activity for Ghosted, unpublished, or filtered-expired presence (repo + `VisiblePresenceBuilder` already drop those for friend surfaces).

### Surfaces

| Surface | Change |
|---|---|
| Map exact pucks (`MapContentBuilder`) | Badge + person fields via presentation helper |
| Regional vague sources (`MapDisplayPuckBuilder`) | Same |
| Friends list (`FriendsContentBuilder`) | Same |
| Group members (`GroupContentBuilder`) | Same; respect publish flag |
| Friend detail sheet | Status line = `venueStatusText` / activity — drop coffee/park/gym invent prefixes |
| Hangout activity line | Prefer `venueStatusText` / activity directly |
| Profile (`ProfileContentBuilder`) | `activityTitle` from presence activity (not availability); `placeTitle` remains vague neighborhood |

### Realtime

No new subscription. Map/Friends already reload on `AppDataContainer.onStoreChange` (Realtime → `LiveDataStore` revision). Correct field mapping is enough for activity updates to appear without pull-to-refresh.

### Non-goals

- New inference rules / place resolution
- Schema migrations
- Place-correction UI / background location
- Major UI redesign or design-system chrome changes
- Seed content rewrite (optional later)

## Acceptance

- [x] All listed surfaces use the same presentation helper for activity fields
- [x] Place and movement activities render correct symbol + label
- [x] No `"At Walking"` / double-prefix from synthetic place names
- [x] Availability remains independent of activity
- [x] Hidden / unpublished / missing activity use safe fallbacks
- [x] Focused presentation tests green; existing derivation suites updated only where expectations change
