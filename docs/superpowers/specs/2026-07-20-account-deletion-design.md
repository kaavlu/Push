# In-app account deletion (Issue #48)

**Date:** 2026-07-20  
**Issue:** [kaavlu/Push#48](https://github.com/kaavlu/Push/issues/48)  
**Status:** Implemented (client + migration file); remote apply + live smoke pending

## Problem

Users need a way to permanently delete their Push account from the app (Profile / settings). Deletion must remove the Supabase Auth user and clean or cascade related application data. Deleting only a local profile row (or a client-only soft flag) is insufficient: the Auth identity would still sign in, and friends/groups could retain private linkage.

## Goals / done when

- A signed-in **live** user can start account deletion from Profile.
- The user must explicitly confirm; copy states deletion is permanent.
- A secure authenticated backend path deletes the **caller’s** Auth user and cleans related data.
- After success: local session and live caches are cleared; UI returns to the auth gate; relaunch stays on auth.
- Failed deletion leaves the user signed in and shows a recoverable error (no optimistic “deleted” state).
- The deleted user cannot sign in again; they disappear from friends, requests, memberships, and audience-relevant surfaces for others after their clients refresh.
- Group ownership is handled without orphaned multi-member groups or dangling sole-owner groups.
- Profile photo storage for the user is removed where appropriate.
- Shared records remain internally consistent (FKs / transfer rules).

## Non-goals

- Temporary deactivation / “pause account.”
- Exporting account data (GDPR data export is a separate product).
- Restoring a deleted account.
- Admin deletion of another user.
- Mock-mode account deletion (DEBUG mock has no real Auth user; control is live-only like Sign Out).
- Edge Functions or service-role client secrets in the app.

## Product decisions

| Decision | Choice |
|---|---|
| Backend mechanism | Single `SECURITY DEFINER` RPC `public.delete_account()`; no user-id argument |
| Auth deletion | `DELETE FROM auth.users WHERE id = auth.uid()` inside the RPC (profiles already `ON DELETE CASCADE` from Auth) |
| Group ownership | **Transfer then delete:** if other active members remain, promote one to owner; if none, delete the group |
| Owner promotion rule | Earliest active membership by `joined_at`, then `person_id` for stability |
| UI placement | Profile, below Sign Out; live-only |
| Confirmation | Explicit destructive confirmation before the RPC |
| Client ownership | Environment-injected effect owned by `RootView` (parallel to `SignOutAction`) |
| Mock | Hide control; no simulated deletion |
| Failure | Stay signed in; show recoverable error + retry; never enter gate until RPC succeeds |

## Architecture

```
ProfileView (confirm + busy + error)
    → environment DeleteAccountAction
        → RootView.performDeleteAccount
            → AuthService.deleteAccount()
                → RPC public.delete_account()
                → clear local Auth session (best-effort signOut)
            → authModel.signOutReset()
            → enter(.gate)  // only after RPC success
```

Views never import Supabase. ViewModels that own profile content do not perform Auth deletion; `RootView` owns session lifecycle (same as sign-out).

### Why an RPC, not client multi-step deletes

- Atomic server-side cleanup avoids partial graphs if the app crashes mid-delete.
- Auth user deletion is not available via normal authenticated client Admin APIs without service role.
- Matches existing write patterns (`remove_friend`, `create_group`, friend/group invite RPCs).
- No target `user_id` parameter → cannot delete another user by IDOR.

### JWT note

Deleting `auth.users` invalidates server-side sessions for that user. The client must still clear local persisted session storage. Order is **RPC first**, then local clear; if local `signOut` fails because the session is already gone, treat as success for routing purposes after a successful RPC.

## Backend: `public.delete_account()`

**Migration:** next free file under `supabase/migrations/` (e.g. `0013_delete_account.sql`).

### Signature and privileges

```sql
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$ ... $$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
```

- `me uuid := (select auth.uid());`
- If `me is null` → `raise exception 'not authenticated'`.
- **No parameters.** Only the JWT subject can be deleted.

### Cleanup sequence

Order is deliberate: handle non-cascading ownership and storage **before** Auth delete.

1. **Authenticate** — require `auth.uid()`.
2. **Avatar storage** — delete objects under the user’s avatars prefix (bucket from `0012_profile_photos`, path convention `{auth.uid()}/…`). Failures that leave orphan objects are non-ideal but must not block Auth deletion if the API cannot list/delete; prefer best-effort delete then proceed. Document the storage API used in the migration comments (Storage SQL helpers if available, or note that cascade of profile path alone does not remove Storage objects).
3. **Group ownership (transfer then delete)**  
   For each `group_id` where `me` has an **active** membership with `role = 'owner'`:
   - Select another **active** member (any role), ordered by `joined_at asc`, `person_id asc`.
   - If found: set that membership’s `role` to `'owner'`.
   - Delete `me`’s membership on that group (if not already removed later in bulk).
   - If **no** other active member: `DELETE FROM public.groups WHERE id = group_id`  
     (memberships cascade; `pushes.group_id` is `ON DELETE SET NULL` per `0006`).
4. **Remaining memberships** — delete any remaining `group_memberships` for `me` (active or invited), covering non-owned groups and pending invites on the user.
5. **Friendships** — delete rows involving `me` if not fully covered by profile cascade (explicit delete keeps behavior testable and independent of FK graph assumptions). Pending and accepted both go.
6. **Auth user** — `DELETE FROM auth.users WHERE id = me`.  
   Cascades:
   - `profiles` (`0001`: `references auth.users on delete cascade`)
   - Rows FKed to `profiles` with `on delete cascade` (friendships, memberships if any left, sharing policies, push responses, pushes as creator, etc.)

Owned **pushes** and **push_responses** for the user must not leave broken FKs. Prefer cascade from profile/Auth; the RPC may delete creator pushes explicitly before Auth delete if review shows a non-cascade path — verify against live migrations during implementation.

### What remains for others

| Data | After deletion |
|---|---|
| Friend list / pending requests involving user | Gone |
| Group membership / invites for user | Gone |
| Groups with other active members | Survive; ownership transferred if user was owner |
| Sole-member (or no other active) owned groups | Deleted |
| Pushes created by user | Removed (cascade / explicit) |
| Responses by user on others’ pushes | Removed |
| Group-backed pushes whose `group_id` was deleted | `group_id` set null; push may remain if another creator — only user-created pushes are removed with the user |
| Sharing policies owned by user | Removed |
| Profile photo path + Storage object | Path gone with profile; object best-effort deleted |

Personal display fields (name, handle, photo) are no longer readable once the profile is gone. Historical feed rows are out of scope (live feed is empty day-1).

### Authorization

- Only `authenticated` may execute.
- Function body always uses `auth.uid()`; never a client-supplied id.
- Advisors: run security advisors after applying migration; treat new high findings as blockers.

## Client

### `AuthService`

```swift
func deleteAccount() async throws
```

- **`SupabaseAuthService`:** invoke `delete_account` RPC with the user’s session; on success clear `currentUser` and best-effort `client.auth.signOut()` so local keychain/session storage is empty.
- **`FakeAuthService`:** throw a dedicated “not supported” (or leave unimplemented if never called); Profile hides the control when the env action is unavailable.
- Map failures to calm copy, e.g. `AuthUserMessage` extension or a small delete-specific string: “Couldn’t delete your account. Check your connection and try again.”

Do **not** sign out before the RPC succeeds.

### `RootView`

- Add `DeleteAccountAction` (same shape as `SignOutAction`: available only when live).
- `performDeleteAccount()`:
  1. `try await auth.deleteAccount()`
  2. On success: `authModel.signOutReset()`; tear down / avoid reusing stale live container (same end state as sign-out: `.gate`).
  3. On failure: rethrow or surface to caller; **stay** on `.app`.
- Inject via environment for Profile.

### Profile UI

- Live only: **Delete Account** control under Sign Out (destructive label styling; walnut/cream profile surface, not map glass).
- Confirmation: title “Delete Account?”; body states permanent removal of profile, friends links, group membership, and pushes you created; Cancel / Delete Account (destructive).
- Busy flag prevents double-submit while the RPC runs.
- Errors: recoverable inline banner or alert with Retry calling the same action again — not a full-screen profile failure.
- Mock: control absent (`isAvailable == false`).

### Session and cache

After successful deletion:

- Auth gate is the only entry (`.gate`).
- Live `AppDataContainer.shared` must not keep the deleted user’s warm snapshot for a later accidental install; follow the same teardown path as sign-out (if sign-out does not currently nil the container, document and align so a new sign-in always re-prepares).

## Testing

### Automated (required)

| Case | Layer |
|---|---|
| Successful deletion clears session path and returns to gate | Client unit (fake auth succeeds → Root/Profile routing) |
| Failed RPC leaves session / `.app` and surfaces error | Client unit |
| Control hidden when delete unavailable (mock) | Client unit / UI logic |
| `deleteAccount` not exposed as deleting another user | RPC has no id param; grant/revoke in migration review |
| Group transfer promotion order | SQL function logic reviewed; optional pure helper test if promotion extracted in Swift (unlikely — keep in SQL) |
| Friendship / membership cleanup | Covered by RPC sequence + FK cascade audit in implementation |
| Profile photo storage | Migration best-effort delete; mapping/tests if storage helper is testable |

Prefer fakes over live network in `PushTests`. Live smoke (optional, manual): create throwaway `@pushapp.dev` user → delete → sign-in fails → friends of another test user no longer see them after refresh.

### Manual / live smoke (acceptance)

- Confirm dialog required.
- After delete, relaunch → auth flow.
- Attempt sign-in with deleted credentials fails.
- Second test user no longer sees deleted user as friend after session refresh.

## Implementation outline

1. Migration `delete_account` + README note; apply via project Supabase workflow.
2. `AuthService.deleteAccount` + Fake.
3. `RootView` `DeleteAccountAction` + success/failure routing.
4. Profile confirmation UI + error/busy.
5. Focused tests; `scripts/test.sh build` + auth/profile-related suites.
6. Optional live smoke with throwaway Auth user.

## Open implementation details (non-blocking)

Resolve during implementation, not product debate:

- Exact Storage delete API available in Postgres vs client-side delete-before-RPC (prefer server-side in the same transaction as Auth delete when possible; if Storage cannot run inside the RPC transaction, document best-effort server delete and accept rare orphans).
- Whether push rows need explicit `DELETE` before Auth delete (verify all FKs cascade).
- Precise teardown of `AppDataContainer.shared` on sign-out/delete if not already symmetric.

## Acceptance criteria mapping

| Criterion | Design coverage |
|---|---|
| Initiate from app | Profile Delete Account (live) |
| Confirm destructive action | Confirmation dialog |
| Auth user cannot sign in | RPC deletes `auth.users` |
| Gone from friends/requests/groups/selectors | Friendship + membership cleanup + cascade |
| Profile photo removed | Storage best-effort + profile cascade |
| Others lose private deleted-user data | Profile and graph rows gone |
| Shared records consistent | Ownership transfer / empty group delete |
| Failure stays signed in + error | Root only gates after success |
| Relaunch → auth | Local session cleared |

## Out of scope (issue)

- Temporarily deactivating an account  
- Exporting account data  
- Restoring a deleted account  
- Deleting another user as an administrator  
