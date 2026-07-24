# Realtime Presence Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Spec: `docs/superpowers/specs/2026-07-24-realtime-presence-sync-design.md`.

**Goal:** Friend map/Friends surfaces update automatically when another user’s `current_presence` changes via Supabase Realtime, patching `LiveDataStore` with debounced revisions and reconcile-on-gap.

**Architecture:** Session-scoped `PresenceRealtimeBridge` subscribes to `postgres_changes` on `public.current_presence` after live install. Pure `PresenceRealtimeApplying` maps events → upsert/remove/reconcileHint. Store APIs apply remote patches without intermediate revisions; bridge debounces and publishes one revision. Self events ignored. Mock never starts. Reconnect / unusable payloads reconcile via `loadPresence()`.

**Tech Stack:** SwiftUI iOS 17+, supabase-swift Realtime (`AnyAction` / `postgresChange`), existing `LiveDataStore` + `CurrentPresenceRow`, XCTest doubles (no live project).

## Global Constraints

- Do **not** change `SupabasePresenceSync` / write path / throttle / Ghost own-write.
- `import Supabase` only in Supabase/auth/repo layer — bridge under `Push/Data/Supabase/`.
- Files ≤ 400 lines (put store remote helpers in `LiveDataStore+PresenceRealtime.swift` — main store is already ~824 lines).
- Functions ≤ 40 lines; named constants only (`LocationPipelineConstants.realtimePatchDebounce`).
- Never log coordinates, full payloads, tokens, or PII.
- Register new Swift files: `python3 scripts/pbxproj_add.py <path relative to Push/>`; tests with `--target tests`.
- Tests: `scripts/test.sh suite PresenceRealtimeTests` (and LivePresence* if store-touched).
- MVVM: no Realtime in Views/ViewModels.

## File map

| File | Responsibility |
|---|---|
| `supabase/migrations/0020_current_presence_realtime.sql` | Add table to `supabase_realtime` publication |
| `supabase/README.md` | Document migration |
| `Push/Data/Supabase/PresenceRealtimeApplying.swift` | Pure event → op mapping |
| `Push/Data/Supabase/LiveDataStore+PresenceRealtime.swift` | Remote apply/remove/reconcile/revision |
| `Push/Data/Supabase/PresenceRealtimeBridge.swift` | Protocol, fake source, live bridge, debounce |
| `Push/Data/AppDataContainer.swift` | Own bridge; start on install; stop on teardown |
| `PushTests/PresenceRealtimeTests.swift` | Applicator + store + bridge lifecycle tests |

---

### Task 1: Migration `0020_current_presence_realtime`

**Files:**
- Create: `supabase/migrations/0020_current_presence_realtime.sql`
- Modify: `supabase/README.md`

**Interfaces:**
- Produces: `public.current_presence` member of publication `supabase_realtime` (idempotent)

- [ ] **Step 1: Write migration**

```sql
-- 0020_current_presence_realtime.sql
-- Issue #84: enable postgres_changes for friend-visible presence updates.
-- RLS on current_presence still filters which rows each JWT receives.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'current_presence'
  ) then
    alter publication supabase_realtime add table public.current_presence;
  end if;
end $$;
```

- [ ] **Step 2: Document in `supabase/README.md`** under migrations list (after 0018/0019).

- [ ] **Step 3: Apply remotely via Supabase MCP `apply_migration`** when credentials available; if MCP unavailable, leave file for later apply and note in commit message.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0020_current_presence_realtime.sql supabase/README.md
git commit -m "db: publish current_presence for Realtime (Issue #84)"
```

---

### Task 2: Pure applicator + store remote APIs (TDD)

**Files:**
- Create: `Push/Data/Supabase/PresenceRealtimeApplying.swift`
- Create: `Push/Data/Supabase/LiveDataStore+PresenceRealtime.swift`
- Create: `PushTests/PresenceRealtimeTests.swift`
- Register both app files + test file in Xcode project

**Interfaces:**

```swift
enum PresenceRealtimeOp: Equatable {
    case upsert(CurrentPresenceRow)
    case remove(userID: String)
    case reconcileHint
}

enum PresenceRealtimeApplying {
    static func operation(
        from event: PresenceRealtimeWireEvent,
        currentUserID: String,
        now: Date = Date()
    ) -> PresenceRealtimeOp?
}

