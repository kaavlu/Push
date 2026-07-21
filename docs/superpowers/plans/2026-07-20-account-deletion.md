# Account Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Spec: `docs/superpowers/specs/2026-07-20-account-deletion-design.md`.

**Goal:** Let a live signed-in user permanently delete their Push account from Profile via a secure `delete_account` RPC, then clear session and return to the auth gate.

**Architecture:** Parameterless `SECURITY DEFINER` Postgres RPC owns graph cleanup, group ownership transfer-then-delete, best-effort avatar removal, and `DELETE FROM auth.users`. Client calls it only through `AuthService.deleteAccount()`, owned by `RootView` via environment `DeleteAccountAction` (parallel to Sign Out). Profile shows confirmation + recoverable error; gate only after RPC success.

**Tech Stack:** SwiftUI, supabase-swift (RPC + Auth), Postgres migrations / RLS patterns from `0009`–`0012`.

## Global Constraints

- MVVM; only auth/repo layer imports Supabase — never Views.
- Live-only control (mock hides like Sign Out).
- Never sign out / enter `.gate` before RPC succeeds.
- RPC has **no** user-id parameter; only `auth.uid()`.
- Files ≤ 400 lines; functions ≤ 40 lines; named constants for layout.
- Register new Swift test files with `python3 scripts/pbxproj_add.py <path> --target tests`.
- Tests via `scripts/test.sh`; scoped suites, not full unless pre-commit.
- Group rule: promote earliest other **active** member (`joined_at`, then `person_id`); else delete group.

## File map

| File | Responsibility |
|---|---|
| `supabase/migrations/0014_delete_account.sql` | `public.delete_account()` RPC |
| `supabase/README.md` | Document migration + RPC |
| `Push/Data/Supabase/AuthService.swift` | `deleteAccount()`, messages, Fake |
| `Push/RootView.swift` | `DeleteAccountAction`, env, perform path |
| `Push/ProfileView.swift` | Button, confirm, busy, error banner |
| `Push/ProfileStyle.swift` | Spacing constants if needed |
| `PushTests/DeleteAccountTests.swift` | Fake + action availability + failure stays signed in |

---

### Task 1: Migration `0014_delete_account`

**Files:**
- Create: `supabase/migrations/0014_delete_account.sql`
- Modify: `supabase/README.md`

**Interfaces:**
- Produces: `public.delete_account()` → `void`, `SECURITY DEFINER`, execute for `authenticated` only

- [x] **Step 1: Write migration**

```sql
-- 0014_delete_account.sql
-- Permanent self-service account deletion (Issue #48).
-- No parameters: only auth.uid() may be deleted (prevents IDOR).
-- Order: storage best-effort → group ownership transfer/delete →
-- remaining memberships + friendships → auth.users (cascades profiles + FKs).

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  owned_group uuid;
  successor uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  -- Best-effort avatar cleanup. Storage API prefers non-SQL deletes; removing
  -- storage.objects rows is best-effort so Auth deletion still proceeds.
  begin
    delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = me::text;
  exception when others then
    null;
  end;

  for owned_group in
    select m.group_id
    from public.group_memberships m
    where m.person_id = me
      and m.role = 'owner'
      and m.membership_status = 'active'
  loop
    select om.person_id into successor
    from public.group_memberships om
    where om.group_id = owned_group
      and om.person_id <> me
      and om.membership_status = 'active'
    order by om.joined_at asc, om.person_id asc
    limit 1;

    if successor is not null then
      update public.group_memberships
      set role = 'owner'
      where group_id = owned_group and person_id = successor;
    else
      delete from public.groups where id = owned_group;
    end if;
  end loop;

  delete from public.group_memberships where person_id = me;

  delete from public.friendships
  where user_low = me or user_high = me;

  delete from auth.users where id = me;
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
```

- [ ] **Step 2: README bullet** under Layout for `0014_delete_account.sql`.

