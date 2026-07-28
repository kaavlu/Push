# Issue #99 — Deterministic Dwell Detection (I1)

## Status

- [x] Spec (`tasks/spec.md`)
- [x] Domain types + configuration + fixtures
- [x] `DeterministicDwellDetector` state machine
- [x] Silent `LocationSession` wiring (no label / publish changes)
- [x] `DwellDetectionTests` — 15 green
- [x] Regression `LocationSessionTests` / activity suites green
- [x] Register pbxproj + commit

## Acceptance

- Sustained stationary → one stable dwell (centroid, start, duration, samples)
- Single fix / walk-by / traffic-light stop → no false dwell
- GPS drift does not reset start or wander locked centroid
- Activity inference + presence publishing unchanged

## Out of scope

- Venue lookup
- Arrived / left events
- Activity label changes (`.chilling` stays window-based only)
- DB / UI

## Related

- #92–#94 activity inference (parallel; not replaced)
- Location presence architecture Phase 2+ venue path
