# Issue #79 — Add Core Location Provider

**Issue:** https://github.com/kaavlu/Push/issues/79  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` §2.4, §2.5, §2.9, PR7  
**Base:** main (includes #76 presence throttle/heartbeat/Ghost)  
**PR:** against `main` when done

## Status

- [x] Plan from issue + design
- [x] `CoreLocationMapping` (auth + CLLocation → LocationObservation)
- [x] `CoreLocationLocationProvider` (manager seam, AsyncStream, start/stop)
- [x] Factory: live → Core Location; mock → Null; `--sim-location` → Simulated
- [x] Session: request when-in-use when not determined; safe auth revoke
- [x] Minimal `NSLocationWhenInUseUsageDescription` (polished UX = next issue)
- [x] Tests (provider + factory + session auth)
- [x] Register files + run suites
- [ ] Commits + PR

## Non-goals

- Custom permission onboarding / denial recovery UI
- Background / Always location, significant-change, visits, geofencing
- Realtime, inference, places catalog, map redesign

## Test evidence (local)

| Suite | Result |
|---|---|
| CoreLocationProviderTests | 16 passed |
| LocationSessionTests | 18 passed |
| LocationSessionContainerTests | 10 passed |

## Deliverables

| Area | Change |
|---|---|
| `Push/Data/Location/` | Infra-only Core Location mapping + provider |
| `LocationSessionFactory` | `usesCoreLocation` selection |
| `LocationSession` | Auth request + revoke-only unpublish |
| `Info.plist` | Minimal when-in-use usage string |
| Tests | Fake manager seam; no real GPS |