enum PresenceRealtimeWireEvent: Equatable {
    case insert(CurrentPresenceRow?)
    case update(new: CurrentPresenceRow?, oldUserID: String?)
    case delete(oldUserID: String?)
}

// LiveDataStore
func applyRemotePresenceRow(_ row: CurrentPresenceRow) -> Bool
func removeRemotePresence(userID: String) -> Bool
func reconcilePresence() async throws -> Bool
func publishPresenceRevision()
```

- [ ] **Step 1: Write failing tests** in `PresenceRealtimeTests.swift` covering:
  - insert friend → upsert op; self insert → nil
  - update published → upsert; update `is_published=false` → remove
  - delete with user id → remove; delete without id → reconcileHint
  - malformed insert (nil row) → nil / no-op
  - store: apply newer row replaces; stale `updated_at` returns false
  - store: remove returns true/false correctly
  - store: reconcile replaces from loader; returns true when changed; one revision only when `publishPresenceRevision` called
  - store: duplicate equal row returns false

Use `CurrentPresenceRow.fixture`, `LiveDataLoaderSpy`, `@MainActor`.

- [ ] **Step 2: Run suite — expect compile/link failures**

```bash
scripts/test.sh suite PresenceRealtimeTests
```

- [ ] **Step 3: Implement applicator**

Rules (from spec):
- Self `user_id` (case-insensitive) → return `nil` (ignore).
- INSERT: nil row → nil; not friend-visible → `.remove(userID)`; else `.upsert`.
- UPDATE: if new decodes and not self: invisible → `.remove`; visible → `.upsert`. If new nil and `oldUserID` known → `.remove`. If both unknown → `.reconcileHint`.
- DELETE: oldUserID → `.remove`; else `.reconcileHint`.
- Friend-visible: `is_published`, expires_at > now when present, not legacy effective ghost via mapped status when possible.

- [ ] **Step 4: Implement store extension**

- `applyRemotePresenceRow`: warm cache upsert with `updated_at` ordering via `PushDateFormatting.parse`; equal skip; nil cache → clear task, return true.
- `removeRemotePresence`: case-insensitive remove from warm cache.
- `reconcilePresence`: `loader.loadPresence().uniqued(by: \.user_id)`; replace; return whether changed.
- `publishPresenceRevision`: `revisionSubject.value += 1` — needs package-internal access; put extension in same module; if `revisionSubject` is private, add `package`/`internal` method on main class or make a fileprivate-friendly `func bumpRevision()` on `LiveDataStore` in the main file (one-liner).

- [ ] **Step 5: Register files + run tests — expect PASS**

```bash
python3 scripts/pbxproj_add.py Data/Supabase/PresenceRealtimeApplying.swift
python3 scripts/pbxproj_add.py Data/Supabase/LiveDataStore+PresenceRealtime.swift
python3 scripts/pbxproj_add.py ../PushTests/PresenceRealtimeTests.swift --target tests
scripts/test.sh suite PresenceRealtimeTests
```

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: remote presence apply APIs and Realtime event mapping (Issue #84)"
```

---

### Task 3: Bridge + debounce + fake event source

**Files:**
- Create/modify: `Push/Data/Supabase/PresenceRealtimeBridge.swift`
- Modify: `PushTests/PresenceRealtimeTests.swift`

**Interfaces:**

```swift
@MainActor
protocol PresenceRealtimeBridging: AnyObject {
    func start() async
    func stop()
    var isRunning: Bool { get }
}

@MainActor
protocol PresenceRealtimeEventSourcing: AnyObject {
    /// Yields wire events until cancelled. Production uses Supabase channel.
    func events() -> AsyncStream<PresenceRealtimeWireEvent>
    func connect() async throws
    func disconnect()
}

@MainActor
final class PresenceRealtimeBridge: PresenceRealtimeBridging {
    init(
        store: LiveDataStore,
        currentUserID: Person.ID,
        source: PresenceRealtimeEventSourcing,
        debounce: TimeInterval = LocationPipelineConstants.realtimePatchDebounce,
        now: @escaping () -> Date = { Date() }
    )
}

/// Test double: controllable stream + connect/disconnect counts.
@MainActor
final class FakePresenceRealtimeSource: PresenceRealtimeEventSourcing { … }
```

