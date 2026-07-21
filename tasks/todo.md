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
