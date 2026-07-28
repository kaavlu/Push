# Issue #105 — Attach Resolved Place Context to Presence Activity

## Goal

Connect place resolution + activity inference into one canonical friend-visible presence activity so friends can receive labels such as:

- At Crunch Fitness
- At Starbucks
- Chilling
- Walking
- Driving
- Moving
- Nearby

Builds on #99–#101 (dwell / lifecycle / place resolution), #94 (activity presentation), and live presence reads/writes/Realtime (`current_presence`).

## Fallback order (canonical)

```
confident resolved place → At {place}
confirmed dwell without a reliable place → Chilling
walking → Walking
driving → Driving
generic movement → Moving
otherwise → Nearby
```

Place context must not stick after departure, Ghost (friend-visible unpublish), hard expiry, or invalid/non-confident resolution.

## Design

### Composition (pure)

`ActivityInferencePresentation.compose` (or apply) merges:

| Input | Role |
|---|---|
| `InferredActivityResult` + heartbeat hold | Motion class |
| `activePlaceResolution` | Confident POI only (`.resolved` + selected name) |
| Confirmed dwell (`phase == .dwelling` + active session) | Enables Chilling when place is weak |

Outputs onto `PresenceStatusDraft`:

- `activity` (`activity_name` / `activity_symbol`)
- `statusNote` — set to `At {place}` when place is attached (so existing “At \(place)” UI paths do not double-prefix)
- `placeID` — resolved candidate id when attached; `nil` otherwise (no places catalog required; friend map place remains synthetic from coords)
- `confidence` / `source` — inference when classified/place; location for unknown Nearby

No schema migration — reuse `current_presence.activity_name`, `activity_symbol`, `place_id`, `status_note`.

### Session wiring

- `LocationSession.enqueueDraft` always runs composition (never blocks on resolver).
- On place-resolution **apply** (async success): if publishing, `republishLastAcceptedIfPossible()` so friends get `At {place}` without waiting for movement/heartbeat.
- On **departure**: clear place context, then republish when publishing so stale place/Chilling leave friend view promptly.
- Ghost / unpublish: existing unpublish path removes friend-visible presence; local place context may remain for re-dwell/republish after Ghost off.
- Resolver failure / ambiguous / empty: no confident place; dwell → Chilling; publish path unchanged.

### Non-goals

UI redesign, place correction UI, co-presence, background location, ETA, feed, new inference rules, places catalog.

## Acceptance

- [x] Confident place publishes as `At {place}`
- [x] Ambiguous / failed / empty resolution falls back safely
- [x] Friends receive activity via existing writes + Realtime/`LiveDataStore` patches
- [x] Departure clears friend-visible place activity on next draft
- [x] Manual availability remains independent
- [x] Ghost / heartbeat / throttle / teardown behavior preserved
- [x] Tests: compose, place, fallback, clear, write mapping, remote read

## Tests

- Pure composition unit tests
- Session: resolve → `At …` draft; empty dwell → Chilling; departure clears
- Existing `ActivityInferenceIntegrationTests` / presence suites still green (`Moving` label)
