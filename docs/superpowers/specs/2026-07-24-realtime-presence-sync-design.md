# Realtime Presence Synchronization (Issue #84)

**Date:** 2026-07-24  
**Issue:** [kaavlu/Push#84](https://github.com/kaavlu/Push/issues/84)  
**Status:** Approved design (ready for implementation plan)  
**Related:** [Location/presence architecture](./2026-07-23-location-presence-architecture-design.md) (PR9), migrations `0018_current_presence`, write path Issues #75/#76, read warm Issue #73

---

## Problem

Live presence **writes** (device → `current_presence` via `SupabasePresenceSync` / `LocationSession`) and **initial reads** (`LiveDataStore` warm + synthetic `Place`) are complete. Friend map pucks and Friends rows still only update when:

- the viewer foreground re-warms / pull-to-refreshes, or
- a local mutation bumps store revision.

There is no Realtime subscription on `current_presence`, so another friend’s moves, availability changes, and Ghost unpublish do not appear until a manual or lifecycle refresh.

---

## Goals / done when

- Subscribe to authorized `current_presence` changes through Supabase Realtime (`postgres_changes`).
- Handle inserts, updates, unpublishes, expiry-related removals, and deletes as supported by the schema.
- Patch the existing `LiveDataStore` presence cache — no parallel presence cache.
- Produce **one shared revision per logical remote mutation** (debounced under burst).
- Map and friend surfaces refresh via existing `onStoreChange` → `load()` without manual reload.
- Subscriptions start only for an authenticated **live** session; never in mock.
- Stop subscriptions on sign-out and container teardown; prevent duplicates and late-session callbacks.
- Reconnect and post-subscribe reconciliation correct missed / out-of-order events.
- Deterministic tests with mocked Realtime events (no live Supabase project required).
- Existing presence write path remains unchanged.

---

## Non-goals

- Rewriting `SupabasePresenceSync`, throttle, heartbeat, or Ghost **own-write** behavior.
- Core Location, permission UX, background location.
- Activity / venue / co-presence inference.
- Map redesign or push notifications.
- New privacy relationships or sharing-policy schema.
- Realtime for tables other than `current_presence`.
- Service-role or elevated Realtime credentials in the app.

---

## Product / design decisions

| Decision | Choice |
|---|---|
| Approach | **Patch + reconcile** (not invalidate-only, not pure patch-only) |
| Own presence events | **Ignore** on the bridge — self write-through already owns own row + revision |
| Ghost / unpublish when payload decodes as invisible | **Optimistic remove** that `user_id` from cache |
| Ghost / unpublish when payload is unusable (RLS filter gap) | **Reconcile** presence from canonical read (clear + `loadPresence`, replace cache) |
| Revision under burst | Debounce `LocationPipelineConstants.realtimePatchDebounce` (0.35s) → one revision |
| No material change | No revision (duplicate / stale / equal snapshot) |
| Malformed events | No cache mutation, no revision |
| Stale ordering | Compare `updated_at`; older remote rows must not overwrite newer cache |
| Mock mode | Bridge never starts |
| Security | Existing RLS only; no elevated keys; client still filters hard-expired / unpublished for non-self on read |
| Logging | Never log coordinates, full presence payloads, tokens, or PII |

---

## Architecture

```
Auth + prepareLive (warm LiveDataStore)
        ↓
installPreparedLive
        ↓
start PresenceRealtimeBridge (once per live session)
        ↓
Supabase channel → postgres_changes on public.current_presence
        ↓
Bridge (MainActor): decode → apply / remove / schedule reconcile
        ↓
LiveDataStore presence cache + debounced single revision
        ↓
onStoreChange → MapViewModel / FriendsViewModel / … load()
        → VisiblePresence → pucks / rows
```

### Why not a second pipeline into `ContentView`

ViewModels already subscribe via `AppDataContainer.onStoreChange` and reload when `revision != lastSeenRevision`. The bridge only needs to patch the store and bump revision — same family as `notifyPushesChanged()` / self write-through.

### Component ownership

| Component | Role |
|---|---|
| `PresenceRealtimeBridging` | Protocol: `start()` / `stop()` (and optional `isRunning` for tests) |
| `PresenceRealtimeBridge` | Live implementation: channel lifecycle, event loop, generation token, debounce, reconcile triggers |
| `PresenceRealtimeApplying` (pure helpers) | Map decoded events → cache ops; stale/duplicate/malformed rules unit-testable without SDK |
| `LiveDataStore` | Cache mutations + revision; expose remote apply / remove / reconcile APIs |
| `AppDataContainer` | Owns bridge lifetime: start after live install; stop on sign-out / teardown |
| Migration `0020_current_presence_realtime` | Add `current_presence` to `supabase_realtime` publication |

**Do not** put Realtime code in Views or application ViewModels. **Do not** import `Supabase` outside the auth/repo/Supabase layer (bridge lives under `Push/Data/Supabase/`).

---

## Backend: Realtime publication

`0018_current_presence` created the table + RLS but did **not** add it to the Realtime publication.

**Migration** (next free number after `0019`): e.g. `0020_current_presence_realtime.sql`

```sql
-- Idempotent: only add if not already a member of the publication.
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

**REPLICA IDENTITY:** default `DEFAULT` (primary key) is enough for DELETE/UPDATE identity via `user_id`. Full-row `oldRecord` for non-PK columns is not required for our remove path (we only need `user_id`).

**RLS + Realtime:** Supabase evaluates SELECT policies for the authenticated JWT on change delivery. Friend policy requires `is_published = true` and non-expired. Consequences:

1. Friend **INSERT/UPDATE** while published → usually delivered with new record.
2. Friend **Ghost / unpublish** (`is_published = false`) → may not deliver a usable new record to friends; may deliver nothing or only a filtered transition. Client uses **optimistic remove when decodeable**, else **reconcile**.
3. Blocked / non-friend users → events not delivered (mirror authorized read path).

No policy changes required for this issue unless dogfood proves Realtime cannot deliver published friend updates (then investigate publication / Realtime RLS config separately — out of initial scope).

---

## LiveDataStore extensions

Existing APIs (keep):

- `currentPresence()` — session cache + coalesced load
- `applyPresenceWriteThrough` / `applyPresenceUnpublish` — **own** write path only
- `notifyPresenceChanged()` — clear cache + one revision (external invalidate)

Add (exact names; keep ≤40-line functions):

### `applyRemotePresenceRow(_ row: CurrentPresenceRow) -> Bool`

- If presence snapshot is warm (`presenceRows != nil`):
  - Find by case-insensitive `user_id`.
  - If existing and remote `updated_at` is **older** than cached → return `false` (no change).
  - If equal content (same `updated_at` and equal material fields) → return `false`.
  - Else replace or append; clear `presenceTask`; return `true`.
- If snapshot never warm (`presenceRows == nil`): leave cache nil, clear `presenceTask`, return `true` so a following revision forces ViewModels to reload and `currentPresence()` refetches the full set.
- **Does not** bump revision itself. Returns a material-change flag; the bridge publishes revision once per debounced batch.

### `removeRemotePresence(userID: String) -> Bool`

- If warm cache contains the user (case-insensitive): remove and return `true`.
- If warm cache exists but user absent: return `false`.
- If cache is nil: return `false` and let the caller issue `reconcilePresence()` when identity-only removal is ambiguous; DELETE with a known `user_id` on a nil cache is a no-op for cache content (listeners already empty until warm).

### `reconcilePresence() async throws -> Bool`

- Reuse loader: `let rows = try await loader.loadPresence().uniqued(by: \.user_id)`.
- Replace `presenceRows` with rows; clear `presenceTask`.
- Return whether the new snapshot differs from the previous warm snapshot (`true` if previous was nil or content changed).
- Bridge bumps **one** revision only when the return is `true`.
- Failed reconcile: leave prior cache; return/throw without revision; log safe error code only.

### Revision publishing

Bridge-facing helper:

```text
func publishPresenceRevision()  // revisionSubject += 1
```

Batch path: apply N ops without intermediate revisions → single `publishPresenceRevision()` if any op returned material change.

Do **not** call full `notifyPresenceChanged()` on every event (that forces network on next read without applying the patch). Use it only if a design path needs “drop and re-fetch on next access” without an immediate load; reconcile path prefers explicit replace.

---

## PresenceRealtimeBridge

### Protocol

```swift
@MainActor
protocol PresenceRealtimeBridging: AnyObject {
    func start() async
    func stop()
    var isRunning: Bool { get }
}
```

### Construction

```text
PresenceRealtimeBridge(
  client: SupabaseClient,           // or narrow RealtimeClient seaming for tests
  store: LiveDataStore,
  currentUserID: Person.ID,
  debounce: TimeInterval = LocationPipelineConstants.realtimePatchDebounce
)
```

For unit tests, prefer injecting:

- a `PresenceRealtimeEventSource` protocol that yields an `AsyncStream<PresenceRealtimeEvent>` of app-owned events (insert/update/delete with decoded or raw JSON maps), and
- the store.

Production wires the source to `client.channel(...).postgresChange(AnyAction.self, schema: "public", table: "current_presence")`.

### Session generation

```text
private var generation: UInt = 0
```

- `start()`: if already running for this generation, no-op; else `stop()` internal cleanup, `generation += 1`, capture `gen`, subscribe, listen.
- Every callback / stream element: `guard gen == generation && isRunning else { return }`.
- `stop()`: `generation += 1` (or set not-running + increment), unsubscribe / remove channel, cancel debounce task, cancel listen task.

### Channel lifecycle

1. Create a single named channel (e.g. `"current-presence"`) per bridge instance.
2. Register `postgresChange` for `AnyAction` on `public.current_presence` (no client-side filter beyond RLS — friend graph is dynamic).
3. `subscribe()` and await status as supported by supabase-swift.
4. On successful subscribe: `await reconcilePresence()` once.
5. Process stream until cancelled.
6. On detected reconnect / re-subscribe (if the SDK surfaces status): reconcile again.
7. `stop()`: remove channel / unsubscribe; ignore further events.

Mock `AppDataContainer` never constructs a live bridge.

### Event → ops

App-owned enum (no Supabase types in pure applicator):

```text
enum PresenceRealtimeEvent {
  case upsert(CurrentPresenceRow)   // insert or update with decodeable new row
  case remove(userID: String)       // delete or decodeable unpublish
  case reconcileHint                // unusable payload / need canonical read
}
```

Mapping rules:

| Realtime action | Mapping |
|---|---|
| INSERT | Decode record → if self, drop; if malformed, drop; else if friend-invisible (`!is_published` or hard-expired), **remove** or ignore; else **upsert** |
| UPDATE | Decode new record if possible. Self → drop. Malformed → drop (or `reconcileHint` only if we know a `user_id` from oldRecord and visibility is ambiguous). If decodeable and not friend-visible → **remove**. If decodeable and visible → **upsert** with stale check. If cannot decode new record but `oldRecord.user_id` known → **remove** (optimistic) or `reconcileHint` when identity unknown → **reconcileHint** |
| DELETE | `user_id` from oldRecord → **remove**; missing id → **reconcileHint** |

**Friend-visible for remote apply** (bridge-side, before cache):

- `is_published == true`
- `expires_at` parseable and `> now` (when present)
- availability not legacy effective-ghost if that maps to unpublished (align with `PresenceStatus.isEffectivelyPublished` / row mapping)

Self rows: always ignore on bridge (own write-through + profile dual-write).

### Debounce

- On material op: append to pending buffer; restart debounce timer (`realtimePatchDebounce`).
- On fire: apply all buffered ops to store (order preserved); if any material → one `publishPresenceRevision()`.
- `reconcileHint` coalesces to a single in-flight `reconcilePresence()` (do not stack concurrent reconciles); successful reconcile that changes cache counts as the revision (do not double-bump with debounce if reconcile already published).

### Reconciliation triggers

1. After successful initial subscribe.
2. On reconnect / channel re-join when detectable.
3. When event mapping yields `reconcileHint`.
4. Not a second polling system — no timer-based presence poll beyond existing foreground `refreshSession` backstop.

---

## AppDataContainer / lifecycle wiring

| Moment | Behavior |
|---|---|
| Mock `init(seed:)` | `presenceRealtimeBridge = nil` |
| `prepareLive` / warm | Build container with bridge **not started** (or constructed but idle) |
| `installPreparedLive` | `shared.shutdown…` (existing) then `shared = container`; start location session; **`await bridge?.start()`** (or Task like location) |
| `shutdownSharedAndReinstallMock` | **`bridge?.stop()`** before or with location teardown; then replace shared with mock |
| Mid-session `installPreparedLive` (same user reinstall) | Old shared stops location (existing); new container starts new bridge — old bridge deallocated / stopped so no duplicate channels |
| Late events | Generation guard |

Prefer holding the bridge on the live container:

```text
private(set) var presenceRealtimeBridge: PresenceRealtimeBridging?
```

Tests inject a `FakePresenceRealtimeBridge` that records start/stop.

**Sign-out order** (extend existing teardown):

1. Best-effort unpublish (existing).
2. Stop location session (existing).
3. **Stop Realtime bridge.**
4. Reinstall mock shared.

Stopping bridge before mock reinstall prevents late events mutating a dying store.

---

## Interaction with own writes

| Path | Revision source |
|---|---|
| Own upsert / unpublish via `SupabasePresenceSync` | `applyPresenceWriteThrough` / `applyPresenceUnpublish` (existing) |
| Friend remote change | Bridge → remote apply/remove + debounced revision |
| Own row echoed on Realtime | Bridge ignores self `user_id` |

No change to movement throttle, heartbeat, Ghost toggle, or dual-write availability.

---

## Security & privacy

- Channel uses the same authenticated `SupabaseClient` as the rest of the app.
- RLS policies on `current_presence` remain the server authority; bridge never “trusts” a row into friend-visible UI without existing repository mapping filters (`friendVisibleStatuses`, `VisiblePresenceBuilder`).
- Cache may briefly hold a row that later fails friend-visible filters; presentation layer still drops hard-expired / unpublished non-self.
- Logging: `PushLog` categories only; `PushLog.safeDescription(for:)` on errors — never `.localizedDescription` of payload errors that might embed data; never lat/lng.

---

## Testing strategy

**Suite:** new `PresenceRealtimeTests` (or `PresenceRealtimeBridgeTests`) via `scripts/test.sh suite PresenceRealtimeTests`.  
**No** live project, no device GPS, no UI tests.

| Case | Expectation |
|---|---|
| Mock container | Bridge not started / nil |
| Live install | `start()` called once |
| Insert friend row | Cache gains row; revision +1 (after debounce) |
| Update coords / availability / freshness / publish | Cache patched; material revision |
| Ghost / unpublish decodeable | Row removed from friend cache path |
| Delete | Row removed |
| Duplicate event | No second logical revision |
| Stale `updated_at` | Cache unchanged; no revision |
| Malformed | No mutation |
| Self event | Ignored |
| Sign-out / stop | `stop()`; further events ignored |
| Late callback after stop | Ignored (generation) |
| Re-auth / reinstall | One replacement start after stop |
| Reconnect / reconcileHint | Canonical load replaces cache; one revision if changed |
| RLS framing | Only rows that would pass authorized read mapping affect friend-visible domain after repo filters |

Pure applicator tests can run without constructing `SupabaseClient`. Store apply/remove tests extend patterns from `LivePresenceReadTests` / `LivePresenceWriteTests`.

---

## Manual validation (two live accounts)

1. Alice and Bob signed in (separate clients/sims), friendship visible.
2. Alice sees Bob on map when published.
3. Bob changes availability → Alice updates without pull-to-refresh.
4. Bob moves / sim location → Alice’s Bob puck updates.
5. Bob enables Ghost → Alice loses Bob’s friend-visible location without refresh.
6. Bob disables Ghost / republishes → Bob returns on Alice’s map.
7. Alice signs out → no further Realtime mutations of her local state.
8. Alice signs back in → single active subscription; presence correct after reconcile.

---

## File / size plan

| File | Notes |
|---|---|
| `supabase/migrations/0020_current_presence_realtime.sql` | Publication membership |
| `Push/Data/Supabase/PresenceRealtimeBridge.swift` | Bridge + protocol + production source |
| `Push/Data/Supabase/PresenceRealtimeApplying.swift` | Pure event → op mapping (keep under 400 lines total split) |
| `Push/Data/Supabase/LiveDataStore.swift` | Remote apply / remove / reconcile / revision helper |
| `Push/Data/AppDataContainer.swift` | Own bridge; start/stop wiring |
| `PushTests/PresenceRealtimeTests.swift` | Deterministic suite |
| Register via `python3 scripts/pbxproj_add.py` | App + `--target tests` |

Constants: reuse `LocationPipelineConstants.realtimePatchDebounce` — no new magic numbers.

---

## Acceptance criteria (checklist)

- [ ] Friend presence changes appear without manual refresh.
- [ ] Realtime events patch existing `LiveDataStore`.
- [ ] One revision per logical remote mutation (debounced under burst).
- [ ] Ghost, unpublish, delete, and expiry remove friend-visible presence (optimistic remove and/or reconcile).
- [ ] Availability and coordinate updates propagate automatically.
- [ ] Subscriptions start/stop with authenticated live session; none in mock.
- [ ] Duplicate subscriptions and late-session callbacks prevented.
- [ ] Reconnect / post-subscribe reconcile against canonical Supabase state.
- [ ] Existing RLS and visibility rules remain enforced.
- [ ] No raw coordinates or sensitive payloads logged.
- [ ] Existing presence write path unchanged.
- [ ] Tests pass without a live Supabase project.

---

## Implementation order (preview)

1. Migration: add `current_presence` to Realtime publication.
2. Pure applicator + store remote apply/remove/reconcile + unit tests.
3. Bridge + fake event source + lifecycle tests.
4. Container wiring (install / teardown).
5. Scoped `scripts/test.sh suite PresenceRealtimeTests` (+ LivePresence* if store touched).
6. Manual two-account dogfood when convenient.

Detailed task breakdown lives in the follow-up implementation plan after this spec is accepted as written.

---

## Locked implementation notes

- Reconnect detection: if supabase-swift does not expose a clean re-join callback, **reconcile on every successful `subscribe` completion** (including re-joins). That satisfies reconnect reconciliation without a custom poller.
- Friend availability chips on map/Friends use presence-derived `PresenceStatus` / `VisiblePresence`, not a separate profile-availability Realtime path. No profile-cache invalidation in this issue.
- No remaining open product questions.
