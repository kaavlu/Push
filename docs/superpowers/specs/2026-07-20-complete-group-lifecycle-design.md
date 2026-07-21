# Complete Group Lifecycle Management and Photo Persistence

**Issue:** [#43](https://github.com/kaavlu/Push/issues/43)  
**Date:** 2026-07-20  
**Status:** Approved design

## Goal

Finish the live group lifecycle now that create + invite accept/deny exist (`0011`). Owners and members manage groups entirely from the app. Group photos persist via Storage and appear for all members after refresh. Do **not** rebuild create or invitation accept/deny flows — extend them.

## Decisions

| Topic | Choice |
|---|---|
| Mutation style | RPC-first `SECURITY DEFINER` functions (same pattern as `create_group` / `resolve_group_invite` / `remove_friend`) |
| Group deletion | **Hard delete** the `groups` row; memberships cascade; `pushes.group_id` becomes `NULL` via existing `ON DELETE SET NULL` |
| Photo storage | Public `group-photos` bucket; keys `{group_id}/{uuid}.jpg`; URL on `groups.image_asset_path` |
| Create + photo | Create group (usually `image_path` null) → upload → `set_group_image`; orphan upload deleted if path write fails |
| UI surface | **Group Detail** is the management hub (owner controls + member leave) |
| Errors | `ActionErrorState` + `ActionErrorBanner`; no incorrect optimistic end state |

## Current baseline

- Schema: `groups`, `group_memberships` (`role` owner/member, `membership_status` active/invited); no archive column.
- RPCs: `create_group`, `resolve_group_invite`, `incoming_group_invites` (`0011`).
- Client: `GroupRepository` has reads + `createGroup` only; Add Group intentionally does **not** upload photos (`imageAssetPath: nil` + session-only `UIImage`).
- Profile photos: `ProfilePhotoStoring` + public `avatars` bucket (`0012`) — mirror for groups.
- Pushes: `pushes.group_id` references `groups(id) ON DELETE SET NULL`.

## Backend

### Helpers

Add `private.is_group_owner(u uuid, g uuid)` — true when `u` has an **active** membership with `role = 'owner'` for `g`. Keep in `private` schema (not PostgREST-exposed). Revoke from `public`/`anon`; grant execute to `authenticated` only as needed by policies/RPCs.

### RPCs (migration `0013_group_lifecycle` or sequential next number)

| Function | Caller | Behavior |
|---|---|---|
| `rename_group(group_id, name)` | owner | Trim name; reject empty / unauthenticated / non-owner |
| `set_group_image(group_id, image_path)` | owner | Set `image_asset_path` or clear when `image_path` is null |
| `invite_to_group(group_id, invitee_ids)` | owner | Each invitee must be a friend of the owner; skip self; skip already-active members; if an `invited` row already exists, no-op for that person; otherwise insert `member` + `invited`. Hard-deleted prior rows (deny/cancel/leave/remove) allow a clean re-invite |
| `cancel_group_invite(membership_id)` | owner of that group | Target row must be `invited`; hard-delete so re-invite works |
| `remove_group_member(group_id, person_id)` | owner | Target must be active non-owner; hard-delete membership |
| `leave_group(group_id)` | active member | Non-owner: hard-delete own membership. Owner: allowed only if they are the **sole remaining active member** (then delete the whole group); otherwise raise — must transfer first |
| `transfer_group_ownership(group_id, new_owner_id)` | owner | Target must be **active** member (not invited, not self); single transaction: previous owner → `member`, new → `owner`. Never leave zero owners mid-transaction |
| `delete_group(group_id)` | owner | `DELETE` from `groups` (cascades memberships; pushes `group_id` set null). Storage cleanup is client best-effort after success |

All RPCs: `SECURITY DEFINER`, `set search_path = ''`, revoke from `public`/`anon`, grant `authenticated` only. Raise clear exceptions for auth, permission, and state errors (stale ownership, not pending, etc.).

Do **not** open broad INSERT/UPDATE/DELETE policies on `groups` / `group_memberships` for client table writes; keep management on RPCs like `0011`.

### Storage

- Bucket: `group-photos`, public, ~5 MiB, jpeg/png/webp.
- Object key: `{group_id}/{uuid}.jpg` (lowercased UUIDs).
- Policies: authenticated INSERT/UPDATE/DELETE (and SELECT-for-upsert as needed) only when `private.is_group_owner(auth.uid(), folder_group_id)`. Avoid listable public SELECT on all objects (same advisor concern as avatars).
- Public HTTPS URL stored on `groups.image_asset_path` for member display via existing loaders.

### Create-with-photo sequence (live)

1. `create_group(name, null, invitee_ids)` → group id.  
2. If user picked a photo: process JPEG → Storage upload under `{group_id}/…` → `set_group_image(group_id, public_url)`.  
3. If upload fails: group exists without photo (honest UI).  
4. If `set_group_image` fails after upload: delete orphan object; leave path null.  
5. Mock: persist path/local file analog without Storage.

Optional: keep `create_group`'s `image_path` parameter for callers that already have a final URL; primary app path is create-then-set.

## Client architecture

### `GroupRepository`

Extend protocol + `LocalGroupRepository` + `SupabaseGroupRepository` / `LiveDataStore`:

- `renameGroup(groupID:name:)`
- `updateGroupPhoto(groupID:jpegData:)`
- `removeGroupPhoto(groupID:)`
- `inviteToGroup(groupID:inviteeIDs:)`
- `cancelGroupInvite(membershipID:)`
- `removeMember(groupID:personID:)`
- `leaveGroup(groupID:)`
- `transferOwnership(groupID:newOwnerID:)`
- `deleteGroup(groupID:)`

Retain `createGroup(name:imageAssetPath:inviteeIDs:)`. Add Group live path: create, then `updateGroupPhoto` when `pickedImage` exists (drop session-only-only product rule).

### Photo seam

- `GroupPhotoStoring` mirroring `ProfilePhotoStoring` (upload/delete; public URL + object path).
- Reuse `ProfilePhotoProcessor` (or shared alias) for resize/compress.
- `AvatarImageLoader` already resolves HTTPS — group badges use the same path field.

### Session refresh

- Successful mutations call `LiveDataStore.notifyGroupsChanged()` (clear groups/memberships cache, bump revision).
- ViewModels already subscribe via `onStoreChange` / `lastSeenRevision`.
- After leave/delete/remove-self, Group Detail dismisses when the group is no longer in the list.
- No schema change for pushes; builders treat nil `groupID` as invitees-only / historical.

### Permissions in UI

- Derive `isOwner`, pending vs active from memberships for `currentUserID`.
- Hide owner-only controls from members; still rely on backend rejection for stale tokens or races.

## UI

### Group Detail (management hub)

**Owner**

- Tappable photo: add / replace / remove (PhotosPicker + confirm remove).
- Rename: inline edit or light editor; save via `renameGroup`.
- Invite friends: sheet of friends who are neither active nor pending for this group.
- Member rows: remove accepted member; cancel pending invite.
- Footer / overflow: Transfer ownership (picker of accepted members only), Delete group.

**Member (non-owner)**

- Read-only name and photo.
- Start push (existing).
- Leave group with confirmation.

**Shared**

- Pending section remains; owner can cancel.
- “Ping group” stays inert (out of scope).
- Cream Friends styling; reuse `ActionErrorBanner`.

### Confirmations

- Light: remove member, leave, cancel invite.
- Strong: delete group — explains all members lose access; cannot undo; historical pushes remain without the group link.
- Transfer: confirm new owner.

### Errors and optimistic UI

- `@Published actionError: ActionErrorState?` on the managing ViewModel (likely extend `GroupsViewModel` or a dedicated detail VM — prefer keeping Group Detail dumb and putting mutations on the ViewModel that already loads groups/memberships).
- Failed writes: banner + Retry when payload is retained; reload authoritative state; do not leave a photo URL that never saved.
- In-flight photo may show local override until success, then drop override once remote path is loaded.

## Invitation lifecycle (complete)

| Action | Result |
|---|---|
| Owner cancel | Hard-delete `invited` row; invitee Alerts no longer list it after refresh |
| Deny (existing) | Already hard-deletes |
| Re-invite | Insert new invited row; no duplicate active invited rows |
| Accepted members | Not invite candidates |
| Pending | Shown separately from accepted (existing Pending section) |

## Delete / leave / transfer edge cases

- Delete: hard-delete group; client best-effort removes Storage objects under that `group_id` prefix when known; failed storage cleanup does not roll back DB delete.
- Leave as sole owner (only active member): delete group (same as delete).
- Leave as owner with other active members: rejected until transfer.
- Transfer then leave: former owner becomes normal member, then may leave.
- Pending invitees cannot become owners.
- Friendships unchanged by leave/remove/delete.

## Testing

### Automated

- Local/mock: owner vs member permission outcomes; transfer atomicity; leave rules; cancel + re-invite; delete clears memberships; push rows keep history with nil group association in mock store.
- Photo: upload/replace/remove; failure does not stick a false remote path; path helper for Storage object key.
- ViewModel: action errors, retry, list/detail refresh after mutation.
- Mapping/RPC shapes as needed for new DTOs.

### Live acceptance (two accounts)

Matches issue criteria 1–16: create with photo → relaunch both see photo → rename → photo update/remove → invite/cancel/re-invite → remove member → leave → transfer → delete → unauthorized rejected → failed mutation UI consistency.

## Out of scope

- Rebuilding group creation or accept/deny flows.
- Presence-based group statistics.
- Realtime subscriptions beyond existing session refresh.
- Large groups, subgroups, public join links.
- Per-member location-sharing controls.
- Soft-archive / restore group.

## Implementation notes

- Spec-before-code already satisfied by this doc; plan next under `docs/superpowers/plans/`.
- Apply migrations via project Supabase workflow (MCP when authenticated); sequential file after `0012b`.
- Register new Swift files with `scripts/pbxproj_add.py`.
- Prefer focused test suites; `scripts/test.sh full` before PR.
- Update `AGENTS.md` / coding-standards durable bullets only after land, via documentation-updater norms.

## Success criteria

Issue #43 acceptance criteria (live, two accounts) plus focused automated coverage for permissions, transfer, leave/remove, invite cancel/re-invite, delete + push safety, photo failure recovery, and cache invalidation.
