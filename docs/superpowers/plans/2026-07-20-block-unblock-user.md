# Block and Unblock User Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users block and unblock other users with backend-enforced bidirectional restrictions, Friends-list Block entry, and a Profile Blocked list — without restoring friendship on unblock.

**Architecture:** Directed `public.user_blocks` + `private.is_blocked` + SECURITY DEFINER RPCs (`block_user`, `unblock_user`, `list_blocked_users`) guard friend request, search, group invite, and direct push-invite paths. App mirrors via `FriendRepository.blockUser` / `unblockUser` / `blockedUsers`, mock store teardown, live RPC + `notifyFriendshipsChanged`, Friends expand UI, and Profile Blocked list.

**Tech Stack:** SwiftUI, MVVM, supabase-swift RPCs, Postgres RLS/SECURITY DEFINER, XCTest via `scripts/test.sh`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-20-block-unblock-user-design.md`
- iOS 17+ SwiftUI; MVVM; no `import Supabase` in Views/ViewModels
- Files ≤ 400 lines; functions ≤ 40 lines; named constants only
- Register new Swift files: `python3 scripts/pbxproj_add.py <path-relative-to-Push/>` (`--target tests` for tests)
- Prefer scoped suites: `scripts/test.sh suite <Name>` / `scripts/test.sh build`
- User-facing: Push/Pushes; calm copy; `ActionErrorBanner` for mutation failures
- No Realtime; no auto-leave shared groups; no notify blocked user
- Block entry: Friends expand only; Blocked list: Profile card
- Soft-hide pending invites; do not hard-delete historical Push/group rows
- Supabase UUID strings: lowercase comparisons for live IDs

## File map

| File | Responsibility |
|------|----------------|
| `supabase/migrations/0016_user_blocks.sql` | Table, RLS, `is_blocked`, RPCs, guards on existing RPCs/policies |
| `supabase/README.md` | Document `0016` |
| `Push/Data/Domain/FriendRequest.swift` (or new `BlockedPerson.swift`) | `BlockedPerson` type |
| `Push/Data/Repositories/Repositories.swift` | `FriendRepository` block APIs |
| `Push/Data/Store/InMemoryDatabase.swift` | Block pairs + teardown + filters |
| `Push/Data/Repositories/LocalRepositories.swift` | Local friend/alert filtering |
| `Push/Data/Supabase/LiveDataStore.swift` | Loader methods + block/unblock + list |
| `Push/Data/Supabase/SupabaseLiveDataLoader.swift` | RPC client calls |
| `Push/Data/Supabase/SupabaseFriendRepository.swift` | Live repo methods |
| `Push/Data/Supabase/EmptyLiveRepositories.swift` / test spies | Protocol conformance stubs |
| `Push/ExpandableFriendRow.swift` | Block action + confirmation |
| `Push/FriendsView.swift` / `FriendsViewModel.swift` | Wire block + error/retry |
| `Push/BlockedUsersView.swift` / `BlockedUsersViewModel.swift` / style | Profile blocked list |
| `Push/ProfileView.swift` | Blocked card entry |
| `PushTests/BlockUserTests.swift` | Mock store + VM coverage |
| `PushTests/DataLayerTests.swift` | Update `ThrowingFriendRepository` |
| `PushTests/LiveDataStoreTests.swift` | Spy methods for block RPCs |
| `tasks/todo.md` / `tasks/spec.md` | Track progress + contract summary |

---

### Task 1: Migration `0016_user_blocks`

**Files:**
- Create: `supabase/migrations/0016_user_blocks.sql`
- Modify: `supabase/README.md`

**Interfaces:**
- Produces SQL:
  - `public.user_blocks (id, blocker_id, blocked_id, created_at)`
  - `private.is_blocked(a uuid, b uuid) returns boolean`
  - `public.block_user(target_user_id uuid) returns void`
  - `public.unblock_user(target_user_id uuid) returns void`
  - `public.list_blocked_users() returns table(id uuid, first_name text, handle text, image_asset_path text)`
  - Guards inside recreated `search_profiles`, `send_friend_request`, `resolve_friend_request`, `create_group`
  - `push_responses` INSERT policy excludes blocked `person_id` for creator-seeded pending rows
  - `resolve_group_invite`: reject when inviter (group owner) and invitee are blocked either way

- [ ] **Step 1: Author migration file**

Create `supabase/migrations/0016_user_blocks.sql` with:

```sql
-- 0016_user_blocks.sql
-- Directed blocks: blocker → blocked. Friendship pair row is deleted on block.
-- Bidirectional checks via private.is_blocked. Writes only via RPCs.

