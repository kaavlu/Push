# Complete Group Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live group lifecycle end-to-end — owner manage (rename, photo, invite, cancel, remove, transfer, delete), member leave, persisted group photos, backend-enforced permissions, session refresh + recoverable errors.

**Architecture:** New `SECURITY DEFINER` RPCs + `group-photos` Storage bucket (migration `0015`). `GroupRepository` gains mutation methods; live path goes `SupabaseGroupRepository` → `LiveDataStore` → `LiveDataLoading` RPCs, with `notifyGroupsChanged()` after every successful write. Group Detail becomes the management hub driven by `GroupsViewModel` (or a thin detail extension on it). Mock `InMemoryDatabase` mirrors RPC rules for unit tests.

**Tech Stack:** SwiftUI MVVM, supabase-swift, Postgres RLS/RPC, XCTest via `scripts/test.sh`, `python3 scripts/pbxproj_add.py`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-20-complete-group-lifecycle-design.md` (Issue #43)
- iOS 17+ SwiftUI; MVVM; no `import Supabase` in Views/ViewModels
- Files ≤ 400 lines; functions ≤ 40 lines; named constants only
- Register new Swift files with `python3 scripts/pbxproj_add.py <path>` (relative to `Push/`; `--target tests` for tests)
- Recoverable mutations: `ActionErrorState` + `ActionErrorBanner`
- Hard delete groups; `pushes.group_id` already `ON DELETE SET NULL`
- Do not rebuild Add Group steps or Alerts accept/deny — only extend photo on create and cancel-invite path
- Supabase MCP may need user auth to apply migrations; commit SQL even if apply is deferred
- Prefer focused suites: DataLayerTests, new GroupLifecycleTests, LiveDataStoreTests; `scripts/test.sh build` after cross-cutting edits

## File map

| File | Responsibility |
|------|----------------|
| `supabase/migrations/0015_group_lifecycle.sql` | `private.is_group_owner`, all lifecycle RPCs, `group-photos` bucket + storage policies |
| `Push/Data/Supabase/GroupPhotoStorage.swift` | `GroupPhotoStoring`, path helper, Supabase + mock-capable upload/delete |
| `Push/Data/Repositories/Repositories.swift` | Extend `GroupRepository` protocol |
| `Push/Data/Store/InMemoryDatabase.swift` | Mock mutations mirroring RPC rules + single `didMutate()` |
| `Push/Data/Repositories/LocalRepositories.swift` | `LocalGroupRepository` write methods + local photo files |
| `Push/Data/Supabase/LiveDataStore.swift` | Loader protocol methods + store wrappers + `notifyGroupsChanged` |
| `Push/Data/Supabase/SupabaseLiveDataLoader.swift` | PostgREST `.rpc` calls |
| `Push/Data/Supabase/SupabaseGroupRepository.swift` | Live repo: photo upload + RPCs |
| `Push/Data/AppDataContainer.swift` | Inject `GroupPhotoStoring` into group repo if needed |
| `Push/AddGroupViewModel.swift` | Create then `updateGroupPhoto` when image picked |
| `Push/GroupsModels.swift` | Member presentation: `membershipID`, `role` / `isOwner`; ViewModel mutations |
| `Push/Data/Derived/GroupContentBuilder.swift` | Pass membership id + role into `PushGroupMemberData` |
| `Push/GroupDetailView.swift` (+ small step/subviews if needed) | Owner/member management UI |
| `Push/FriendsView.swift` / `GroupsView.swift` | Wire ViewModel actions into detail |
| `PushTests/GroupLifecycleTests.swift` | Mock permission + lifecycle tests |
| `PushTests/GroupPhotoTests.swift` (or fold into GroupLifecycle) | Photo path + mock upload failure |
| `tasks/todo.md` | Progress checklist |

---

### Task 1: Migration — helpers, RPCs, group-photos storage

**Files:**
- Create: `supabase/migrations/0015_group_lifecycle.sql`
- Reference: `supabase/migrations/0011_group_invites.sql`, `0012_profile_photos.sql`, `0010_remove_friend.sql`

**Interfaces:**
- Consumes: `public.groups`, `public.group_memberships`, `private.is_friend`, `private.is_group_member`
- Produces: SQL functions listed below; bucket `group-photos`

- [ ] **Step 1: Author `0015_group_lifecycle.sql`**

Include, in order:

1. `private.is_group_owner(u uuid, g uuid)` — `security definer`, `search_path = ''`, exists active membership with `role = 'owner'`. Revoke from public/anon; grant authenticated if storage policies need it.

2. RPCs (each: `plpgsql`, `security definer`, `search_path = ''`, revoke public/anon, grant authenticated):

```sql
-- rename_group(p_group_id uuid, p_name text) returns public.groups
-- set_group_image(p_group_id uuid, p_image_path text) returns public.groups  -- null path clears
-- invite_to_group(p_group_id uuid, p_invitee_ids uuid[]) returns void
-- cancel_group_invite(p_membership_id uuid) returns void
-- remove_group_member(p_group_id uuid, p_person_id uuid) returns void
-- leave_group(p_group_id uuid) returns void
-- transfer_group_ownership(p_group_id uuid, p_new_owner_id uuid) returns void
-- delete_group(p_group_id uuid) returns void
```

**Behavioral requirements (must match tests in Task 3):**

- All: `auth.uid()` null → `'not authenticated'`.
- Owner-only ops: not owner → `'not owner'` (or equivalent stable message).
- `rename_group`: `trim`; empty → `'group name required'`.
- `set_group_image`: owner; set or clear `image_asset_path`.
- `invite_to_group`: owner; each id friend via `private.is_friend`; skip self; skip if active membership exists; skip if `invited` already exists; else insert `role=member`, `membership_status=invited`. Empty array ok (no-op).
- `cancel_group_invite`: membership must be `invited` and caller owner of that group; hard-delete.
- `remove_group_member`: target active, not owner, not self via this RPC (use leave for self); hard-delete.
- `leave_group`: must be active member. If `role=member`: hard-delete self. If `role=owner` and count(active)=1: `DELETE` group. If owner and other actives remain: raise `'transfer ownership first'`.
- `transfer_group_ownership`: target active member, not invited, not self; in one transaction set old owner role→`member`, new→`owner`.
- `delete_group`: owner; `DELETE FROM public.groups WHERE id = p_group_id` (cascades memberships; pushes SET NULL).

3. Storage bucket (mirror 0012 structure, own bucket):

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'group-photos',
  'group-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
```