- [ ] **Step 3: Apply** via Supabase MCP `apply_migration` when authenticated; if MCP unavailable, leave file for later apply and note in commit.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0014_delete_account.sql supabase/README.md
git commit -m "feat(db): add delete_account RPC for issue #48"
```

---

### Task 2: AuthService.deleteAccount + Fake + tests

**Files:**
- Modify: `Push/Data/Supabase/AuthService.swift`
- Create: `PushTests/DeleteAccountTests.swift`
- Register tests: `python3 scripts/pbxproj_add.py DeleteAccountTests.swift --target tests` (path relative to tests folder as project expects)

**Interfaces:**
- Produces:
  - `AuthService.deleteAccount() async throws`
  - `AuthFailureContext.deleteAccount` (or dedicated message constant)
  - `AuthUserMessage.deleteFailed`
  - `FakeAuthService.deleteAccountResult: Result<Void, Error>?`
  - On success Fake clears `currentUser`; on success Supabase clears `currentUser` + best-effort `signOut`

- [ ] **Step 1: Failing tests** in `DeleteAccountTests.swift`

```swift
@MainActor
final class DeleteAccountTests: XCTestCase {
    func testFakeDeleteAccountSuccessClearsCurrentUser() async throws {
        let auth = FakeAuthService()
        auth.currentUser = AuthedUser(id: "u1", email: "a@push.test") // need writable or set via signIn
        // Prefer: signIn then deleteAccount
        _ = try await auth.signIn(email: "a@push.test", password: "x")
        try await auth.deleteAccount()
        XCTAssertNil(auth.currentUser)
    }

    func testFakeDeleteAccountFailureLeavesCurrentUser() async {
        let auth = FakeAuthService()
        _ = try? await auth.signIn(email: "a@push.test", password: "x")
        auth.deleteAccountResult = .failure(URLError(.notConnectedToInternet))
        do {
            try await auth.deleteAccount()
            XCTFail("expected throw")
        } catch {
            XCTAssertNotNil(auth.currentUser)
        }
    }

    func testDeleteAccountUserMessage() {
        XCTAssertFalse(AuthUserMessage.deleteFailed.isEmpty)
    }

    func testDeleteAccountActionUnavailableByDefault() {
        XCTAssertFalse(DeleteAccountAction().isAvailable)
    }

    func testDeleteAccountActionAvailableWhenHandlerSet() async throws {
        var called = false
        let action = DeleteAccountAction {
            called = true
        }
        XCTAssertTrue(action.isAvailable)
        try await action()
        XCTAssertTrue(called)
    }
}
```

Note: `FakeAuthService.currentUser` is `private(set)` — set via `signIn` / `restorable` + `restoreSession`. Adjust tests accordingly. `DeleteAccountAction` is added in Task 3; if Task 2 runs first, only Fake tests here and move action tests to Task 3 — **implement Tasks 2+3 together if preferred**.

- [ ] **Step 2: Protocol + Supabase + Fake**

```swift
// AuthService protocol
func deleteAccount() async throws

// AuthUserMessage
static let deleteFailed = "Couldn't delete your account. Check your connection and try again."

// SupabaseAuthService
func deleteAccount() async throws {
    try await client.rpc("delete_account").execute()
    currentUser = nil
    try? await client.auth.signOut()
}

// FakeAuthService
var deleteAccountResult: Result<Void, Error>?
func deleteAccount() async throws {
    switch deleteAccountResult ?? .success(()) {
    case .success:
        currentUser = nil
    case .failure(let e):
        throw e
    }
}
```

- [ ] **Step 3: Register + run tests**

```bash
python3 scripts/pbxproj_add.py DeleteAccountTests.swift --target tests
scripts/test.sh suite DeleteAccountTests
```

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(auth): deleteAccount service + Fake for issue #48"
```

---

### Task 3: RootView DeleteAccountAction

**Files:**
- Modify: `Push/RootView.swift`

**Interfaces:**
- Produces: `DeleteAccountAction` with `isAvailable`, `callAsFunction() async throws`
- Env key `\.deleteAccount`
- Live-only handler: RPC via `auth.deleteAccount()`, then `authModel.signOutReset()`, `enter(.gate)`
- Failure: rethrow; state stays `.app`

