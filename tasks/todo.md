# Issue #64 — Audit repository architecture for location tracking and activity inference

**Issue:** https://github.com/kaavlu/Push/issues/64  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md`

## Status

- [x] Audit current map/presence data flow with concrete file references
- [x] Recommend ownership (LocationSession, sync, presence, inference, presentation)
- [x] Domain model + protocol boundaries (mock / sim / Core Location)
- [x] Supabase conceptual shape (`current_presence`, RLS, Realtime → revision)
- [x] Privacy matrix (SharingPolicy + orthogonal Ghost)
- [x] Testing strategy without physical movement
- [x] Phase 1 follow-up issue plan + PR plan
- [x] Key Decisions (all 10 audit questions)
- [x] Design review loop (3 rounds → approve, 0 open issues)
- [x] Phase 0 final clarifications (rev 4): Ghost orthogonal, unpublish lifecycle, freshness, throttle bypasses, availability canonical field, Realtime required for completed surface, CL type boundary, Phase 1 non-goals, split CL provider vs permission UX
- [x] Commit design document and close #64

## Non-goals (confirmed)

- No Core Location integration
- No migrations / Realtime / inference implementation
- No mock puck replacement

## Verification

- Architecture doc present (rev 4 Phase 0 clarifications)
- No production location code introduced