Policies: folder name first segment = group id; owner-only via `private.is_group_owner((select auth.uid()), ((storage.foldername(name))[1])::uuid)` for insert/update/delete; select-own for upsert only (avoid public listing of all objects — same pattern/advisors as avatars).

- [ ] **Step 2: Apply migration when Supabase MCP/CLI is available**

Prefer project skill workflow (`apply_migration` / MCP). If auth fails, leave file committed and note in PR that migration must be applied.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0015_group_lifecycle.sql
git commit -m "feat(db): group lifecycle RPCs and group-photos storage (0015)"
```

---

### Task 2: Protocol + GroupPhoto storage seam

**Files:**
- Create: `Push/Data/Supabase/GroupPhotoStorage.swift`
- Modify: `Push/Data/Repositories/Repositories.swift`
- Register: `python3 scripts/pbxproj_add.py Data/Supabase/GroupPhotoStorage.swift`

**Interfaces:**
- Produces:

```swift
protocol GroupRepository {
    func groups() async throws -> [FriendGroup]
    func memberships() async throws -> [GroupMembership]
    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [Person.ID]) async throws -> FriendGroup.ID
    func renameGroup(groupID: FriendGroup.ID, name: String) async throws
    func updateGroupPhoto(groupID: FriendGroup.ID, jpegData: Data) async throws
    func removeGroupPhoto(groupID: FriendGroup.ID) async throws
    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) async throws
    func cancelGroupInvite(membershipID: GroupMembership.ID) async throws
    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) async throws
    func leaveGroup(groupID: FriendGroup.ID) async throws
    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) async throws
    func deleteGroup(groupID: FriendGroup.ID) async throws
}

struct GroupPhotoUploadResult: Equatable {
    let objectPath: String
    let publicURL: String
}

protocol GroupPhotoStoring: AnyObject {
    func upload(groupID: String, jpegData: Data) async throws -> GroupPhotoUploadResult
    func delete(objectPath: String) async throws
}

enum GroupPhotoStorageConfig {
    static let bucketID = "group-photos"
    static let contentType = "image/jpeg"
    static let cacheControlSeconds = "3600"
}

