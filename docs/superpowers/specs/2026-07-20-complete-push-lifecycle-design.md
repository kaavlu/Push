# Complete the Push Lifecycle and Live History (Issue #45)

## Problem

Live Push create / edit / RSVP / cancel / delete already work. What is missing:

1. **Lifecycle** — `activePlans()` only drops soft-cancelled rows. Expired Pushes stay on Active cards forever. Stored `PushPlan.state` is almost never updated.
2. **History / calendar** — `SupabasePushRepository.pastHangouts` returns `[]`. Live calendar and History are empty. Mock still uses seed `PastHangout` rows.
3. **History ›** — no-op button. Day detail exists for calendar tiles but there is no month History list or historical Push detail.
4. **Stub** — `ManagePushView` still says “Manage coming soon” (owner Manage already routes to `StartPushFlowView(context: .edit)`; invitee Manage routes to `ReviewPushesView`).

This design finishes lifecycle, live History, and calendar **without** rebuilding coordination writes or adding hangout tables.

## Product decisions (locked)

| Decision | Choice |
|----------|--------|
| History source | **Derive on read** from push + response rows |
| Active → historical | **Time-only**: active while `cancelledAt == nil && now < expiresAt` |
| Cancelled in History/calendar | **Excluded entirely** |
| `collecting` / `locked` / `happening` | **Derived on read** from time; DB `state` not source of truth for lists |
| Edit + RSVP window | **Until expiry** (including post-`startsAt` “happening” window) |
| History › | **Month History list** → item detail |
| Completed vs attendance | History shows **completed plans / participating respondents** (`.in`), not physical attendance |
| Schema | Prefer **no new tables**; reuse `pushes` / `push_responses` |

## Lifecycle rules

### Source of truth

| Concern | Rule |
|---------|------|
| Active vs historical | Derived at **read time** from `startsAt`, `expiresAt`, `cancelledAt`, `now` |
| DB `state` column | Left as-is for compatibility; **not** used for Active/History filtering |
| History rows | Derived push + responses → `PastHangout` (no `past_hangouts` table) |
| Cancelled | Soft-cancel (`cancelled_at`); excluded from Active, History, calendar |
| Deleted | Hard delete; gone everywhere (responses cascade) |

### Derived phases

| Phase | Predicate | Product surfaces |
|-------|-----------|------------------|
| **Upcoming** | not cancelled, `now < startsAt`, `now < expiresAt` | Active; owner edit; RSVP |
| **Happening** | not cancelled, `startsAt ≤ now < expiresAt` | Active; owner edit; RSVP |
| **Completed** | not cancelled, `now ≥ expiresAt` | History + calendar only |
| **Cancelled** | `cancelledAt != nil` | Nowhere in product lists |
| **Deleted** | row gone | Nowhere |

`expiresAt` remains **startsAt + 6 hours** on create/update (existing `PushWriteConstants` / mock equivalent).

Optional derived `PushPlan.State` for timing/copy helpers:

- `now < startsAt` → `.collecting` (`.locked` unused for gating in this issue)
- `startsAt ≤ now < expiresAt` → `.happening`
- else historical (not on active list)

Presentation pills on cards still come from the viewer’s **response** (`PlansContentBuilder.pill`), not lifecycle phase.

### Mutations

While **active** (`cancelledAt == nil && now < expiresAt`):

- **Owner:** edit (title, time, location text, audience/invitees, note), cancel, delete
- **Invitee:** upsert own RSVP only; no owner edit/cancel/delete chrome

Once **historical** (`now ≥ expiresAt`):

- App surfaces **block** edit, RSVP, cancel, and delete (History remains stable)
- Backend RLS unchanged (creator could still mutate via API); client does not offer actions

### Invitee reconciliation (existing; verify only)

On owner edit, `reconcileResponses` keeps existing RSVPs for retained people, seeds `.pending` for new invitees, deletes rows for removed invitees. Removed invitees lose `can_view_push` via missing response row (and non-membership for group audience). Their old responses must not affect active counts after removal.

## History derivation

### `PastHangout` mapping (from a completed push)

| Field | Source |
|-------|--------|
| `id` | Push id |
| `date` | `startsAt` (day bucket via `Calendar.current`) |
| `note` | Push `title` |
| `timeRange` | Formatted start (reuse timing helpers; empty string only if no useful time) |
| `participantIDs` | Distinct people with response `.in` (including creator) |
| `cameFromPush` | `true` |
| `didHappen` | `true` |

Never map cancelled or deleted pushes. Never map active pushes into History.

**Copy stance:** UI may say participants “were in” / show names from RSVPs. Do not claim physical attendance.

### Mock vs live

