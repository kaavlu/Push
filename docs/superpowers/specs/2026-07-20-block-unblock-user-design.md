# Block and Unblock User (Issue #52)

## Goal

Allow a user to block another user so that further **direct** social interaction is impossible, enforced by the backend. Unblocking removes the restriction but does **not** restore the previous friendship or reopen closed requests.

## Non-goals

- Reporting users or moderator review tools
- Temporary mute
- Blocking group-wide content
- Automatically removing either user from shared groups
- Restoring friendships after unblocking
- Device-level contact blocking
- Realtime / push notifications of block state (other sessions learn via refresh)
- Block entry points beyond Friends list expand actions (map sheet, Add Friends results)

## Product decisions

| Topic | Choice |
|-------|--------|
| Block entry | Friends list expand row only (next to Remove), with confirmation |
| Blocked list / Unblock | Profile → **Blocked** card → full-screen list |
| Pending invites on block | Soft-hide from active UI; server rejects resolve/accept while blocked; no hard-delete of historical Push/group rows |
| Shared groups | Memberships unchanged; no direct-friend visibility restored via co-membership |
| Notify blocked user | Never |
| Backend model | Directed `user_blocks` table + SECURITY DEFINER RPCs + `private.is_blocked` |
| App API | Methods on `FriendRepository` (same social-graph home as remove/search) |

## Acceptance criteria (from issue)

- User A can block User B from Friends expand + confirmation
- Existing friendship removed for both; pending requests both ways closed
- Neither can send new friend requests or direct Push/group invites to the other
- Direct friend-only access revoked
- Blocking does not notify User B
- Shared group rule as documented below
- User A can view blocked list and unblock; friendship not restored
- New friend request allowed after unblock
- Backend rejects bypass attempts (both directions)
- Failed block/unblock leaves UI consistent (`ActionErrorBanner`, no premature list mutation)
- Historical Push and group records remain valid

---

## 1. Data model

### Table `public.user_blocks`

| Column | Type | Notes |
|--------|------|--------|
| `id` | uuid PK | default `gen_random_uuid()` |
| `blocker_id` | uuid NOT NULL | → `profiles(id)` ON DELETE CASCADE |
| `blocked_id` | uuid NOT NULL | → `profiles(id)` ON DELETE CASCADE |
| `created_at` | timestamptz NOT NULL | default `now()` |

Constraints:

- `blocker_id <> blocked_id`
- UNIQUE `(blocker_id, blocked_id)`

Indexes:

- `(blocker_id, created_at DESC)` for list
- `(blocked_id)` for reverse lookups in `is_blocked`

### RLS

- `SELECT`: only rows where `blocker_id = auth.uid()` (blocker manages their list)
- No client INSERT / UPDATE / DELETE policies — writes only via SECURITY DEFINER RPCs
- Blocked user never reads the row (silent)

### Helper `private.is_blocked(a uuid, b uuid) → boolean`

Returns true if a row exists with `(blocker_id, blocked_id)` in either direction. Lives in non-API-exposed `private` schema (same pattern as `private.is_friend`).

---

## 2. Backend RPCs and guards

Migration: `0013_user_blocks.sql` (after `0012b_profile_photos_select_own`).

All RPCs: `SECURITY DEFINER`, `set search_path = ''`, grant `EXECUTE` to `authenticated` only.

### `block_user(target_user_id uuid) → void`

1. Require `auth.uid()`; reject null/self/unknown profile.
2. Insert into `user_blocks` (idempotent: `ON CONFLICT DO NOTHING` or equivalent).
3. Tear down the undirected friendship pair for `(me, target)`:
   - Delete the `friendships` row regardless of `pending` / `accepted` / `denied` so no lingering request exists either way.
4. Do **not** modify `group_memberships`, `pushes`, or `push_responses`.
5. Do **not** insert notifications or otherwise signal the blocked user.

### `unblock_user(target_user_id uuid) → void`

1. Require auth; reject null/self.
2. Delete only where `blocker_id = auth.uid()` and `blocked_id = target`.
3. No friendship restore; no request reopen.

### `list_blocked_users() → table(id, first_name, handle, image_asset_path)`