enum GroupPhotoPath {
    static func storageObjectPath(from imageAssetPath: String?) -> String?
}
```

`GroupPhotoPath` parses `/storage/v1/object/public/group-photos/` the same way `ProfilePhotoPath` does for avatars.

- [ ] **Step 1: Extend `GroupRepository` in `Repositories.swift`** with the methods above (stubs will not compile until Local/Supabase implement — implement both in Task 3–4 same PR sequence, or add empty `fatalError` only if splitting commits forces it; prefer Task 2 protocol + Task 3 local in one continuous flow).

- [ ] **Step 2: Implement `GroupPhotoStorage.swift`** mirroring `ProfilePhotoStorage.swift`:

```swift
// Key: "\(groupID.lowercased())/\(UUID().uuidString.lowercased()).jpg"
// bucket: GroupPhotoStorageConfig.bucketID
// upsert: false; new key every upload
```

- [ ] **Step 3: Register pbxproj + commit**

```bash
python3 scripts/pbxproj_add.py Data/Supabase/GroupPhotoStorage.swift
git add Push/Data/Supabase/GroupPhotoStorage.swift Push/Data/Repositories/Repositories.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: GroupRepository lifecycle APIs and GroupPhotoStoring"
```

---

### Task 3: InMemoryDatabase + LocalGroupRepository (TDD)

**Files:**
- Modify: `Push/Data/Store/InMemoryDatabase.swift`
- Modify: `Push/Data/Repositories/LocalRepositories.swift`
- Create: `PushTests/GroupLifecycleTests.swift`
- Register tests: `python3 scripts/pbxproj_add.py --target tests GroupLifecycleTests.swift`

**Interfaces:**
- Consumes: `GroupRepository` methods from Task 2
- Produces: mock behavior matching RPC rules; local photo via file store under group id

- [ ] **Step 1: Write failing tests** in `PushTests/GroupLifecycleTests.swift`

Use `AppDataContainer(seed:)` or direct `InMemoryDatabase` via container. Cover at minimum:

```swift
@MainActor
final class GroupLifecycleTests: XCTestCase {
    func testRenameGroupUpdatesName() async throws { ... }
    func testNonOwnerRenameThrowsOrNoopsPerMockContract() async throws { ... }
    // Prefer: Local throws same conceptual errors — use a small GroupRepositoryError enum
    // or NSError; document chosen contract in test comments.

