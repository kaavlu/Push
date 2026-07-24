# Issue #76 — Presence Throttling, Heartbeat, Ghost, Availability Sync

**Issue:** https://github.com/kaavlu/Push/issues/76  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` §2.5, §2.7.1, §2.4 dual-write  
**Base:** main (includes #75 `SupabasePresenceSync` write buffer)  
**PR:** against `main` when done

## Status

- [x] Plan written
- [x] Pure publish policy (60s/50m + first fix + heartbeat due)
- [x] LocationSession: movement throttle, firstEligibleStart, 15m heartbeat
- [x] Ghost: unpublish on, republish last fix off (orthogonal to availability)
- [x] Availability dual-write via `set_availability_choice` (one revision)
- [x] Profile: Ghost → publish flag; availability ActionError + rollback
- [x] Mock LocalPresenceSync parity for Ghost/unpublish
- [x] Wire live availabilityProvider from profile cache
- [x] Tests (policy, session throttle/heartbeat/ghost, dual-write, bypass)
- [x] Register files + run suites
- [ ] Commits + PR

## Non-goals

- Core Location, permission UX, Realtime, background tracking
- Venue/activity inference, map redesign
- Re-implement #75 write buffer (extend only)

## Test evidence (local)

| Suite | Result |
|---|---|
| PresencePublishPolicyTests | 10 passed |
| LocationPresenceThrottleTests | 8 passed |
| LocationSessionTests | 15 passed |
| LivePresenceWriteTests | 12 passed |
| DataLayerTests | 27 passed |
| LocationPresenceFoundationTests | 20 passed |
| LocationSessionContainerTests | 8 passed |

## Deliverables

| Area | Change |
|---|---|
| `PresencePublishPolicy` | Pure 60s/50m + heartbeat-due decisions |
| `LocationSession` | Throttle, first fix, heartbeat timer, Ghost unpublish/republish |
| `LiveDataStore` / loader | `set_availability_choice` RPC; one revision; mirror presence cache |
| `ProfileViewModel` | Orthogonal Ghost; availability failure ActionError + rollback |
| Mock | `LocalPresenceSync` + store publish flag (Busy+Ghost) |
| Tests | Policy + session + dual-write + bypass matrix |
