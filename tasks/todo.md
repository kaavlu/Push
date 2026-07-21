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
- [ ] Apply migration 0013 to remote Supabase (MCP auth required — apply before live smoke)
- [ ] Live two-account smoke (issue acceptance criteria 1–17)

## Verification
- [x] `scripts/test.sh suite FriendRelationshipTests` — 13 tests, 0 failures
- [x] `scripts/test.sh suite AddFriendsTests` — 5 tests, 0 failures
- [x] `scripts/test.sh suite AlertsTests` — 8 tests, 0 failures