    func testInviteThenCancelAllowsReinvite() async throws { ... }
    func testInviteSkipsActiveAndPendingDuplicates() async throws { ... }
    func testRemoveMemberDropsMembership() async throws { ... }
    func testMemberCanLeave() async throws { ... }
    func testOwnerLeaveWithOthersFails() async throws { ... }
    func testOwnerLeaveWhenSoleMemberDeletesGroup() async throws { ... }
    func testTransferOwnershipIsAtomic() async throws { ... }
    func testPendingCannotBecomeOwner() async throws { ... }
    func testDeleteGroupRemovesGroupAndMembershipsNullsPushGroupID() async throws { ... }
    func testUpdateAndRemoveGroupPhoto() async throws { ... }
    func testCreateGroupThenPhotoPersistsPath() async throws { ... }
}
```

For mock error policy: throw a dedicated error (add if missing):

```swift
enum GroupRepositoryError: Error, Equatable {
    case notAuthenticated
    case notOwner
    case notMember
    case invalidName
    case invalidTarget
    case transferRequired
    case notPending
}
```

Place in `Repositories.swift` or `GroupRepositoryError.swift` (register if new file).

- [ ] **Step 2: Run tests — expect fail**

```bash
scripts/test.sh suite GroupLifecycleTests
```

Expected: compile errors or failures (methods missing).

- [ ] **Step 3: Implement `InMemoryDatabase` mutations**

For each method: enforce owner/member rules; hard-delete memberships; on `deleteGroup` / sole-owner leave: remove group from `groupsByID`/`orderedGroups`, remove all memberships for that group, set `plansByID[...].groupID = nil` for matching plans (domain `PushPlan` is a struct — replace with copy `groupID: nil`). Call `didMutate()` **once** per public mutation.

Photo mock: write file via small helper (reuse or clone `ProfilePhotoFileStore` pattern with group folder) and set `FriendGroup.imageAssetPath`.

- [ ] **Step 4: Implement `LocalGroupRepository` methods** as thin `database.*` wrappers; photo methods process path like `LocalProfileRepository`.

- [ ] **Step 5: Run tests — expect pass**

```bash
scripts/test.sh suite GroupLifecycleTests
```

- [ ] **Step 6: Commit**

```bash
git add Push/Data/Store/InMemoryDatabase.swift Push/Data/Repositories/LocalRepositories.swift Push/Data/Repositories/Repositories.swift PushTests/GroupLifecycleTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: mock group lifecycle mutations and tests"
```

---

### Task 4: Live loader + store + SupabaseGroupRepository

**Files:**
- Modify: `Push/Data/Supabase/LiveDataStore.swift` (`LiveDataLoading` + store methods)
- Modify: `Push/Data/Supabase/SupabaseLiveDataLoader.swift`
- Modify: `Push/Data/Supabase/SupabaseGroupRepository.swift`
- Modify: `Push/Data/AppDataContainer.swift` (wire `GroupPhotoStoring`)
- Modify: fakes in `PushTests/LiveDataStoreTests.swift` that conform to `LiveDataLoading` — add stub methods that `XCTFail` or no-op throw
- Optional: `PushTests` spy updates

**Interfaces:**
- Extends `LiveDataLoading` with:

```swift
func renameGroup(groupID: String, name: String) async throws -> GroupRow
func setGroupImage(groupID: String, imagePath: String?) async throws -> GroupRow
func inviteToGroup(groupID: String, inviteeIDs: [String]) async throws
func cancelGroupInvite(membershipID: String) async throws
func removeGroupMember(groupID: String, personID: String) async throws
func leaveGroup(groupID: String) async throws
func transferGroupOwnership(groupID: String, newOwnerID: String) async throws
func deleteGroup(groupID: String) async throws
```

- `LiveDataStore` wrappers: call loader, then `notifyGroupsChanged()` on success (including photo path set after upload — repository orchestrates upload then `setGroupImage`).
- `SupabaseGroupRepository`:
  - Inject `store: LiveDataStore`, `photoStorage: GroupPhotoStoring?`, `currentUserID` only if needed for local path parse.
  - `updateGroupPhoto`: upload → `setGroupImage` with public URL → on set failure `delete` orphan → `notify` via store method.
  - `removeGroupPhoto`: `setGroupImage(nil)` then best-effort delete old object via `GroupPhotoPath`.
  - `deleteGroup`: RPC then best-effort storage cleanup if previous path known (optional: skip list-all; only delete known object path from cached group row before delete).

RPC parameter names must match SQL (`p_group_id` etc.) or use un-prefixed names consistently — **match the migration exactly**. Example:

```swift
struct RenameGroupParams: Encodable {
    let p_group_id: String
    let p_name: String
}
// client.rpc("rename_group", params: RenameGroupParams(...)).execute()
// Decode GroupRow when function returns public.groups
```

- [ ] **Step 1: Update `LiveDataLoading` + all test fakes** so the project compiles.

- [ ] **Step 2: Implement loader RPCs** in `SupabaseLiveDataLoader`.

- [ ] **Step 3: Implement store + repository photo orchestration**.

- [ ] **Step 4: Wire photo storage in `AppDataContainer.prepareLive` / live factory** next to profile photo storage:

```swift
// groups: SupabaseGroupRepository(store: store, photoStorage: GroupPhotoStorage(...))
```

- [ ] **Step 5: Build**

```bash
scripts/test.sh build
```

Expected: SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Push/Data/Supabase Push/Data/AppDataContainer.swift PushTests
git commit -m "feat: live group lifecycle RPCs and group photo upload"
```

---

### Task 5: Add Group — persist photo on create

**Files:**
- Modify: `Push/AddGroupViewModel.swift`
- Optionally keep `registerSessionImage` as optimistic display until reload shows HTTPS URL

**Interfaces:**
- Consumes: `createGroup`, `updateGroupPhoto`, `ProfilePhotoProcessor`

- [ ] **Step 1: Change `submit()`**

```swift
let groupID = try await container.groups.createGroup(
    name: trimmedName,
    imageAssetPath: nil,
    inviteeIDs: Array(selectedFriendIDs)
)
if let image = pickedImage,
   let jpeg = ProfilePhotoProcessor.jpegData(from: image) {
    do {
        try await container.groups.updateGroupPhoto(groupID: groupID, jpegData: jpeg)
    } catch {
        // Group exists; surface non-blocking error or attach ActionErrorState
        // Spec: failure must not show a saved photo that was not saved.
        // Prefer: return groupID still, set actionError for photo-only failure
        // so caller can dismiss flow but banner/retry photo is optional.
        // Minimum: log actionError "Group created, but photo didn't save."
        actionError = ActionErrorState(message: "Group created, but the photo didn't save.")
    }
}
return groupID
```