- [ ] **Step 1: Add action type** (mirror SignOutAction but throwing)

```swift
struct DeleteAccountAction {
    private let handler: (() async throws -> Void)?
    init(handler: (() async throws -> Void)? = nil) { self.handler = handler }
    var isAvailable: Bool { handler != nil }
    func callAsFunction() async throws {
        guard let handler else { return }
        try await handler()
    }
}
```

- [ ] **Step 2: Wire on `.app` content**

```swift
ContentView()
    .environment(\.signOut, signOutAction)
    .environment(\.deleteAccount, deleteAccountAction)
```

```swift
private var deleteAccountAction: DeleteAccountAction {
    guard mode == .live else { return DeleteAccountAction() }
    return DeleteAccountAction { try await performDeleteAccount() }
}

@MainActor
private func performDeleteAccount() async throws {
    try await auth.deleteAccount()
    authModel.signOutReset()
    enter(.gate)
}
```

- [ ] **Step 3: Build**

```bash
scripts/test.sh build
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: wire DeleteAccountAction from RootView"
```

---

### Task 4: Profile UI

**Files:**
- Modify: `Push/ProfileView.swift`
- Modify: `Push/ProfileStyle.swift` (padding between Sign Out and Delete Account)

**Interfaces:**
- Consumes: `@Environment(\.deleteAccount)`
- Shows button only if `deleteAccount.isAvailable`
- Confirmation dialog permanent-deletion copy
- Busy while in flight; `ActionErrorBanner` with Retry on failure
- Never dismiss profile optimistically

- [ ] **Step 1: State + UI**

```swift
@Environment(\.deleteAccount) private var deleteAccount
@State private var isDeleteAccountConfirmationPresented = false
@State private var isDeletingAccount = false
@State private var deleteAccountError: ActionErrorState?

// In profileContent after Sign Out:
if deleteAccount.isAvailable {
    DeleteAccountButton(isBusy: isDeletingAccount) {
        isDeleteAccountConfirmationPresented = true
    }
}
if let err = deleteAccountError {
    ActionErrorBanner(
        message: err.message,
        onRetry: { performDeleteAccount() },
        onDismiss: { deleteAccountError = nil }
    )
}

// confirmationDialog for delete
// performDeleteAccount: guard !isDeletingAccount; busy; try await deleteAccount(); on error set ActionErrorState(message: AuthUserMessage.deleteFailed)
```

Copy:
- Title: `Delete Account?`
- Message: `This permanently deletes your account, profile, friend connections, group membership, and pushes you created. This cannot be undone.`
- Destructive button: `Delete Account`

- [ ] **Step 2: Preview** inject `.environment(\.deleteAccount, DeleteAccountAction { })` optionally.

- [ ] **Step 3: Build + DeleteAccountTests**

```bash
scripts/test.sh suite DeleteAccountTests
scripts/test.sh build
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(profile): Delete Account confirmation and errors"
```

---

### Task 5: Docs + final verify

**Files:**
- Modify: `tasks/todo.md` (Issue #48 checklist)
- Spec status line can stay "approved" or note "implemented"

- [ ] **Step 1: Update todo.md** with completed tasks

- [ ] **Step 2: Final verification**

```bash
scripts/test.sh suite DeleteAccountTests
scripts/test.sh suite AuthBootstrapTests
scripts/test.sh build
```

Expected: all green

- [ ] **Step 3: Commit docs if needed**

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Parameterless RPC + Auth delete | 1 |
| Group transfer-then-delete | 1 |
| Avatar best-effort | 1 |
| Friendships / memberships cleanup | 1 |
| AuthService.deleteAccount | 2 |
| Fake + unit tests | 2 |
| RootView env action; gate only on success | 3 |
| Profile confirm + error | 4 |
| Live-only / mock hide | 3–4 |
| README | 1 |

## Out of scope in this plan

- Live MCP smoke against throwaway user (manual)
- Edge Functions
- Data export / restore
