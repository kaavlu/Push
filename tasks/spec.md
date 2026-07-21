# Block / Unblock User (Issue #52)

## Goal
Allow a user to block another so further **direct** social interaction is impossible
(backend-enforced). Unblock removes the restriction but does **not** restore friendship
or reopen closed requests.

## Contract
- Directed `public.user_blocks` + `private.is_blocked` (bidirectional) + SECURITY DEFINER
  RPCs: `block_user` / `unblock_user` / `list_blocked_users` (migration `0016`).
- Guards on friend request, resolve, search, create_group invitees, and direct push
  invitees; shared group memberships and historical pushes/groups are not mutated.
- App API on `FriendRepository`: `blockUser` / `unblockUser` / `blockedUsers` →
  `[BlockedPerson]`. Mock tears down friendship + pending requests; live RPCs +
  `notifyFriendshipsChanged`. Soft-hide blocked-pair alerts/pickers.
- UI: Friends expand **Block** + confirm (no optimistic remove; `ActionErrorBanner`);
  Profile → Blocked list → Unblock (`fullScreenCover`).
- Full design: `docs/superpowers/specs/2026-07-20-block-unblock-user-design.md`.

## Acceptance
See design doc acceptance criteria. Focused suites: `BlockUserTests`, plus regression
on DataLayer / LiveDataStore / Alerts; `scripts/test.sh build`.

---

# Complete Group Lifecycle (Issue #43)

## Goal
Finish live group lifecycle after create + invite accept/deny (`0011`): owners/members
manage groups from Group Detail; photos persist via Storage; backend-enforced permissions.

## Contract (summary)
- Design: `docs/superpowers/specs/2026-07-20-complete-group-lifecycle-design.md`
- Plan: `docs/superpowers/plans/2026-07-20-complete-group-lifecycle.md`
- Migration `0015_group_lifecycle`: `SECURITY DEFINER` RPCs (rename/photo/invite/cancel/
  remove/leave/transfer/delete) + public `group-photos` bucket; no broad client writes
  on `groups` / `group_memberships`.
- Client: `GroupRepository` lifecycle methods; mock mirrors `0015` rules; live via
  `SupabaseGroupRepository` → `LiveDataStore` → RPCs + `GroupPhotoStoring` (orphan rollback).
- UI: Group Detail management hub; `GroupsViewModel` mutations + `ActionErrorBanner`.
- Hard delete groups; `pushes.group_id` SET NULL; owner leave requires transfer if others remain.

## Acceptance
See design doc acceptance 1–16; unit coverage in `GroupLifecycleTests` / related suites.

---

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