- Joins `user_blocks` → `profiles` for `blocker_id = auth.uid()`.
- Ordered by `user_blocks.created_at` DESC.
- Limited public fields only (same spirit as `search_profiles`).

### Guards (bidirectional via `private.is_blocked`)

| Path | Behavior when blocked |
|------|------------------------|
| `send_friend_request` | Raise exception (e.g. `blocked`) |
| `resolve_friend_request` | Raise if either party is blocked relative to the other (stale IDs) |
| `search_profiles` | Exclude profiles that are blocked with the caller either way |
| `create_group` invitee loop | Reject blocked invitees (in addition to `is_friend`) |
| Push create / direct recipient validation | Reject blocked person recipients (server path that validates direct invitees; group-audience pushes still follow group membership) |
| Friend-only visibility | Correct after friendship delete; co-membership must **not** re-open friend-only presence/profile beyond existing group rules |

If push recipient validation is only client-side today, add or extend a server-side check on create/update so direct person invitees cannot include a blocked pair. Group-wide audience continues to use group membership rules.

### Shared groups (documented rule)

- Blocking does **not** remove either user from shared groups.
- Shared membership remains visible where required for the group to function.
- Direct interaction (friend request, direct Push invite, direct group invite to a **new** group as invitee) remains blocked.
- Group-wide actions continue to follow group membership RLS.
- No direct-friend visibility is restored solely because of shared membership.
- Information that may remain visible because of shared groups: group name/image, active co-member listing as required by group UI, group-scoped pushes the user is already on — not friend-only map presence or private friend profile detail.

### Pending invites (soft-hide)

- On block: do not hard-delete historical Push or group invite rows.
- Client: after successful block, filter alerts / active invitation surfaces so the blocked pair’s pending items are not actionable.
- Server: accept/resolve of stale friend request, group invite, or push RSVP involving a blocked pair fails while the block exists.
- After unblock: historical rows remain; they do not auto-reopen as pending social work unless product later defines that (out of scope — closed requests stay closed; friendship not restored).

---

## 3. App architecture

### Repository

Extend `FriendRepository`:

```text
func blockUser(_ personID: Person.ID) async throws
func unblockUser(_ personID: Person.ID) async throws
func blockedUsers() async throws -> [BlockedPerson]
```

`BlockedPerson`: `id`, `firstName` (or display name), `handle`, `imageAssetPath` — presentation-ready, mirrors search result shape.

**Local (`InMemoryDatabase` + `LocalFriendRepository`):**

- Store directed block pairs.
- `blockUser`: insert block; remove friendship + any pending request involving the pair; `didMutate()`.
- `unblockUser`: remove only outbound block; `didMutate()`.
- `searchPeople` / friend lists / invite pickers exclude bidirectional blocks.
- Alerts builder soft-hides friend-request rows involving a blocked pair.

**Live (`SupabaseFriendRepository` + loader):**

- RPC `block_user` / `unblock_user` / `list_blocked_users`.
- On successful block/unblock: invalidate profile/friendship-related caches the same way as remove/accept friend (`notifyFriendshipsChanged` or equivalent) so Friends, Alerts, Add Friends, and recipient pickers update without relaunch.
- `blockedUsers()` is **on-demand** when the Blocked list loads — not part of the six-table session warm.

### ViewModels

| VM | Responsibility |
|----|----------------|
| `FriendsViewModel` | `blockFriend` with confirmation already handled in view; success removes row; failure → `actionError` + retry; no list remove until success |
| `BlockedUsersViewModel` | `LoadState<[BlockedPerson]>`; `unblock`; `actionError`; optional pull-to-refresh via `refreshSession` then reload list |

Views remain dumb; no `import Supabase` outside auth/repo layer.

### UI

| Surface | Behavior |
|---------|----------|
| `ExpandableFriendRow` | Add **Block** action (with Remove / Start push / Directions as today). Confirmation dialog before call. |
| Confirmation copy | Short, calm: e.g. “They won’t be notified. You won’t appear as friends.” Primary destructive **Block**. |
| Profile | New **Blocked** card (cream Friends treatment, same weight as Legal). Navigates to blocked list. |
| Blocked list | Full-screen cream list: avatar, name, handle, **Unblock**. Empty: “No blocked people.” Light confirm on unblock. |
| Errors | Shared `ActionErrorBanner` (message, Retry, dismiss). |

