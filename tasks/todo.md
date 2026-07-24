# Issue #75 — Supabase Presence Writes and Sync Buffer

**Issue:** https://github.com/kaavlu/Push/issues/75  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (PR5b write path)  
**Builds on:** Issue #73 (live presence reads), #71 (`0018_current_presence`)

## Status

- [x] Extend `PresenceStatusDraft` with coordinates + inferrer mapping
- [x] `CurrentPresenceWriteMapping` / upsert payload (snake_case, expiry, vague pair)
- [x] `LiveDataLoading` + `SupabaseLiveDataLoader` upsert + `unpublish_current_presence` RPC
- [x] `LiveDataStore` write-through (`upsertOwnPresence` / `unpublishOwnPresence`, one revision)
- [x] `SupabasePresenceSync` latest-draft buffer, coalesce, `flushPending`, `shutdown`
- [x] Wire live container (`AppDataContainer.makeLiveLocationSession`)
- [x] `LocationSession.shutdown` → `PresenceSyncing.shutdown`
- [x] Tests: `LivePresenceWriteTests` + regression suites
- [ ] PR

## Non-goals (this issue)

- Movement throttle / first-fix timing policy (Issue #76)
- Stationary heartbeat (Issue #76)
- Manual availability dual-write / Ghost UI migration (Issue #76)
- Core Location / permission UI
- Realtime

## Dogfood

`scripts/run-ios-sim.sh -- --live --sim-location` after signing in — simulated fixes should upsert `current_presence` for the authenticated user.
