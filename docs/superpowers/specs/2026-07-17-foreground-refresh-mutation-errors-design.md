# Foreground Refresh & Reliable Mutation Errors (Issue #33)

## Goal

Improve live-mode freshness and make failed backend writes visible and recoverable.

Cross-device changes should appear after foregrounding or pull-to-refresh. Offline or failed mutations must fail visibly, roll back optimistic UI where applicable, and recover correctly on retry.

## Non-goals

- Realtime / Supabase subscriptions
- Map pull-to-refresh (map still reloads via store revision after re-warm)
- Profile basics/privacy/availability mutation polish
- Start Push create/edit mutation polish (unless shared types force a thin touch)
- Ghost Mode, push notifications, real GPS

## Decisions

| Topic | Choice |
|-------|--------|
| Architecture | Session-level re-warm on `AppDataContainer` / `LiveDataStore`, plus per-ViewModel action errors |
| Foreground | Full session snapshot re-warm (live only), debounced ~2s, skip first `.active` after launch |
| Pull-to-refresh | Friends, Alerts, Groups, Pushes |
| Mutation UX | Inline banner (message + Retry + dismiss), not system alerts |
| Optimistic failure | Rollback UI + banner + retry last action |
| Mutation coverage | Push RSVP, cancel, delete; friend remove; group create; friend-request and group-invite accept/deny |

---

## 1. Session refresh architecture

### Entry point

```text
AppDataContainer.refreshSession() async throws
```

**Live:** delegate to `LiveDataStore.refresh()` (name may match implementation).

**Mock:** no-op success (no network, no revision bump). Pull-to-refresh still completes.

### Live refresh algorithm

1. **Coalesce:** concurrent callers share one in-flight task.
2. **Debounce:** after a successful warm/refresh, ignore a new *scheduled* refresh for `SessionRefresh.minimumInterval` (~2 seconds), so rapid scene churn does not thrash. Callers already awaiting an in-flight task still complete with that result.
3. Clear all session caches and in-flight load tasks: profiles, groups, memberships, policies, pushes, responses (and any cache keyed off those tables).
4. Call existing `warm()` (concurrent loads, existing per-table coalescing).
5. **Success:** publish exactly **one** revision bump so subscribed ViewModels reload.
6. **Failure:** leave prior cache intact; do **not** bump revision.

### Foreground trigger

- Observe `scenePhase` on the live app shell (`ContentView` or `RootView` when presenting `.app`).
- When returning to `.active` after `.background` / `.inactive`, call `refreshSession()`.
- Live only.
- Skip the initial `.active` that accompanies first paint after bootstrap (preparation already warms). Track `hasEnteredBackground` (or equivalent) so only true returns-to-foreground refresh.

### Pull-to-refresh surfaces

| Screen | Behavior |
|--------|----------|
| Friends | `.refreshable` → ViewModel refresh |
| Alerts | same |
| Groups (list / Groups mode) | same |
| Pushes (`PlansView`) | same |

Recommended ViewModel helper:

```text
func refresh() async {
  try? await container.refreshSession()  // or catch → light refresh error
  await load()
}
```

Foreground path only calls `refreshSession()`; screens update via existing `onStoreChange` → `load()`.

### Keep content while refreshing

- If `loadState` already has a value, do **not** force a blank exclusive loading state.
- Alerts today sets `loadState = .loading` unconditionally — change to soft load (match Friends/Plans: only `.loading` when there is no prior value).
- On refresh failure with prior content: keep content; optional light “Couldn’t refresh” message.
- Foreground re-warm failure: **silent**; keep existing snapshot.

### Constants

- `SessionRefresh.minimumInterval` — ~2 seconds between successful refreshes (named constant, no magic numbers).

---

## 2. Mutation reliability

### Problem

Important writes use optimistic UI with silent failure (`try?`) or wipe the whole screen on action failure (`loadState = .failed`).

### Covered mutations

| Mutation | Surface | Optimistic? | On failure |
|----------|---------|-------------|------------|
| `setCurrentUserResponse` (RSVP) | Pushes / review | Yes — status pill | Restore pill; banner + retry |
| `cancelPush` | Pushes | Yes — remove card | Re-insert card; banner + retry |
| `deletePush` | Pushes | Yes — remove card | Re-insert card; banner + retry |
| `removeFriend` | Friends | No list remove until success (current) | Banner + retry; list unchanged |
| `createGroup` | Add Group flow | No | Keep form; banner + retry |
| Accept/deny friend request | Alerts | Chrome only after success | Keep row; banner + retry (not full-screen fail) |
| Accept/deny group invite | Alerts | Chrome only after success | Keep row; banner + retry |

### Shared presentation model

```text
ActionErrorState {
  message: String
}
```

ViewModels expose:

- `@Published var actionError: ActionErrorState?` (or map existing `errorMessage` / `removeErrorMessage` to the same banner component)
- `dismissActionError()`
- `retryLastAction() async` driven by a private `PendingMutation` (or equivalent) snapshot of the last failed action

**UI:** shared `ActionErrorBanner` — non-blocking inline banner: message, **Retry**, dismiss. Cream-page friendly; not a system alert.

### Optimistic write protocol