### Client filtering after block

- Drop blocked person from Friends list immediately after successful RPC (store revision / reload).
- Soft-hide their alerts and remove them from friend-token pickers (Start Push, Add Group).
- Live search already excludes server-side; mock filters in store.
- Stale search result → send request fails server-side; surface as action error.

### Error and refresh

- Do not remove local relationships unless backend block succeeds.
- On failure: banner + retry; list unchanged.
- On uncertain partial failure: `refreshSession()` / social reload so UI matches server.
- Other devices: correct after foreground re-warm or pull-to-refresh (Realtime out of scope).

---

## 4. File / layer map (implementation guide)

| Area | Touchpoints (expected) |
|------|------------------------|
| Migration | `supabase/migrations/0013_user_blocks.sql`; note in `supabase/README.md` |
| Private helper | `private.is_blocked`; guards in 0009/0011/push RPCs as needed |
| Domain | `BlockedPerson` (or adjacent to search result types) |
| Store | `InMemoryDatabase` block set + teardown helpers |
| Repos | `FriendRepository`, Local + Supabase impls, loader protocol methods |
| Live store | Cache invalidation on block/unblock |
| Friends UI | `ExpandableFriendRow`, `FriendsView` / `FriendsViewModel` |
| Profile UI | `ProfileView` Blocked card; `BlockedUsersView` + ViewModel |
| Alerts / builders | Soft-hide blocked-pair requests where content is built client-side |
| Selectors | Start Push / Add Group friend pickers exclude blocked |
| Tests | See §5 |
| Xcode | `python3 scripts/pbxproj_add.py` for new Swift files |

---

## 5. Testing

### Mock / unit

- Block with existing friendship
- Block with outgoing pending request
- Block with incoming pending request
- Block with no prior relationship (store/RPC path; UI may only expose block for current friends)
- Bidirectional friend-request prevention after block
- Search and audience selector filtering
- Soft-hide alerts for blocked pair
- Unblock: restriction gone; friendship not restored; re-request allowed
- Three-account: unrelated relationships unaffected
- Failed block/unblock leaves prior state; retry path
- Cache invalidation / revision after success

### Live / mapping / auth

- Loader/RPC call paths for block, unblock, list
- Only blocker can remove their block row; blocked user cannot unblock themselves
- Bypass attempts rejected when exercises exist (or SQL notes + focused repo tests with fakes)

### Manual / MCP when applying migration

- `send_friend_request` / resolve / create_group blocked invitee / direct push invitee rejected
- Shared group membership still works; no friend-only presence restored
- `get_advisors(security)` — treat high findings on new objects as blocking

### Out of automated scope unless cheap

- Full UI snapshot tests
- Realtime multi-session

---

## 6. Rollout notes

- DEBUG mock: full block/unblock without network.
- Live: apply `0013` via Supabase migration workflow (MCP/skills); seed needs no default blocks.
- Documentation: durable notes in `agents.md` / `supabase/README.md` after implementation (post-commit doc skill may handle).

---

## 7. Open implementation details (resolved defaults)

| Detail | Default |
|--------|---------|
| Friendship row on block | **Delete** entire pair row (any status), not status flip |
| Mutual block | Both directions allowed as separate rows; `is_blocked` true if either exists |
| Block non-friend from UI | Not in v1 UI; RPC still allows block without prior friendship for defense in depth |
| List warm | On-demand only |
| Repository home | `FriendRepository` |
| Push historical rows | Preserve; soft-hide + reject resolve while blocked |

---

## Self-review checklist

- [x] No TBD placeholders for product behavior
- [x] Shared groups rule explicit
- [x] Soft-hide vs hard-delete consistent
- [x] UI entry points match decisions (Friends + Profile Blocked)
- [x] Backend enforcement both directions
- [x] Scope fits one implementation plan (migration + data + Friends + Profile + tests)
