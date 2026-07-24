# Issue #73 — Live Presence Reads and Synthetic Place Mapping

**Issue:** https://github.com/kaavlu/Push/issues/73  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (PR5 / §1.2, §1.7, §2.4, §2.6, §2.8)  
**Builds on:** Issue #71 (`0018_current_presence`)

## Status

- [x] `CurrentPresenceRow` DTO + `PresenceStatus` / synthetic `Place` mapping
- [x] `LiveDataLoading.loadPresence` + `SupabaseLiveDataLoader`
- [x] `LiveDataStore` presence cache, warm, snapshot, restore, `notifyPresenceChanged`
- [x] `SupabaseFriendRepository.presenceStatuses()`
- [x] `SupabasePushRepository.allPlaces()` → synthetic places from presence cache
- [x] `VisiblePresenceBuilder` non-self unpublished defense
- [x] Tests: `LivePresenceReadTests`, store/isolation updates
- [ ] Run suites: LivePresenceReadTests, LiveDataStoreTests, LiveContainerIsolationTests, MapRenderTests
- [ ] PR

## Non-goals (this issue)

- Presence upserts / unpublish from Swift
- Core Location / permission UI
- Realtime
- Places catalog / reverse geocode / co-location
- Availability dual-write client / Ghost UI migration
