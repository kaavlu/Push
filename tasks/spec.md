# Complete Friend Relationship Lifecycle (Issue #44)

## Goal
Harden the live friend system so every relationship state is consistent across
search, requests, Alerts, Friends list, and backend authorization — without
rebuilding the existing send/accept/deny/remove flows.

## Canonical states
One relationship state per pair, derived from the single `friendships` row
(`user_low < user_high`):

| State | Row | Surfaces |
|---|---|---|
| No relationship | no row, or `denied` | search: Add Friend |
| Outgoing request | `pending` + `requested_by` = me | search: Cancel; Alerts: hidden |
| Incoming request | `pending` + `requested_by` ≠ me | search Accept/Decline; Alerts |
| Friends | `accepted` | Friends list; search: Friends |

Closed states (`denied`, cancelled/deleted) never appear as active relationships.

## Backend contract (migration `0013`)
- **`send_friend_request`**: idempotent on active pending; rejects already-friends;
  re-opens `denied` as new pending; race-safe on unique pair (unique_violation
  re-reads and applies the same rules).
- **`resolve_friend_request`**: recipient only; pending only (stale IDs rejected).
- **`cancel_friend_request`**: requester only; pending only; hard-deletes the row
  so Alerts and search clear, and a later send inserts cleanly.
- **`remove_friend`**: either participant; deletes the pair row for any status
  (accepted/pending/denied) so removal always clears incompatible request state;
  group memberships and historical pushes are untouched.

Authorization stays in SECURITY DEFINER RPCs — no raw table writes from clients.

## Client contract
- `FriendRepository.cancelFriendRequest(id:)` (mock + live).
- Search maps the same relation enum already used by Add Friends.
- Add Friends: Cancel on outgoing; mutation failures use `ActionErrorBanner` +
  optimistic rollback (do not wipe search results into full-screen failed).
- Successful mutations bump friendship revision / clear profile cache as today
  so Friends, Alerts, and search agree after reload.

## Out of scope
Blocking, suggestions, contact import, presence beyond existing friend access,
realtime beyond current refresh, UI redesigns.

## Acceptance
Live two-account scenarios 1–17 in GitHub issue #44; unit coverage for
duplicate/reciprocal send, cancel, deny re-request, remove + re-add, search
mapping, optimistic rollback, and unauthorized/stale resolve paths (mock +
loader fakes).