| Mode | `pastHangouts(forMonthContaining:)` |
|------|-------------------------------------|
| **Live** | Only derived completed pushes in that month |
| **Mock** | Derived completed pushes **plus** existing seed hangouts (non-push calendar richness). Seed hangouts never appear in live. |

Both modes use the same **active** filter so mock Active lists also drop expired/cancelled rows.

### Month scope

Keep `forMonthContaining`. Filter completed pushes whose `startsAt` falls in that calendar month (`Calendar.current`). Week navigation that crosses months may need a reload when `referenceDate`’s month changes (ViewModel already reloads on store change; `moveWeek` should reload hangouts when the visible month changes).

## Calendar

Existing `PlansContentBuilder.calendarDays` stays the aggregator:

- `pushCount` / tiles use hangouts with `didHappen == true`
- Cancelled never appear → never count as completed activity
- Multiple completed pushes same day aggregate correctly
- Empty weeks: existing empty day cells + footer counts stay valid
- Timezone: **device `Calendar.current`** consistently (same as mock today)

No structured place backend; location text on History detail comes from push `locationText` / place name when available via existing plan fields (detail model may carry more than `PastHangout` — see UI).

## UI

### Active surfaces

- Owner **Manage →** → existing `StartPushFlowView(context: .edit(plan:))` (already wired)
- Invitee **Manage →** → existing focused `ReviewPushesView` (already wired)
- **Remove or leave unreachable** `ManagePushView` stub (“Manage coming soon”) so it cannot be presented

### History ›

- Opens full-screen (or cream full-screen cover consistent with Friends/Pushes) **month History list** for the ViewModel’s current `referenceDate` month
- Rows: title (`note`), date/time, optional location if we pass richer presentation models, participant pucks, completed treatment only
- Empty month: intentional empty copy (“No completed Pushes this month”)
- Tap row → **History detail**

### History detail

Read-only surface for one completed push (or seed hangout in mock):

- Title, scheduled time, location text when known
- Audience/group label when known
- Participating respondents (`.in`)
- Completed state (not cancelled — cancelled never shown)
- **No** Manage / RSVP / Cancel / Delete / edit actions

Day calendar sheet can keep listing hangouts; optional enhancement: row tap from day sheet also opens the same detail. Minimum bar: History list → detail; day sheet remains useful as-is.

### Calendar week navigation

When `moveWeek` changes the month containing `referenceDate`, re-fetch `pastHangouts` / reload so activity is not stuck on the first loaded month.

## Backend / authorization

No new RLS required if derivation stays client-side on already-visible rows.

Existing rules (keep / verify with tests):

- Select push: creator, response-row recipient, or group member (`private.can_view_push`)
- Update/cancel push: creator only
- Delete push: creator only (0008)
- Response insert/update: self (creator may insert `.pending` only)
- Response delete: self or creator (invitee reconcile)
- Removed invitee: no response row → cannot select invitees-only push
- Historical access: same as active visibility for rows still present; deleted rows unreadable

Optional later (out of scope unless tests demand): DB CHECK or trigger refusing updates when `now() >= expires_at`. Client gating is enough for this issue.

## Refresh and consistency

- Reuse `notifyPushesChanged()` after writes; ViewModels reload via `onStoreChange`
- After expiry with no write: next `load()` / pull-to-refresh / foreground `refreshSession` moves the card Active → History
- Same push must not appear in both Active and History under the same `now`
- Failed mutations keep existing `ActionErrorBanner` + rollback patterns
- Pull-to-refresh already re-warms session then `load()`

## Architecture

### New pure helpers (recommended names)

```
Push/Data/Derived/PushLifecycle.swift
  isActive(plan:now:) -> Bool
  isHistorical(plan:now:) -> Bool
  phase(plan:now:) -> PushPlan.State   // collecting | happening (locked unused)
  // cancelled / deleted handled by callers

Push/Data/Derived/PastHangoutBuilder.swift
  hangouts(plans:responses:month:now:calendar:) -> [PastHangout]
  // only non-cancelled, expiresAt <= now, startsAt in month
```

Repos filter:

```swift
plans.filter { PushLifecycle.isActive($0, now: now) }
// isActive := cancelledAt == nil && now < expiresAt
```

Live `pastHangouts`:

```swift
let plans = try await store.pushes().map { $0.pushPlan() }
let responses = try await store.pushResponses().map { $0.pushResponse() }
return PastHangoutBuilder.hangouts(plans: plans, responses: responses, month: date, now: Date())
```

Mock `pastHangouts`:

```swift
let derived = PastHangoutBuilder.hangouts(...)
let seed = database.hangouts.filter { same month }
return merge(derived, seed) // stable sort by date
```

### Timing copy

Update `PushTimingFormatter` so “now” uses **derived happening** (`startsAt ≤ now < expiresAt` and not cancelled), not stored `plan.state == .happening`. Avoids stuck “now” on stale seed/live rows.