Decide: photo failure after create still returns `groupID` (flow completes) with banner — matches “group without photo is honest.”

- [ ] **Step 2: Session image** — still register for immediate UI; after `notifyGroupsChanged` reload, remote URL should replace when available.

- [ ] **Step 3: Focused test if easy** — extend GroupLifecycleTests create+photo path (already in Task 3).

- [ ] **Step 4: Commit**

```bash
git add Push/AddGroupViewModel.swift
git commit -m "feat: upload group photo after create_group"
```

---

### Task 6: Presentation model — membership id, owner flags

**Files:**
- Modify: `Push/GroupsModels.swift` (`PushGroupMemberData`, `PushGroupData` if needed)
- Modify: `Push/Data/Derived/GroupContentBuilder.swift`
- Modify: previews / tests that construct `PushGroupMemberData`

**Interfaces:**
- Produces:

```swift
struct PushGroupMemberData {
    // existing fields...
    let membershipID: String
    let isOwner: Bool
    let isPending: Bool
    // person id remains `id` for row identity OR use membershipID as id —
    // Prefer: id stays personID for stable friend rows; store membershipID separately
    // for cancel invite.
}
```

- `GroupsViewModel` exposes:

```swift
func isCurrentUserOwner(of groupID: String) -> Bool
func currentUserMembership(in groupID: String) -> GroupMembership?
func inviteCandidates(for groupID: String) -> [Person] // friends not active/pending
```

Load already has memberships — cache raw memberships or derive from builder inputs during `load()`.

- [ ] **Step 1: Extend builder** to set `membershipID`, `isOwner` from `GroupMembership.role == .owner`.

- [ ] **Step 2: Fix all call sites / previews**.

- [ ] **Step 3: Build + any GroupContentBuilder tests if present**.

- [ ] **Step 4: Commit**

```bash
git add Push/GroupsModels.swift Push/Data/Derived/GroupContentBuilder.swift
git commit -m "feat: group member presentation includes owner and membership id"
```

---

### Task 7: GroupsViewModel mutations + action errors

**Files:**
- Modify: `Push/GroupsModels.swift` (`GroupsViewModel`)
- Create if file would exceed 400 lines: `Push/GroupDetailViewModel.swift` — **prefer extending `GroupsViewModel` first**; split only if over limit

**Interfaces:**
- Produces methods (all set `actionError` on failure, clear on success; call repo; `load()` follows via store subscription):

```swift
@Published var actionError: ActionErrorState?
// private retry payload enum similar to FriendsViewModel / AlertsViewModel

func renameGroup(groupID: String, name: String) async
func updateGroupPhoto(groupID: String, jpegData: Data) async
func removeGroupPhoto(groupID: String) async
func inviteFriends(groupID: String, friendIDs: [String]) async
func cancelInvite(membershipID: String) async
func removeMember(groupID: String, personID: String) async
func leaveGroup(groupID: String) async  // on success closeDetail()
func transferOwnership(groupID: String, newOwnerID: String) async
func deleteGroup(groupID: String) async // on success closeDetail()
func retryActionError() async
func dismissActionError()
```

Optimistic rules:
- Rename: optional optimistic name on card; roll back on failure by awaiting load / restoring previous.
- Photo: optional local override in `sessionImages` only while in-flight; clear on failure; on success leave until remote path loads then clear override.
- Remove/leave/delete: do not remove from UI until success (or optimistic remove with rollback — prefer wait-for-success for membership changes).

- [ ] **Step 1: Port error/retry pattern from `FriendsViewModel.removeFriend` / `AlertsViewModel.resolve`.**

- [ ] **Step 2: Unit tests for one mutation failure** (fake throwing `GroupRepository`) if ViewModel is testable via container override — optional but preferred:

```swift
// GroupsViewModelTests or inside GroupLifecycleTests
func testRemoveMemberFailureSetsActionError() async { ... }
```

- [ ] **Step 3: Commit**

```bash
git add Push/GroupsModels.swift PushTests
git commit -m "feat: GroupsViewModel group lifecycle mutations and errors"
```

---

### Task 8: Group Detail UI

**Files:**
- Modify: `Push/GroupDetailView.swift`
- Possibly create: `Push/GroupDetailManageViews.swift` (invite sheet, transfer picker, confirm dialogs) if detail would exceed 400 lines
- Modify: `Push/FriendsView.swift`, `Push/GroupsView.swift` — pass callbacks / observe `actionError`
- Reuse: `GroupPhotoBadge`, PhotosPicker patterns from Profile / Add Group, `ActionErrorBanner`, cream Friends styling

