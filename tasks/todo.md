# Issue #44 — Complete Friend Relationship Lifecycle

- [x] Spec in `tasks/spec.md`
- [x] Migration `0013_friend_relationship_lifecycle.sql`
  - `cancel_friend_request` (requester / pending / hard-delete)
  - race-safe `send_friend_request` (unique_violation re-read)
  - `remove_friend` deletes any status between the pair
- [x] Swift data layer: `FriendRepository.cancelFriendRequest`, send returns request id
- [x] Mock `InMemoryDatabase` cancel + remove clears pending
- [x] Live loader/store wiring + revision bumps
- [x] Add Friends: Cancel on outgoing; ActionErrorBanner + optimistic rollback
- [x] Tests: `FriendRelationshipTests` (13) + existing suites
- [x] `supabase/README.md` note for 0013
- [x] Apply migration 0013 to remote Supabase (`0013_friend_relationship_lifecycle`)
- [x] Live two-account smoke (Alice/Bob/Carol JWT → PostgREST RPCs)

## Verification
- [x] `scripts/test.sh suite FriendRelationshipTests` — 13 tests, 0 failures
- [x] `scripts/test.sh suite AddFriendsTests` — 5 tests, 0 failures
- [x] `scripts/test.sh suite AlertsTests` — 8 tests, 0 failures
- [x] Migration history includes `0013_friend_relationship_lifecycle`
- [x] Function grants: cancel/send/remove/resolve — authenticated only (anon/public false)
- [x] Security advisors: only expected WARN for intentional public SECURITY DEFINER RPCs + auth leaked-password toggle (no new high-severity)
- [x] Live smoke 18/18: send, idempotent re-send, incoming pending, requester/unrelated reject resolve, deny, re-request, cancel, stale cancel, accept, already-friends reject, remove, groups intact, re-request after remove
