# Issue #66 — Add Location and Presence Domain Foundations

**Issue:** https://github.com/kaavlu/Push/issues/66  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (PR1 / §10)

## Status

- [x] Extend `PresenceStatus` with orthogonal `isPublished` (+ legacy `.ghost` mapping)
- [x] Domain types: `LocationObservation`, auth/tracking state, drafts, freshness, sync triggers
- [x] Protocols: `LocationProviding`, `LocationSessioning`, validator, inferrer, `PresenceSyncing`
- [x] Phase 1 constants centralized (`LocationPipelineConstants`, `PresenceFreshness`)
- [x] Test doubles: Null/Fake provider, Fake session/sync, accept/reject validator, passthrough inferrer
- [x] Unit tests: `LocationPresenceFoundationTests`
- [x] Build + suite green
- [x] PR limited to foundations (no sim provider, validation logic, session wiring, Supabase)

## Non-goals (this issue)

- Core Location / Info.plist / permission UX
- Simulated route playback / observation validation implementation
- `LocationSession` container wiring / sign-out teardown
- Supabase migrations / live presence reads-writes / Realtime
- Map UI / Ghost Profile migration / throttle execution

## Verification

- [x] `scripts/test.sh suite LocationPresenceFoundationTests` — 20 passed
- [x] `scripts/test.sh suite DataLayerTests` / `DerivationTests` / `EmptySurfaceTests` / `MapRenderTests` — green
- [x] No `import CoreLocation` in new location domain files
