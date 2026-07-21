# Spec: Complete the Push Lifecycle and Live History (Issue #45)

**Design:** `docs/superpowers/specs/2026-07-20-complete-push-lifecycle-design.md`  
**Issue:** https://github.com/kaavlu/Push/issues/45

## Goal

Finish live Push lifecycle (active → happening → completed), derive History/calendar from real push rows, and wire History › to a month list + read-only detail — without rebuilding create/edit/RSVP/cancel/delete.

## Locked decisions

1. **Derive History on read** from `pushes` + `push_responses` (no hangout table).
2. **Active** while `cancelledAt == nil && now < expiresAt` (time-only).
3. **Cancelled** excluded from Active, History, and calendar.
4. **Lifecycle phases** derived on read; DB `state` not list source of truth.
5. **Edit + RSVP** allowed until expiry (including after `startsAt`).
6. **History ›** opens month History list → item detail.
7. Participants in History = `.in` respondents (not physical attendance).
8. Mock keeps seed hangouts; live never uses them.

## Deliverables

- [x] `PushLifecycle` + history/hangout builder (pure), unit tests
- [x] `activePlans` / `historicalPlans` / `pastHangouts` in Local + Supabase repos
- [x] `PushTimingFormatter` uses derived happening for “now”
- [x] PlansViewModel: month-change reload; History route/state
- [x] History list + read-only detail UI; wire History ›
- [x] Remove/unwire `ManagePushView` stub
- [x] Focused tests + build
- [ ] Manual two-account checklist (live env)

## Out of scope

Presence/places backend, attendance, feed, realtime, notifications, weekly recap storytelling, materialized hangouts, cron.