- [ ] **Step 1: Tests**
  - start connects source and sets isRunning; second start no-ops
  - stop disconnects; late events ignored
  - friend insert after start → cache updated + one revision after debounce (use short debounce 0.01 in tests)
  - self event ignored
  - stale update no revision
  - ghost update removes row
  - reconnect: connect called again / reconcile after start loads presence
  - generation: stop then yield → no mutation

- [ ] **Step 2: Implement bridge**
  - generation token
  - on start: connect, reconcile once (if reconcile returns true → publish revision), spawn listen task
  - map wire events via `PresenceRealtimeApplying`
  - buffer ops; debounce; apply; publish if material
  - coalesce reconcileHint to single in-flight reconcile
  - stop: cancel tasks, disconnect, increment generation

- [ ] **Step 3: Production source using Supabase** (same file or `SupabasePresenceRealtimeSource.swift` if length demands)

```swift
// Channel name constant
enum PresenceRealtimeConstants {
    static let channelName = "current-presence"
    static let tableName = "current_presence"
}
```

Use `client.channel(PresenceRealtimeConstants.channelName)`, `postgresChange(AnyAction.self, schema: "public", table: …)`, `subscribeWithError()`, map `AnyAction` → wire event by decoding `CurrentPresenceRow` via action `decodeRecord` / `decodeOldRecord` with a `JSONDecoder` that matches PostgREST shapes (string timestamps already on DTO).

- [ ] **Step 4: Run tests PASS + commit**

```bash
git commit -m "feat: PresenceRealtimeBridge with debounced store patches (Issue #84)"
```

---

### Task 4: AppDataContainer lifecycle wiring

**Files:**
- Modify: `Push/Data/AppDataContainer.swift`
- Modify: `PushTests/PresenceRealtimeTests.swift` (and/or `LiveContainerIsolationTests` / `LocationSessionContainerTests` if natural)

**Interfaces:**
- `private(set) var presenceRealtimeBridge: PresenceRealtimeBridging?`
- Live factory constructs `PresenceRealtimeBridge` when `SupabaseClient` available; loader-only `prepareLive` uses nil or injectable fake
- `installPreparedLive`: after assigning shared, `Task { await container.presenceRealtimeBridge?.start() }` (alongside location)
- `shutdownSharedAndReinstallMock` / `shutdownLocationSession` path: `presenceRealtimeBridge?.stop()`; nil out

**Notes:**
- `prepareLive(loader:)` tests have no client — inject optional bridge parameter on private `live(store:…)` for tests, default production source only when client exists.
- Pattern: add `presenceRealtimeBridge: PresenceRealtimeBridging? = nil` to private live init; `prepareLive(client:)` builds real bridge; `prepareLive(loader:)` leaves nil unless test injects via a test-only factory if needed.
- Simplest test path: unit-test bridge in isolation (Task 3); container test: mock container has `presenceRealtimeBridge == nil`; live container built with fake bridge records start on `installPreparedLive`.

- [ ] **Step 1: Wire start/stop**
- [ ] **Step 2: Tests for mock nil + install starts + shutdown stops**
- [ ] **Step 3: Run PresenceRealtimeTests + LivePresenceWriteTests + LivePresenceReadTests**
- [ ] **Step 4: Commit**

```bash
git commit -m "feat: start/stop Realtime presence bridge with live session (Issue #84)"
```

---

### Task 5: Docs + verification

**Files:**
- Modify: `tasks/todo.md` (progress)
- Optional: `agents.md` already auto-updated for design — ensure PR9 marked implemented only after code lands

- [ ] **Step 1:** `scripts/test.sh suite PresenceRealtimeTests`
- [ ] **Step 2:** `scripts/test.sh suite LivePresenceReadTests` and `LivePresenceWriteTests` (no regressions)
- [ ] **Step 3:** Apply migration via MCP if not done in Task 1
- [ ] **Step 4:** Final commit if doc-only leftovers

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Realtime subscribe `current_presence` | 1, 3 |
| Patch LiveDataStore | 2, 3 |
| One revision per logical mutation / debounce | 3 |
| Ghost optimistic remove + reconcile gap | 2, 3 |
| Self ignore | 2, 3 |
| Start live only / stop teardown | 4 |
| No mock subscribe | 4 |
| Generation / late callbacks | 3 |
| Reconnect reconcile | 3 |
| No write-path changes | (constraint) |
| No PII logging | 3 |
| Deterministic tests | 2–4 |

## Out of plan

- Manual two-account dogfood (human)
- Realtime for other tables
- Background location / inference