1. Snapshot the UI slice that will change.
2. Apply optimistic update (where product already expects instant feedback).
3. `await` the repository write (no `try?` on covered paths).
4. **Success:** clear action error; stamp `lastSeenRevision` / rely on store revision.
5. **Failure:** rollback to snapshot; set `actionError`; store retry payload.
6. **Retry:** re-run the same mutation from the recovered state.

### Alerts action failure

- Do **not** set `loadState = .failed` when accept/deny fails and the list already has content.
- Clear resolving chrome for that id; show banner; allow retry.

### Copy (calm, recoverable)

- “Couldn't update your response. Try again.”
- “Couldn't cancel this Push. Try again.”
- “Couldn't delete this Push. Try again.”
- Friend remove / group create keep existing voice, routed through the shared banner.

### Live store write contract (unchanged)

- Successful writes invalidate the right caches and bump revision once.
- Failed writes must not corrupt session cache or bump revision.
- Verify group create invalidates groups/memberships and bumps revision so lists update without restart.

---

## 3. Components & wiring

### Data flow

```text
scenePhase (.active after background) ──┐
                                        ├──► AppDataContainer.refreshSession()
.pull-to-refresh ───────────────────────┘              │
                                                       ▼ live
                                              LiveDataStore.refresh()
                                                coalesce + debounce
                                                clear caches + warm()
                                                one revision on success
                                                       │
                                                       ▼
                                              onStoreChange → VM load()
                                              (last content kept visible)

User mutation → ViewModel snapshot → optimistic? → await repo
                  success: clear error
                  failure: rollback + actionError + pending retry
```

### Implementation sketch (files)

| Piece | Role |
|-------|------|
| `LiveDataStore` | `refresh()`: invalidate all warm state, `warm()`, one revision |
| `AppDataContainer` | `refreshSession()` live vs mock |
| Small refresh helper (optional) | Debounce + skip-first-active; may live on container or app shell |
| `ActionErrorState` + `ActionErrorBanner` | Shared error presentation |
| `PlansViewModel` | Async respond/cancel/delete with rollback + retry |
| `FriendsViewModel` | Unify remove error with banner + retry |
| `AlertsViewModel` | Soft load; action errors without wiping list |
| `AddGroupViewModel` | Same banner for create errors |
| `ContentView` / `RootView` | `scenePhase` → refresh (live) |
| `FriendsView`, `AlertsView`, Groups surface, `PlansView` | `.refreshable` + banner host |

Register new Swift files via `scripts/pbxproj_add.py`.

### Soft load rule (all list VMs)

```text
if loadState.value == nil { loadState = .loading }
// fetch…
// success → .loaded
// failure → if had content, keep it (+ optional refresh error); else .failed
```

---

## 4. Testing & acceptance

### Automated coverage

| Area | Prove |
|------|--------|
| LiveDataStore refresh | Clears caches; re-fetches; concurrent callers coalesce; success → one revision; failure → prior rows, no revision |
| Debounce / coalesce | Documented minimum interval behavior; first-active skip does not block a later true foreground |
| AppDataContainer | Live hits store; mock no-ops without throw |
| PlansViewModel | RSVP/cancel/delete failure rolls back + sets error; retry re-invokes repo |
| FriendsViewModel | Remove failure keeps list + message; retry path |
| AlertsViewModel | Action failure keeps rows; soft load keeps content while refreshing |
| AddGroupViewModel | Create failure leaves form + message |

Use existing fakes / `LiveDataLoading` doubles. Scoped suites: `LiveDataStoreTests`, `PlansViewModelTests`, `AlertsTests`, friends/remove coverage, then `scripts/test.sh build`; full suite before PR.

### Manual live smoke (when possible)

1. Two sessions: change on A → foreground B → B updates without restart.
2. Pull-to-refresh after remote change on Friends / Alerts / Groups / Pushes.
3. Airplane mode on covered mutations → banner + rollback; network + Retry → success.

### Acceptance criteria

1. Live return-to-foreground re-warms the full session snapshot (debounced/coalesced); open screens update via revision without blanking content.
2. Friends, Alerts, Groups, and Pushes support pull-to-refresh with content kept visible.
3. No silent failure for: push RSVP, cancel, delete; friend remove; group create; friend-request and group-invite accept/deny.
4. Optimistic RSVP/cancel/delete restore prior UI on failure.
5. Banner Retry re-attempts the same mutation; success clears the error.
6. Foreground refresh failure is quiet; pull-to-refresh failure may show a light message without wiping lists.
7. Mock mode: refresh and mutation error paths work without network.
8. Successful writes still bump revision once; failed writes do not corrupt live cache.

### Docs after implementation

- `tasks/spec.md` — Issue #33 contract
- `tasks/todo.md` — progress checklist
- `docs/data-architecture.md` — session re-warm entry point (durable facts only)

---

## Implementation order (suggested)

1. `LiveDataStore.refresh` + `AppDataContainer.refreshSession` + tests
2. Debounce / foreground wiring + skip first active
3. Soft load fixes + pull-to-refresh on four surfaces
4. `ActionErrorState` + banner component
5. Plans mutations (RSVP/cancel/delete)
6. Friends remove + Alerts accept/deny + Add Group banner unification
7. Verify group-create cache invalidation on live path
8. Focused tests + build