create table public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_blocks_not_self check (blocker_id <> blocked_id),
  constraint user_blocks_unique_pair unique (blocker_id, blocked_id)
);

create index user_blocks_blocker_created_idx
  on public.user_blocks (blocker_id, created_at desc);
create index user_blocks_blocked_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

create policy user_blocks_select_own on public.user_blocks
  for select using (blocker_id = (select auth.uid()));
-- no insert/update/delete policies — RPCs only

create or replace function private.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks ub
    where (ub.blocker_id = a and ub.blocked_id = b)
       or (ub.blocker_id = b and ub.blocked_id = a)
  );
$$;
revoke execute on function private.is_blocked(uuid, uuid) from public, anon;
grant execute on function private.is_blocked(uuid, uuid) to authenticated;

create or replace function public.block_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  low uuid;
  high uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if target_user_id is null or target_user_id = me then
    raise exception 'invalid target';
  end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'unknown user';
  end if;

  insert into public.user_blocks (blocker_id, blocked_id)
  values (me, target_user_id)
  on conflict (blocker_id, blocked_id) do nothing;

  if target_user_id < me then
    low := target_user_id; high := me;
  else
    low := me; high := target_user_id;
  end if;

  delete from public.friendships
  where user_low = low and user_high = high;
end;
$$;
revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

create or replace function public.unblock_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then raise exception 'not authenticated'; end if;
  if target_user_id is null or target_user_id = me then
    raise exception 'invalid target';
  end if;

  delete from public.user_blocks
  where blocker_id = me and blocked_id = target_user_id;
end;
$$;
revoke all on function public.unblock_user(uuid) from public, anon;
grant execute on function public.unblock_user(uuid) to authenticated;

