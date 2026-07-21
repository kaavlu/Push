# Complete Group Lifecycle (Issue #43)

- [x] Design: `docs/superpowers/specs/2026-07-20-complete-group-lifecycle-design.md`
- [x] Plan: `docs/superpowers/plans/2026-07-20-complete-group-lifecycle.md`
- [x] Migration `0015_group_lifecycle` (RPCs + `group-photos` Storage) — SQL in repo (renumbered after main's `0013` friend + `0014` delete account)
- [x] `GroupRepository` lifecycle APIs + `GroupPhotoStoring`
- [x] Mock lifecycle (`InMemoryDatabase+GroupLifecycle` / `LocalGroupRepository`) + tests
- [x] Live RPCs + photo upload (`SupabaseGroupRepository` / `LiveDataStore` / `0015`)
- [x] Add Group: create then `updateGroupPhoto` for picked JPEG
- [x] Member presentation: `membershipID`, `isOwner`, `isPending`
- [x] `GroupsViewModel` lifecycle mutations + `ActionErrorState` / retry
- [x] Group Detail management UI (rename/photo/invite/cancel/remove/leave/transfer/delete)
- [x] Focused verification suites + build + full suite

## Verification
- [x] `scripts/test.sh suite GroupLifecycleTests` — 17 tests, 0 failures
- [x] `scripts/test.sh suite DataLayerTests` — 26 tests, 0 failures
- [x] `scripts/test.sh suite LiveDataStoreTests` — 13 tests, 0 failures
- [x] `scripts/test.sh suite GroupsTests` — 6 tests, 0 failures
- [x] `scripts/test.sh build` — SUCCEEDED
- [x] `scripts/test.sh full` — 251 tests, 0 failures
- [ ] Live smoke (acceptance 1–16) when `0015` applied + two test accounts
- [ ] Confirm remote apply of `0015_group_lifecycle` via MCP/CLI if not yet on project

---

# Issue #45 — Complete the Push Lifecycle and Live History

**Design:** `docs/superpowers/specs/2026-07-20-complete-push-lifecycle-design.md`  
**Plan:** `docs/superpowers/plans/2026-07-20-complete-push-lifecycle.md`  
**Spec:** `tasks/spec.md`

## Status

- [x] Product decisions (derive, time-only active, cancel excluded, edit until expiry, History month list)
- [x] Design doc written
- [x] Implementation plan
- [x] Implementation
- [x] Focused verification

## Implementation checklist

- [x] Pure lifecycle + hangout/history derivation + tests
- [x] Local + Supabase repository wiring (`activePlans`, `historicalPlans`, `pastHangouts`)
- [x] Timing formatter + ViewModel month reload + History state
- [x] History list + detail UI; wire History ›
- [x] Remove ManagePushView stub
- [x] Focused test suites + build
- [ ] Manual AC smoke (two accounts) when live env available

## Verification

- [x] `PushLifecycleTests` 6/6
- [x] `PushTimingFormatterTests` 4/4
- [x] `SupabasePushRepositoryTests` 7/7
- [x] `PlansViewModelTests` 24/24
- [x] `LiveDataStoreTests` 13/13
