# Issue #69 — LocationSession, App-Lifetime Wiring, Safe Teardown

**Issue:** https://github.com/kaavlu/Push/issues/69  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (PR3 / §2.2–2.5, §2.9, §2.9.1, §10)  
**Builds on:** Issue #66 domain contracts, Issue #68 simulated provider + validator

## Status

- [x] `PresenceSyncing.unpublishCurrentPresence` + `NoOpPresenceSync` / fake tracking
- [x] Concrete `LocationSession` (`LocationSessioning`) — provider → validator → inferrer → sync
- [x] Eligibility (auth + publish + not shut down); no duplicate consumption starts
- [x] Idempotent `stop` / `shutdown`; best-effort `unpublishBestEffort` (timeout)
- [x] `AppDataContainer.locationSession` ownership + inject fake for tests
- [x] DEBUG null default / `--sim-location` simulated provider (`LocationSessionFactory`)
- [x] `installPreparedLive` shuts down previous session (no unpublish)
- [x] `shutdownSharedAndReinstallMock` unpublish → shutdown → mock
- [x] RootView sign-out / delete-account teardown order
- [x] Mock `.app` entry calls `startIfEligible` (sim dogfood)
- [x] Focused tests: `LocationSessionTests`, `LocationSessionContainerTests`

## Non-goals (this issue)

- Core Location / `CLLocationManager`
- Permission UI / Info.plist
- Supabase migrations / live presence writes
- Movement throttle / heartbeat execution
- Ghost UI migration / map changes
- Realtime / synthetic Place / inference

## Verification

- [x] `scripts/test.sh suite LocationSessionTests` — 15 passed
- [x] `scripts/test.sh suite LocationSessionContainerTests` — 8 passed
- [x] `scripts/test.sh suite LocationPresenceFoundationTests` — 20 passed
- [x] `scripts/test.sh suite LocationSimulatedProviderTests` — 8 passed
- [x] `scripts/test.sh suite LocationObservationValidatorTests` — 18 passed
- [x] `scripts/test.sh suite LiveContainerIsolationTests` — 4 passed
- [x] `scripts/test.sh suite DeleteAccountTests` — 6 passed

## Deviations from architecture doc (document in PR)

| Item | Note |
|---|---|
| `PresenceSyncing.unpublishCurrentPresence` | Added for sign-out best-effort seam; was not on PR1 protocol sketch |
| `LocationSessioning.unpublishBestEffort` | Session-facing timeout wrapper (3s) over sync unpublish |
| No movement throttle / heartbeat | Explicitly deferred to live-write PR (PR6) |
| `NoOpPresenceSync` default | Until live presence writer lands; pipeline still exercises upsert path in tests |
| Delete-account unpublish | Skipped after successful delete (server cascade); pipeline still shut down |