create or replace function public.list_blocked_users()
returns table (
  id uuid,
  first_name text,
  handle text,
  image_asset_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.first_name, p.handle, p.image_asset_path
  from public.user_blocks ub
  join public.profiles p on p.id = ub.blocked_id
  where ub.blocker_id = (select auth.uid())
  order by ub.created_at desc;
$$;
revoke all on function public.list_blocked_users() from public, anon;
grant execute on function public.list_blocked_users() to authenticated;
```

Then in the **same file**, `create or replace` the existing functions from `0009` / `0011` with block guards. Pattern for each:

**`search_profiles`** — add to WHERE:

```sql
and not private.is_blocked((select auth.uid()), p.id)
```

**`send_friend_request`** — after unknown-user check:

```sql
if private.is_blocked(me, target_user_id) then
  raise exception 'blocked';
end if;
```

**`resolve_friend_request`** — after loading `existing`, before status flips:

```sql
if private.is_blocked(me, existing.user_low)
   or private.is_blocked(me, existing.user_high) then
  -- me is always one of the pair; is_blocked(me, other) is enough:
  null; -- prefer:
end if;
```

Use explicit other party:

```sql
if private.is_blocked(
     me,
     case when existing.user_low = me then existing.user_high else existing.user_low end
   ) then
  raise exception 'blocked';
end if;
```

**`create_group`** — inside invitee loop, after `is_friend` check:

```sql
if private.is_blocked(me, invitee) then
  raise exception 'invitee % is blocked', invitee;
end if;
```

**`resolve_group_invite`** — after loading membership, find active owner of that group; if `private.is_blocked(me, owner.person_id)` raise `blocked`.

**Push responses policy** — drop and recreate insert policy:

```sql
drop policy if exists push_responses_insert_self_or_creator on public.push_responses;
create policy push_responses_insert_self_or_creator on public.push_responses
  for insert with check (
    person_id = (select auth.uid())
    or (
      private.is_push_creator((select auth.uid()), push_id)
      and response = 'pending'
      and not private.is_blocked((select auth.uid()), person_id)
    )
  );
```

Copy full function bodies from `0009_friend_requests.sql` and `0011_group_invites.sql` when replacing — do not leave stubs. Keep UUID ordering and existing status logic intact; only add block checks.

- [ ] **Step 2: Document in README**

Add under Layout in `supabase/README.md`:

```markdown
- `migrations/0016_user_blocks.sql` — directed `user_blocks`, `private.is_blocked`,
  `block_user` / `unblock_user` / `list_blocked_users`; guards friend request, search,
  group invite, and creator-seeded push_responses; soft-hide policy (no hard-delete of
  historical pushes/groups). Shared group membership unchanged on block.
```

- [ ] **Step 3: Apply migration when Supabase MCP is available**

Use project Supabase skill / MCP `apply_migration` with name `user_blocks` and the SQL body. If MCP auth is unavailable, leave the file in-repo and note in the PR that apply is required before live QA.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0016_user_blocks.sql supabase/README.md
git commit -m "feat(db): user_blocks table and block RPCs (Issue #52)"
```

---

### Task 2: Domain + mock store + FriendRepository API

**Files:**
- Modify: `Push/Data/Domain/FriendRequest.swift` (add `BlockedPerson` at bottom) **or** Create: `Push/Data/Domain/BlockedPerson.swift` + pbxproj
- Modify: `Push/Data/Repositories/Repositories.swift`
- Modify: `Push/Data/Store/InMemoryDatabase.swift`
- Modify: `Push/Data/Repositories/LocalRepositories.swift`
- Modify: `PushTests/DataLayerTests.swift` (`ThrowingFriendRepository`)
- Create: `PushTests/BlockUserTests.swift` + register with pbxproj
- Any other `FriendRepository` stubs in tests (grep and update)

**Interfaces:**
- Produces:
  ```swift
  struct BlockedPerson: Identifiable, Equatable {
      let id: Person.ID
      let firstName: String
      let handle: String
      let imageAssetPath: String?
  }
  ```
  ```swift
  // FriendRepository
  func blockUser(_ personID: Person.ID) async throws
  func unblockUser(_ personID: Person.ID) async throws
  func blockedUsers() async throws -> [BlockedPerson]
  ```
- Store:
  ```swift
  // InMemoryDatabase
  private(set) var blockedUserIDs: Set<Person.ID>  // people *I* blocked
  func isBlocked(_ personID: Person.ID) -> Bool     // bidirectional if mock ever stores reverse; v1 only outbound from currentUser + optional reverse set if needed
  func blockUser(_ personID: Person.ID)
  func unblockUser(_ personID: Person.ID)
  func blockedPeople() -> [BlockedPerson]
  ```

Mock bidirectional: store `Set` of outbound blocks for current user. For “I am blocked by them” without a second account context, optional `inboundBlockedByIDs` is YAGNI unless tests need three-account reverse block — implement **directed rows** as:

```swift
struct UserBlock: Equatable {
    let blockerID: Person.ID
    let blockedID: Person.ID
}
private(set) var userBlocks: [UserBlock]
```

`isBlockedPair(_ a: Person.ID, _ b: Person.ID)` true if either direction exists.

- [ ] **Step 1: Write failing tests** in `PushTests/BlockUserTests.swift`

```swift
import XCTest
@testable import Push

@MainActor
final class BlockUserTests: XCTestCase {
    func testBlockRemovesFriendshipAndPendingRequests() async throws {
        let container = AppDataContainer(seed: .default)
        let friendID = try await container.friends.friends().first!.id

        // Ensure a pending request involving friend if seed has one, or create via another pair
        try await container.friends.blockUser(friendID)

        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.contains { $0.id == friendID })

        let blocked = try await container.friends.blockedUsers()
        XCTAssertTrue(blocked.contains { $0.id == friendID })

        // Cannot re-friend while blocked
        try await container.friends.sendFriendRequest(to: friendID)
        // send may no-op or leave no pending — assert relation not friends and request not pending
        let hits = try await container.friends.searchPeople(query: blocked.first!.firstName)
        XCTAssertFalse(hits.contains { $0.id == friendID })
    }

    func testUnblockDoesNotRestoreFriendship() async throws {
        let container = AppDataContainer(seed: .default)
        let friendID = try await container.friends.friends().first!.id
        try await container.friends.blockUser(friendID)
        try await container.friends.unblockUser(friendID)

        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.contains { $0.id == friendID })
        let blocked = try await container.friends.blockedUsers()
        XCTAssertFalse(blocked.contains { $0.id == friendID })

        // Re-request allowed
        try await container.friends.sendFriendRequest(to: friendID)
        let relation = container.database.relation(to: friendID)
        if case .outgoingPending = relation {
            // ok
        } else {
            XCTFail("expected outgoing pending after re-request, got \(relation)")
        }
    }

    func testBlockWithNoPriorRelationship() async throws {
        let container = AppDataContainer(seed: .default)
        // discoverable non-friend (seed has austin/jordan style discoverable people)
        let hits = try await container.friends.searchPeople(query: "austin")
        guard let target = hits.first(where: { $0.relation == .none }) else {
            throw XCTSkip("no discoverable non-friend in seed")
        }
        try await container.friends.blockUser(target.id)
        let after = try await container.friends.searchPeople(query: "austin")
        XCTAssertFalse(after.contains { $0.id == target.id })
    }

    func testIncomingFriendRequestSoftHiddenWhenBlocked() async throws {
        let container = AppDataContainer(seed: .default)
        // Find or seed an incoming pending request, block the requester, assert alerts empty for that id
        let requests = try await container.alerts.incomingFriendRequests()
        guard let request = requests.first else {
            throw XCTSkip("no incoming request in seed")
        }
        try await container.friends.blockUser(request.requester.id)
        let after = try await container.alerts.incomingFriendRequests()
        XCTAssertFalse(after.contains { $0.id == request.id })
    }
}
```

Adjust person IDs to real seed names after reading `SeedData` if `"austin"` differs.

- [ ] **Step 2: Run tests — expect compile/link failures**

```bash
scripts/test.sh suite BlockUserTests
```

Expected: fail (missing APIs / type).

- [ ] **Step 3: Implement domain + protocol + store + local repos**

1. Add `BlockedPerson` next to `PersonSearchResult` in `FriendRequest.swift` (keeps one small domain file) **or** new file + `python3 scripts/pbxproj_add.py Data/Domain/BlockedPerson.swift`.

2. Extend `FriendRepository` in `Repositories.swift`:

```swift
func blockUser(_ personID: Person.ID) async throws
func unblockUser(_ personID: Person.ID) async throws
func blockedUsers() async throws -> [BlockedPerson]
```

3. `InMemoryDatabase`:

```swift
private(set) var userBlocks: [UserBlock] = []

struct UserBlock: Equatable {
    let blockerID: Person.ID
    let blockedID: Person.ID
}

func isBlocked(_ a: Person.ID, _ b: Person.ID) -> Bool {
    userBlocks.contains {
        ($0.blockerID == a && $0.blockedID == b) || ($0.blockerID == b && $0.blockedID == a)
    }
}

func blockUser(_ personID: Person.ID) {
    guard personID != currentUserID else { return }
    if !userBlocks.contains(where: { $0.blockerID == currentUserID && $0.blockedID == personID }) {
        userBlocks.append(UserBlock(blockerID: currentUserID, blockedID: personID))
    }
    acceptedFriendIDs.remove(personID)
    friendRequests.removeAll { involvesPair(personID, request: $0) }
    didMutate()
}

func unblockUser(_ personID: Person.ID) {
    userBlocks.removeAll { $0.blockerID == currentUserID && $0.blockedID == personID }
    didMutate()
}

func blockedPeople() -> [BlockedPerson] {
    userBlocks
        .filter { $0.blockerID == currentUserID }
        .compactMap { block -> BlockedPerson? in
            guard let person = peopleByID[block.blockedID] else { return nil }
            return BlockedPerson(
                id: person.id,
                firstName: person.firstName,
                handle: handle(for: person.id),
                imageAssetPath: person.imageAssetPath
            )
        }
}
```

Make `involvesPair` usable from `blockUser` (already private — same type).

4. Guard `sendFriendRequest`:

```swift
guard !isBlocked(currentUserID, personID) else { return nil }
```

5. Guard `searchPeople` filter in `LocalFriendRepository`:

```swift
.filter { !database.isBlocked(database.currentUserID, $0.id) }
```

6. Guard `createGroup` invitees (skip or no-op blocked — mirror server by only inviting non-blocked; if Local always trusted, filter in repo).

7. `LocalFriendRepository`:

```swift
func blockUser(_ personID: Person.ID) async throws { database.blockUser(personID) }
func unblockUser(_ personID: Person.ID) async throws { database.unblockUser(personID) }
func blockedUsers() async throws -> [BlockedPerson] { database.blockedPeople() }
```

8. `LocalAlertRepository.incomingFriendRequests`:

```swift
database.friendRequests.filter {
    $0.status == .pending
        && $0.recipientID == database.currentUserID
        && !database.isBlocked(database.currentUserID, $0.requester.id)
}
```

Similarly filter `pendingGroupInvites` when `inviterID` is blocked.

9. `createPush` path: when building invitee person IDs, exclude blocked (in `LocalPushRepository` / resolver). If create already only uses friends, friendship removal is enough for friend tokens; still filter explicit person IDs.

10. Update all test fakes implementing `FriendRepository` with empty/throwing stubs for the three methods.

- [ ] **Step 4: Register test target and run**

```bash
python3 scripts/pbxproj_add.py --target tests BlockUserTests.swift
scripts/test.sh suite BlockUserTests
scripts/test.sh suite DataLayerTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Push/Data PushTests scripts 2>/dev/null; git add -u
git commit -m "feat: mock block/unblock on FriendRepository (Issue #52)"
```

---

### Task 3: Live loader + LiveDataStore + SupabaseFriendRepository

**Files:**
- Modify: `Push/Data/Supabase/LiveDataStore.swift` (`LiveDataLoading` protocol + store methods)
- Modify: `Push/Data/Supabase/SupabaseLiveDataLoader.swift`
- Modify: `Push/Data/Supabase/SupabaseFriendRepository.swift`
- Modify: `PushTests/LiveDataStoreTests.swift` (spy stubs)
- Grep for `LiveDataLoading` conformers / other spies

**Interfaces:**
- Produces on `LiveDataLoading`:
  ```swift
  func blockUser(targetUserID: String) async throws
  func unblockUser(targetUserID: String) async throws
  func listBlockedUsers() async throws -> [SearchProfileRow] // reuse search row shape if columns match
  ```
- Prefer reusing `SearchProfileRow` if it already has `id, first_name, handle, image_asset_path`; otherwise a thin `BlockedProfileRow` with same snake_case fields.
- Store:
  ```swift
  func blockUser(targetUserID: String) async throws {
      try await loader.blockUser(targetUserID: targetUserID)
      profileRows = nil
      profilesTask = nil
      notifyFriendshipsChanged()
  }
  // unblock: same invalidation (friendship not restored, but search/list must refresh)
  func listBlockedUsers() async throws -> [BlockedPerson] { ... map rows }
  ```

- [ ] **Step 1: Extend loader protocol + RPC params**

In `SupabaseLiveDataLoader.swift` (mirror `RemoveFriendParams`):

```swift
struct BlockUserParams: Encodable {
    let target_user_id: String
}

func blockUser(targetUserID: String) async throws {
    try await client
        .rpc("block_user", params: BlockUserParams(target_user_id: targetUserID))
        .execute()
}

func unblockUser(targetUserID: String) async throws {
    try await client
        .rpc("unblock_user", params: BlockUserParams(target_user_id: targetUserID))
        .execute()
}

func listBlockedUsers() async throws -> [SearchProfileRow] {
    try await client
        .rpc("list_blocked_users")
        .execute()
        .value
}
```

Confirm `SearchProfileRow` field names match RPC return columns; if not, add `BlockedProfileRow` in `Push/Data/Supabase/Rows/`.

- [ ] **Step 2: Wire store + friend repository**

```swift
// SupabaseFriendRepository
func blockUser(_ personID: Person.ID) async throws {
    try await store.blockUser(targetUserID: personID)
}
func unblockUser(_ personID: Person.ID) async throws {
    try await store.unblockUser(targetUserID: personID)
}
func blockedUsers() async throws -> [BlockedPerson] {
    try await store.listBlockedUsers()
}
```

- [ ] **Step 3: Update spies / EmptyLive repositories**

Any `LiveDataLoading` spy in `LiveDataStoreTests` gets no-op/throw stubs. If `EmptyLive*` friend repo exists, add methods.

- [ ] **Step 4: Build**

```bash
scripts/test.sh build
scripts/test.sh suite LiveDataStoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: live block/unblock RPCs via FriendRepository (Issue #52)"
```

---

### Task 4: Friends list Block UI + ViewModel

**Files:**
- Modify: `Push/ExpandableFriendRow.swift`
- Modify: `Push/FriendsView.swift`
- Modify: `Push/FriendsViewModel.swift`
- Extend: `PushTests/BlockUserTests.swift` (VM failure leaves row)

**Interfaces:**
- `ExpandableFriendRow`: add `isBlocking: Bool`, `onBlock: () -> Void`; confirmation dialog for Block
- `FriendsViewModel`:
  ```swift
  @Published private(set) var blockingFriendIDs: Set<String> = []
  private var pendingBlock: FriendRowModel?
  func blockFriend(_ row: FriendRowModel) async
  // retryLastAction: prefer last pending mutation (block or remove) — private enum Action { case remove; case block }
  ```

- [ ] **Step 1: ExpandableFriendRow — Block action**

Add a fourth action button is tight on small phones. Prefer **two destructive actions** in confirmation style:

**Option implemented:** Keep three main buttons; put **Block** as a second destructive path via long-press on Remove **or** replace layout with a 2×2 grid. Spec requires Block next to Remove.

Use a horizontal layout that wraps or slightly smaller labels:

```swift
// ExpandableFriendRowActionRow
let isBlocking: Bool
let onBlock: () -> Void

// Add button:
ExpandableFriendRowActionButton(
    label: "Block",
    symbolName: "hand.raised.fill",
    emphasis: .destructive,
    isLoading: isBlocking,
    action: onBlock
)
```

If four buttons overflow compact width, use:

```swift
// Two rows of HStack
// Row1: Directions | Start push
// Row2: Remove | Block
```

Confirmations:

```swift
.confirmationDialog("Block \(row.friend.name)?", isPresented: $isConfirmingBlock, titleVisibility: .visible) {
    Button("Block", role: .destructive, action: onBlock)
    Button("Cancel", role: .cancel) {}
} message: {
    Text("They won't be notified. You won't appear as friends.")
}
```

Wire `onBlock` from parent after confirm (dialog already confirms).

- [ ] **Step 2: FriendsViewModel.blockFriend**

Mirror `removeFriend`:

```swift
func blockFriend(_ row: FriendRowModel) async {
    guard blockingFriendIDs.insert(row.id).inserted else { return }
    defer { blockingFriendIDs.remove(row.id) }
    do {
        try await friends.blockUser(row.friend.id)
        lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        if expandedFriendID == row.id { expandedFriendID = nil }
        actionError = nil
        pendingBlock = nil
        await load()
    } catch {
        pendingBlock = row
        actionError = ActionErrorState(
            message: "Couldn't block \(row.friend.name). Try again."
        )
    }
}
```

Update `retryLastAction` to retry either pending remove or pending block (store last action kind).

Do **not** remove the row until success.

- [ ] **Step 3: FriendsView wiring**

```swift
ExpandableFriendRow(
    ...
    isBlocking: viewModel.blockingFriendIDs.contains(row.id),
    onBlock: { Task { await viewModel.blockFriend(row) } }
)
```

- [ ] **Step 4: VM unit test**

```swift
func testBlockFailureKeepsFriendAndSurfacesError() async {
    // Inject throwing FriendRepository wrapper that fails only blockUser
    // Assert rows still contain friend; actionError non-nil
}
```

- [ ] **Step 5: Run + commit**

```bash
scripts/test.sh suite BlockUserTests
scripts/test.sh build
git commit -am "feat: Friends list Block action with confirmation (Issue #52)"
```

---

### Task 5: Alerts soft-hide + invitation pickers

**Files:**
- Modify: `Push/Data/Repositories/LocalRepositories.swift` (if not fully done in Task 2)
- Modify: `Push/Data/Supabase/SupabaseAlertRepository.swift` — filter friend requests / group invites against blocked set when possible
- Modify: Start Push / Add Group friend candidate builders (search for where friend lists feed pickers)

**Live Alerts:** After block, friendship deleted → pending friendship rows gone server-side, so friend-request alerts disappear on refresh. Group invites from blocked inviter may still load — filter client-side:

```swift
// After loading invites, drop those whose inviterID is in blocked set
// Requires one listBlockedUsers() or is_blocked — expensive. Prefer:
// store.listBlockedUsers() cached briefly OR filter when inviter not visible
```

Pragmatic v1 for live:
- Friend requests: server deleted the friendship row on block → gone after reload (already via `notifyFriendshipsChanged`).
- Group invites: soft-hide if inviter is in `list_blocked_users` results (call when loading alerts if cheap) **or** rely on `resolve_group_invite` raise + action error.

Minimum for this task:

1. Mock: complete soft-hide (Task 2).
2. Live Alerts: after friendships changed, existing load path refreshes; add optional filter for group invites whose inviter is blocked if `blockedUsers()` is available without warm.

- [ ] **Step 1: Grep pickers**

```bash
rg -n "friends\(\)|acceptedFriend|invitee" Push/StartPush*.swift Push/AddGroup*.swift Push/Data/Derived
```

Ensure candidates come from `friends()` only (already true for Add Group). After block, friends list excludes target → pickers OK.

Start Push suggestion buckets from presence — blocked friend no longer in friends → excluded if builder uses friends().

- [ ] **Step 2: Tests for soft-hide** (if not in Task 2)

Assert group invite from blocked inviter not returned by local alerts.

- [ ] **Step 3: Commit**

```bash
git commit -am "fix: soft-hide blocked-pair alerts and pickers (Issue #52)"
```

---

### Task 6: Profile Blocked list UI

**Files:**
- Create: `Push/BlockedUsersViewModel.swift`
- Create: `Push/BlockedUsersView.swift`
- Create: `Push/BlockedUsersStyle.swift` (only if constants exceed inline Friends reuse)
- Modify: `Push/ProfileView.swift`
- Register pbxproj for new files
- Tests: unblock success/failure in `BlockUserTests`

**Interfaces:**
```swift
@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[BlockedPerson]> = .idle
    @Published private(set) var actionError: ActionErrorState?
    @Published private(set) var unblockingIDs: Set<Person.ID> = []

    init(friends: FriendRepository, container: AppDataContainer? = nil)
    func load() async
    func refresh() async  // refreshSession + load
    func unblock(_ person: BlockedPerson) async
    func retryLastAction() async
    func dismissActionError()
}
```

- [ ] **Step 1: ViewModel + tests**

```swift
func testUnblockRemovesFromList() async throws {
    let container = AppDataContainer(seed: .default)
    let friendID = try await container.friends.friends().first!.id
    try await container.friends.blockUser(friendID)
    let vm = BlockedUsersViewModel(friends: container.friends, container: container)
    await vm.load()
    guard case .loaded(let people) = vm.loadState else { return XCTFail() }
    XCTAssertTrue(people.contains { $0.id == friendID })
    let person = people.first { $0.id == friendID }!
    await vm.unblock(person)
    guard case .loaded(let after) = vm.loadState else { return XCTFail() }
    XCTAssertFalse(after.contains { $0.id == friendID })
}
```

- [ ] **Step 2: BlockedUsersView**

Cream full-screen list matching Friends/Alerts:

- Nav title “Blocked”
- Empty: “No blocked people.”
- Row: avatar (reuse profile avatar helper), name, `@handle`, Unblock button
- Confirmation: “Unblock \(name)?” / “You can send a friend request again later. Friendship is not restored automatically.”
- Host `ActionErrorBanner`
- `.refreshable { await viewModel.refresh() }`
- `.task { await viewModel.load() }`

- [ ] **Step 3: Profile card**

In `ProfileView.profileContent`, above Legal (or below Privacy):

```swift
NavigationLink {
    BlockedUsersView()
} label: {
    // GlassCard row: hand.raised, "Blocked", "Manage blocked people", chevron
}
```

Or `ProfileBlockedCard` private struct matching Legal card styling but internal navigation (not external Link).

Use existing `NavigationStack` if Profile already has one; if Profile is a sheet without stack, present `.sheet` / `fullScreenCover` via `@State showBlocked`.

Check `ProfileView` navigation context — prefer `NavigationLink` if inside `NavigationStack`, else cover.

- [ ] **Step 4: pbxproj + run**

```bash
python3 scripts/pbxproj_add.py BlockedUsersViewModel.swift
python3 scripts/pbxproj_add.py BlockedUsersView.swift
# style file if created
scripts/test.sh suite BlockUserTests
scripts/test.sh build
```

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: Profile Blocked list and unblock (Issue #52)"
```

---

### Task 7: Docs, task tracking, verification

**Files:**
- Modify: `tasks/todo.md` — Issue #52 checklist
- Modify: `tasks/spec.md` — short contract pointer to design doc
- Durable agent notes only if implementation landed (post-commit skill may update `agents.md`)

- [ ] **Step 1: Write `tasks/todo.md` section**

```markdown
# Issue #52 — Block / Unblock

- [x] Design + plan
- [x] Migration 0016
- [x] Mock store + FriendRepository
- [x] Live RPC path
- [x] Friends Block UI
- [x] Soft-hide / pickers
- [x] Profile Blocked list
- [ ] Apply migration on remote (if not done)
- [ ] Live smoke: block friend, search empty, unblock, re-request
```

- [ ] **Step 2: Full verification**

```bash
scripts/test.sh suite BlockUserTests
scripts/test.sh suite DataLayerTests
scripts/test.sh suite LiveDataStoreTests
scripts/test.sh suite AlertsTests
scripts/test.sh build
```

Before PR: `scripts/test.sh full` if cross-cutting (optional but preferred).

- [ ] **Step 3: Final commit if docs dirty**

```bash
git add tasks/todo.md tasks/spec.md
git commit -m "docs: Issue #52 block/unblock tracking and contract"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `user_blocks` + RLS | 1 |
| `private.is_blocked` bidirectional | 1 |
| `block_user` / `unblock_user` / `list_blocked_users` | 1 |
| Guards: friend request, resolve, search, create_group, push invite | 1 |
| Shared groups unchanged | 1 (no membership mutation) |
| Soft-hide pending invites | 2, 5 |
| `FriendRepository` APIs | 2 |
| Mock teardown + search filter | 2 |
| Live RPC + cache invalidation | 3 |
| Friends expand Block + confirm | 4 |
| ActionErrorBanner / no premature remove | 4 |
| Profile Blocked list + Unblock | 6 |
| Unblock ≠ restore friendship | 2 tests |
| Three-account / unrelated graph | extend tests in 2 if seed allows |
| Historical pushes preserved | 1 (no delete) |
| Docs / README | 1, 7 |

## Placeholder / consistency review

- Method names: `blockUser` / `unblockUser` / `blockedUsers` consistent across protocol, local, live.
- RPC names: `block_user` / `unblock_user` / `list_blocked_users`.
- Type: `BlockedPerson` (not `BlockedUser`) to avoid clashing with “user” auth types.
- No TBD steps remaining.