### ViewModel / models

- `PlansViewModel`: History presentation flag/route; `moveWeek` reloads when month changes; expose month hangouts / history items for list
- Prefer a small presentation struct for History rows/detail if `PastHangout` lacks location/group (e.g. `HistoryItemData` built beside calendar) — keep Views dumb
- No new repository protocol methods unless needed: enrich `pastHangouts` only, or add `historicalPlans(forMonthContaining:)` if detail needs full `PushPlan` + responses. Prefer one path:

  **Preferred:** add `func historicalPlans(forMonthContaining:) async throws -> [PushPlan]` **or** return richer derived DTOs from a single builder used by calendar + History. Simplest fit with today’s API: keep `pastHangouts` for calendar; add repo method or builder input that also yields detail fields from the same completed-plan filter.

  Concrete choice for implementation:

  1. Extend derivation to produce `HistoryEntry` (id, date, title, timeRange, locationHint, groupName, participantIDs, didHappen, cameFromPush) used by calendar (map down to `PastHangout` / day entries) **or**
  2. Keep `PastHangout` for calendar; History detail reloads plan by id from cached pushes.

  **Choose (1) thin `HistoryEntry` in Derived** if location/group are required on list/detail without a second fetch. Map to existing `DayHangoutEntry` fields where possible to limit UI churn.

### Files likely touched

- `Push/Data/Derived/PushLifecycle.swift` (new)
- `Push/Data/Derived/PastHangoutBuilder.swift` or `HistoryContentBuilder.swift` (new)
- `Push/Data/Repositories/LocalRepositories.swift` — active filter + hangouts
- `Push/Data/Supabase/SupabasePushRepository.swift` — active filter + hangouts
- `Push/Data/Derived/PushTimingFormatter.swift` — derived “now”
- `Push/Data/Derived/PlansContentBuilder.swift` — only if History presentation joins here
- `Push/PlansViewModel.swift` — month reload, History route, detail selection
- `Push/PlansCalendarView.swift` — wire History ›
- New History list/detail views + style (cream Pushes treatment)
- Remove/unwire `ManagePushView` stub
- Tests: lifecycle, hangout builder, repo filters, ViewModel month boundary, timing formatter
- `tasks/spec.md` / `tasks/todo.md` for tracking
- Docs: this file; brief AGENTS note after ship if durable

## Testing

| Area | Coverage |
|------|----------|
| Lifecycle | Active / historical / cancelled predicates; boundary at `expiresAt` |
| Timing | “now” only when derived happening |
| pastHangouts | Completed mapped; cancelled/deleted excluded; month filter; `.in` participants |
| Mock | Seed hangouts still appear; live path empty without completed pushes |
| activePlans | Expired and cancelled excluded (mock + live unit with fixtures) |
| Invitee reconcile | Existing tests remain; add removal loses access counts if missing |
| Cancel vs delete | Cancel soft-hides; delete removes; neither corrupts hangout derivation |
| Calendar | Aggregation, empty month, timezone day boundaries via `Calendar` injection where tests need it |
| History UI ViewModel | Month change reload; detail has no mutation entry points (logic tests) |
| Cache | `notifyPushesChanged` still reloads plans + hangouts |

Out of scope for automated here unless harness exists: full two-account live E2E (manual AC checklist in todo).

## Out of scope (unchanged from issue)

- Presence / places backend, structured place picker, GPS attendance
- Feed, realtime, push notifications
- Advanced weekly/group recap storytelling
- Materialized hangout table / cron state machine
- Changing RLS model beyond verification

## Acceptance mapping

| # | Criterion | Design coverage |
|---|-----------|-----------------|
| 1–5 | Create, RSVP, edit, recipients, invitee limits | Existing writes + verify; no rebuild |
| 6–7 | Lifecycle advance; leave Active | Time-derived active filter |
| 8–10 | Calendar + History + detail | Derive hangouts + History › list/detail |
| 11 | Cancelled ≠ completed | Cancelled excluded from derivation |
| 12 | Deleted gone | Hard delete; no row to derive |
| 13 | Expired rules | `expiresAt` gate |
| 14 | Calendar boundaries | `Calendar.current` + month reload |
| 15 | Unauthorized mutations | Existing RLS; client gates historical |
| 16 | Mock isolation | Seed hangouts mock-only; live derive-only |

## Implementation order (preview)

1. Pure `PushLifecycle` + hangout/history builder + unit tests  
2. Wire Local + Supabase `activePlans` / `pastHangouts`  
3. Timing formatter + PlansViewModel month reload  
4. History list + detail UI; wire History ›  
5. Remove Manage stub; regression suites  
6. Manual two-account checklist  

Detailed step plan follows in `docs/superpowers/plans/` after spec approval.
