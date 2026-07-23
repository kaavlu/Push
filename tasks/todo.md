# Issue #68 — Add Simulated Location Provider and Observation Validator

**Issue:** https://github.com/kaavlu/Push/issues/68  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (PR2 / §10)  
**Builds on:** Issue #66 domain contracts

## Status

- [x] Validation thresholds centralized in `LocationPipelineConstants`
- [x] `GeoDistance` haversine helper (app Doubles only)
- [x] `LocationObservationValidator` (`LocationObservationValidating`, pure/Sendable)
- [x] `SimulatedLocationRoute` + representative fixtures
- [x] `SimulatedLocationProvider` (manual + timed, injectable sleep)
- [x] Unit tests: `LocationObservationValidatorTests`, `LocationSimulatedProviderTests`
- [x] No Core Location / Supabase / LocationSession / map wiring

## Thresholds added beyond architecture doc (document in PR)

| Constant | Value | Why |
|---|---|---|
| `maxObservationAge` | 5 min | Drop stale GPS fixes |
| `futureTimestampTolerance` | 60 s | Device clock skew |
| `highConfidenceAccuracyMeters` | 20 m | High vs medium confidence |
| `highConfidenceMaxAge` | 30 s | High vs medium confidence |
| `maxPlausibleSpeedMetersPerSecond` | 90 m/s (~324 km/h) | Reject teleports; allow highway |
| `nearDuplicateDistanceMeters` | 1 m | Drop near-duplicate noise |
| `nearDuplicateTimeInterval` | 1 s | Drop near-duplicate noise |
| `earthRadiusMeters` | 6_371_000 | Haversine |

Architecture already locked `maxHorizontalAccuracyMeters` = 100.

## Non-goals (this issue)

- `LocationSession` / AppDataContainer wiring
- Presence draft / sync / Supabase
- Core Location / permission UX
- Map / Ghost migration / inference

## Verification

- [x] `scripts/test.sh suite LocationObservationValidatorTests` — 18 passed
- [x] `scripts/test.sh suite LocationSimulatedProviderTests` — 8 passed
- [x] `scripts/test.sh suite LocationPresenceFoundationTests` — foundation still green
