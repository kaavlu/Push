# Complete Push Lifecycle and Live History — Implementation Plan

> **For agentic workers:** Execute task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Derive Push active/historical lifecycle from time, fill live History/calendar from completed pushes, and wire History › to a month list + read-only detail.

**Architecture:** Pure `PushLifecycle` + `PastHangoutBuilder` drive repo filters and calendar/history. No new tables. Mock keeps seed hangouts; live derives only. UI adds History list/detail on cream Pushes styling.

**Tech Stack:** SwiftUI, MVVM, existing `PushRepository` / `LiveDataStore`, XCTest via `scripts/test.sh`.

**Design:** `docs/superpowers/specs/2026-07-20-complete-push-lifecycle-design.md`

## Global Constraints

- Files ≤ 400 lines; functions ≤ 40 lines
- No magic numbers — named constants
- Register new Swift files with `python3 scripts/pbxproj_add.py`
- Tests: `scripts/test.sh suite <Name>`
- Do not rebuild create/edit/RSVP/cancel/delete write paths
- Mock seed hangouts never leak to live

## File map

| File | Role |
|------|------|
| `Push/Data/Derived/PushLifecycle.swift` | Active/historical/phase predicates |
| `Push/Data/Derived/PastHangoutBuilder.swift` | Completed pushes → `PastHangout` |
| `Push/Data/Derived/HistoryContentBuilder.swift` | `HistoryItemData` for list/detail |
| `Push/Data/Repositories/LocalRepositories.swift` | Wire active + hangouts |
| `Push/Data/Supabase/SupabasePushRepository.swift` | Wire active + hangouts |
| `Push/Data/Derived/PushTimingFormatter.swift` | “now” from derived happening |
| `Push/PlansModels.swift` | `HistoryItemData` |
| `Push/PlansViewModel.swift` | History state, month reload |
| `Push/PlansHistoryView.swift` | Month list + detail |
| `Push/PlansCalendarView.swift` | Wire History › |
| `Push/ManagePushView.swift` | Delete or leave unused (remove if safe) |
| `PushTests/PushLifecycleTests.swift` | Lifecycle + hangout builder tests |
| `PushTests/PushTimingFormatterTests.swift` | Update for derived “now” |

---

### Task 1: PushLifecycle + PastHangoutBuilder (TDD)

**Files:**
- Create: `Push/Data/Derived/PushLifecycle.swift`
- Create: `Push/Data/Derived/PastHangoutBuilder.swift`
- Create: `PushTests/PushLifecycleTests.swift`
- Register via `pbxproj_add.py`

**Interfaces:**
- `PushLifecycle.isActive(_ plan: PushPlan, now: Date) -> Bool` — `cancelledAt == nil && now < expiresAt`
- `PushLifecycle.isHistorical(_ plan: PushPlan, now: Date) -> Bool` — `cancelledAt == nil && now >= expiresAt`
- `PushLifecycle.isHappening(_ plan: PushPlan, now: Date) -> Bool` — active && `now >= startsAt`
- `PushLifecycle.phase(_ plan: PushPlan, now: Date) -> PushPlan.State?` — `.collecting` / `.happening` if active, else `nil`
- `PastHangoutBuilder.hangouts(plans:responses:monthContaining:now:calendar:) -> [PastHangout]`

- [ ] **Step 1:** Write failing tests for active/historical/cancelled boundaries and hangout mapping (`.in` only, month filter, cancel excluded)
- [ ] **Step 2:** Implement helpers; register files; run `scripts/test.sh suite PushLifecycleTests` → PASS
- [ ] **Step 3:** Commit

---

### Task 2: Repository wiring

**Files:**
- Modify: `LocalPushRepository.activePlans` / `pastHangouts`
- Modify: `SupabasePushRepository.activePlans` / `pastHangouts`

- [ ] **Step 1:** Filter active with `PushLifecycle.isActive`
- [ ] **Step 2:** Live pastHangouts via builder from store pushes+responses
- [ ] **Step 3:** Mock pastHangouts = builder + seed hangouts same month, sorted by date
- [ ] **Step 4:** Extend tests (or DataLayer/Plans tests) for expired exclusion; run suites
- [ ] **Step 5:** Commit

---

### Task 3: Timing formatter

**Files:**
- Modify: `Push/Data/Derived/PushTimingFormatter.swift`
- Modify: `PushTests/PushTimingFormatterTests.swift`

- [ ] **Step 1:** “now” iff `PushLifecycle.isHappening` (ignore stored `state`)
- [ ] **Step 2:** Update tests: past start within expiry → “now”; future start even if stored `.happening` → not “now”; expired → formatted time
- [ ] **Step 3:** Run suite; commit

---

### Task 4: History presentation + ViewModel

**Files:**
- Modify: `Push/PlansModels.swift` — add `HistoryItemData: Identifiable`
- Create: `Push/Data/Derived/HistoryContentBuilder.swift`
- Modify: `Push/PlansViewModel.swift` — history items, presentation flags, month-change reload on `moveWeek`

`HistoryItemData`: id, date, title, timeRange, locationHint, groupName, participants (`[HangoutPerson]`), cameFromPush, didHappen.

Builder builds from completed plans + responses + people/groups/places (same inputs as plan cards where needed). Calendar can keep using `PastHangout`; History list uses `HistoryItemData`.

- [ ] **Step 1:** Models + builder + unit tests (cancelled excluded, location from locationText/place)
- [ ] **Step 2:** ViewModel loads history items alongside hangouts; `isHistoryPresented`, `selectedHistoryItem`
- [ ] **Step 3:** `moveWeek` calls `load()` when month of `referenceDate` changes (or always reload hangouts for simplicity)
- [ ] **Step 4:** Commit

---

### Task 5: History UI + wire History ›

**Files:**
- Create: `Push/PlansHistoryView.swift`
- Modify: `Push/PlansCalendarView.swift` — History › sets `viewModel.isHistoryPresented = true`
- Modify: `Push/PlansView.swift` — fullScreenCover for history
- Delete or empty-stub remove: `ManagePushView` if unused (grep first)

- [ ] **Step 1:** Month list (cream styling), empty state, row → detail (read-only)
- [ ] **Step 2:** Wire covers and History ›
- [ ] **Step 3:** Build; commit

---

### Task 6: Verification

- [ ] `scripts/test.sh suite PushLifecycleTests`
- [ ] `scripts/test.sh suite PushTimingFormatterTests`
- [ ] `scripts/test.sh suite PlansViewModelTests`
- [ ] `scripts/test.sh build`
- [ ] Update `tasks/todo.md` / `tasks/spec.md` checkboxes
- [ ] Final commit if needed

## Spec coverage

| Spec item | Task |
|-----------|------|
| Derive lifecycle | 1–2 |
| pastHangouts live | 2 |
| Cancelled excluded | 1–2 |
| Timing “now” | 3 |
| History list/detail | 4–5 |
| Month reload | 4 |
| Manage stub | 5 |
| Mock isolation | 2 |