**UI checklist:**

| Control | Visibility | Action |
|---------|------------|--------|
| Photo tap menu | Owner | PhotosPicker → process → `updateGroupPhoto`; Remove → `removeGroupPhoto` |
| Rename | Owner | TextField + save / pencil |
| Invite | Owner | Sheet multi-select from `inviteCandidates` |
| Pending row trailing | Owner | Cancel invite |
| Active member row trailing | Owner, not self | Remove member |
| Leave | Non-owner member | Confirmation → `leaveGroup` |
| Transfer | Owner, ≥1 other active | Confirmation + picker |
| Delete | Owner | Strong confirmation → `deleteGroup` |
| Start push | All members | existing |
| Ping group | All | still no-op |

Confirm copy examples:
- Delete: “Delete this group for everyone? Members lose access. Past pushes stay, but won’t link to this group.”
- Leave: “Leave this group? You can only rejoin if someone invites you again.”
- Transfer: “Make {name} the owner? You’ll become a regular member.”

- [ ] **Step 1: Refactor `GroupDetailView` to take a richer model or bindings** — avoid putting repo calls in the View. Pass:

```swift
struct GroupDetailView: View {
    let group: PushGroupData
    let members: [PushGroupMemberData]
    let isOwner: Bool
    let sessionImage: UIImage?
    let inviteCandidates: [Person] // or row models
    let actionError: ActionErrorState?
    // closures for each action + dismiss error + retry
}
```

- [ ] **Step 2: Wire from Friends/Groups containers.**

- [ ] **Step 3: Banner** above content or safe area bottom like other cream pages.

- [ ] **Step 4: Build + visual smoke in mock** (`scripts/run-ios-sim.sh -- --friends` if useful).

- [ ] **Step 5: Commit**

```bash
git add Push/GroupDetailView.swift Push/GroupDetailManageViews.swift Push/FriendsView.swift Push/GroupsView.swift
git commit -m "feat: Group Detail management UI for lifecycle actions"
```

---

### Task 9: Verification suite + docs

**Files:**
- Modify: `tasks/todo.md`, optionally `tasks/spec.md` contract pointer
- Do **not** bulk-edit AGENTS until after land (documentation-updater)

- [ ] **Step 1: Run focused tests**

```bash
scripts/test.sh suite GroupLifecycleTests
scripts/test.sh suite DataLayerTests
scripts/test.sh suite LiveDataStoreTests
scripts/test.sh build
```

Expected: all pass / SUCCEEDED.

- [ ] **Step 2: Before PR, full suite**

```bash
scripts/test.sh full
```

- [ ] **Step 3: Live smoke (when migration applied + two test accounts)**

Walk issue acceptance 1–16. Unauthorized mutations must error from backend.

- [ ] **Step 4: Update `tasks/todo.md` checkboxes for issue #43.**

- [ ] **Step 5: Commit docs progress**

```bash
git add tasks/todo.md
git commit -m "docs: track group lifecycle verification"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| rename / set image RPCs | 1, 3, 4, 7–8 |
| invite / cancel / re-invite | 1, 3, 4, 7–8 |
| remove member / leave / transfer / delete hard | 1, 3, 4, 7–8 |
| group-photos bucket + persist on create | 1, 2, 4, 5 |
| Owner cannot leave with others without transfer | 1, 3 |
| Pending cannot own | 1, 3 |
| Pushes survive delete (`group_id` null) | 1, 3 |
| Backend permissions | 1, 4 |
| notifyGroupsChanged / no relaunch | 4, 7 |
| ActionErrorBanner | 7–8 |
| Do not rebuild create/accept UX | 5 (photo only), 8 |
| Tests | 3, 4 fakes, 9 |
| Out of scope Realtime / soft archive | — (not planned) |

## Placeholder / consistency notes

- RPC param names: pick `p_group_id` style in Task 1 and reuse identically in Task 4.
- `GroupRepositoryError` introduced in Task 3; live maps PostgREST errors to user-facing strings in ViewModel (not raw SQL text required).
- `PushGroupMemberData.id` remains person id; `membershipID` is separate for cancel.
- Migration apply may be blocked without Supabase auth — SQL still ships in repo.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-complete-group-lifecycle.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — this session executes tasks with checkpoints  

Which approach?
