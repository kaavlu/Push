# Issue #100 — Arrival / Departure Lifecycle (I2)

## Status

- [x] Spec (`tasks/spec.md`)
- [x] Transitions + completed session types
- [x] Departure hysteresis config + detector
- [x] Lifecycle fixtures
- [x] `DwellLifecycleTests` — 13 green
- [x] I1 `DwellDetectionTests` — 15 green
- [x] File splits ≤ 400 lines
- [x] Commit

## Acceptance

- One arrival per confirmed dwell; no repeats while active
- Brief near-zone movement / single bad fix do not depart
- Sustained leave → one departure + completed session metadata
- Re-arrival after leave works
- No venue / UI / activity label / publish changes

## Related

- #99 I1 place-cluster detection (done)
- Later: venue resolution from completed sessions
