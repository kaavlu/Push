---
name: plans-page-design
description: Design spec for the Plans page — calendar heatmap, current pushes module, and swipe review deck (issue #5)
metadata:
  type: project
---

# Plans Page — Design Spec

**Issue:** #5  
**Date:** 2026-07-01  
**Scope:** Three systems — calendar heatmap, current pushes module, swipe review deck. Start-plan flow deferred to a future issue.

---

## What We're Building

A Plans page that feels like a **social activity calendar + compact stack of current Pushes + swipe-based way to review plans**. Not a calendar app, task manager, or chat feed. Plans should feel alive, lightweight, and social.

The page is presented as a `fullScreenCover` from `ContentView`, consistent with Groups and Profile. No bottom navbar — only a sticky `+ Start Plan` pill at the bottom (stub for now).

---

## Data Models (`PlansModels.swift`)

### PlanData

```swift
struct PlanData: Identifiable {
    let id: String
    let title: String           // e.g. "Food tonight?"
    let group: String           // e.g. "Michigan"
    let timeSignal: String      // e.g. "8:00 PM", "around 7:45 PM", "now"
    let socialProof: String     // e.g. "3 in · 2 maybe"
    let locationHint: String    // e.g. "Suggested: North Park"
    var status: PlanStatus
}
```

### PlanStatus

```swift
enum PlanStatus: String {
    case pending, joined, open, waiting, locked, happening
    var pill: String { rawValue.capitalized }
}
```

### CalendarDayData

```swift
struct CalendarDayData: Identifiable {
    let id: String           // "2026-07-01"
    let date: Date
    let pushCount: Int       // 0 = empty dot, 1 = small, 2 = filled, 3+ = emphasized
    let hadPlan: Bool        // true → ring around dot
    let almostHappened: Bool // true → hollow dot (overrides pushCount rendering)
}
```

### SwipeDirection

```swift
enum SwipeDirection { case left, right, up }
```

### PlansMockData

Lives in `PlansModels.swift` as a `enum PlansMockData`. Seeds plans using real group names (India, Exec, Michigan) and friend names from `RealWorldMockData`. Calendar days generated for the current month with plausible randomized push counts.

---

## ViewModel (`PlansViewModel.swift`)

Single ViewModel owns all state. Both `PlansView` and `ReviewPushesView` share the same instance.

### Published State

| Property | Type | Purpose |
|---|---|---|
| `plans` | `[PlanData]` | All active plans, mutable statuses |
| `calendarDays` | `[CalendarDayData]` | Current month's days |
| `monthLabel` | `String` | e.g. "July" |
| `totalPushesThisMonth` | `Int` | Footer summary count |
| `mostActiveGroup` | `String` | Footer summary group name |
| `selectedDay` | `CalendarDayData?` | Drives day-detail `.sheet` |
| `isReviewDeckPresented` | `Bool` | Drives `ReviewPushesView` fullScreenCover |

### Derived

- `plansNeedingResponse` — plans with `.pending` or `.open` status; these feed the swipe deck
- `activeCount` — total plan count
- `needsResponseCount` — count of pending/open plans
- `sortedPlans` — sorted by: needing response → happening soon → joined → high-momentum → other

### Mutation

```swift
func respond(to plan: PlanData, with direction: SwipeDirection) {
    // right → .joined, left → .waiting, up → .open (maybe)
}
```

---

## File Structure

| File | Responsibility | Notes |
|---|---|---|
| `PlansModels.swift` | Models + mock data | ≤ 400 lines |
| `PlansViewModel.swift` | All state + mutations | ≤ 400 lines |
| `PlansStyle.swift` | Layout enums + `PlanStatusPill` component | ≤ 400 lines |
| `PlansView.swift` | Page shell + current pushes module | ≤ 400 lines |
| `PlansCalendarView.swift` | Heatmap grid + day-detail sheet | ≤ 400 lines |
| `ActivePlanCard.swift` | Normalized plan card | ≤ 400 lines |
| `ReviewPushesView.swift` | Full-screen swipe deck | ≤ 400 lines |

---

## PlansView

Page shell following the same pattern as `GroupsView` and `ProfileView`:

```
ZStack(alignment: .bottom) {
    PushModalBackground()
    ScrollView {
        VStack {
            PlansCalendarView(viewModel)     // heatmap card
            CurrentPushesModule(viewModel)   // summary + 1-2 cards + "Review all →"
        }
    }
    StartPlanButton()                        // sticky pill, stub action
}
.overlay(alignment: .top) { PushModalCloseButtonBar }
.fullScreenCover(isPresented: $viewModel.isReviewDeckPresented) {
    ReviewPushesView(viewModel: viewModel)
}
```

### CurrentPushesModule (private struct in PlansView)

- Summary row: `"5 active · 2 need you"`
- Up to 2 `ActivePlanCard` views (sorted by priority)
- `"Review all N →"` button → sets `viewModel.isReviewDeckPresented = true`

---

## PlansCalendarView

Builds a 7-column grid (M T W T F S S) from `calendarDays`.

### CalendarDayCell rendering rules

| Condition | Visual |
|---|---|
| `pushCount == 0` | Faint dot |
| `pushCount == 1` | Small filled dot |
| `pushCount == 2` | Stronger filled dot |
| `pushCount >= 3` | Larger / emphasized dot |
| `hadPlan == true` | Ring around dot |
| `almostHappened == true` | Hollow dot (overrides count) |

Tapping a cell sets `viewModel.selectedDay`, which drives a `.sheet` showing:
- Date header (e.g. "Friday, July 12")
- Count line (e.g. "3 Pushes")
- List of that day's pushes with group + who

Footer below grid:
- `"N Pushes this month"`
- `"Most active: [group]"`

---

## ActivePlanCard

Normalized card used in both `PlansView` (current pushes preview) and `ReviewPushesView` (deck card).

```
┌────────────────────────────────┐
│ [title]              [status]  │
│ [group] · [timeSignal]         │
│                                │
│ [socialProof]                  │
│ [locationHint]                 │
└────────────────────────────────┘
```

Status rendered as a `PlanStatusPill` (defined in `PlansStyle.swift`) — a small capsule with color-coded fill:
- `.pending` → sunbeam yellow
- `.joined` → walnut green-ish warm
- `.open` → soft neutral
- `.happening` → stronger accent

Uses `pushGlassBackground(cornerRadius:)` for the card background, consistent with the rest of the app.

---

## ReviewPushesView

Full-screen cover. Shows cards from `viewModel.plansNeedingResponse` one at a time.

### Layout

```
"Review Pushes"         [X dismiss]

┌────────────────────────────────┐
│  ActivePlanCard (current)      │  ← draggable, rotates with offset
└────────────────────────────────┘

← Pass        Maybe ↑        Join →

[N left]
```

### Gesture handling

`DragGesture` on the card:
- `.onChanged`: apply `offset` and `rotationAngle` (proportional to horizontal drag)
- `.onEnded`: if horizontal distance > threshold → left/right swipe; if vertical up > threshold → up swipe. Calls `viewModel.respond(to: currentPlan, with: direction)` then advances deck index.

Threshold constants live in `PlansStyle.swift`.

After last card: empty state — `"You're all caught up"` with a secondary line `"Check back later"`.

### State

`@State private var deckIndex: Int` — local to `ReviewPushesView`, starts at 0, increments on each swipe. Always guard `deckIndex < viewModel.plansNeedingResponse.count` before subscripting — the array shrinks as the user swipes and VM mutates statuses.
`@State private var dragOffset: CGSize` — drives card transform during drag.

---

## Design Constraints

- **No bottom navbar** on PlansView. Sticky `+ Start Plan` pill is the only bottom element (stub).
- **No streak language.** Calendar footer never says "you missed X days."
- **Status copy is social, not managerial.** Pills say "Joined" not "Accepted"; "Pass" not "Reject."
- **Glass card style** via `pushGlassBackground()` on all cards and the calendar module.
- **Color palette** — sunbeam + walnut only. No black text; use `PushControlColors.textEspresso` for titles.
- **Files ≤ 400 lines, functions ≤ 40 lines.** Split further if needed.

---

## ContentView Wiring

`PlansView` already has a route in `MainMapRoute.plans` and `ContentView` already handles it:

```swift
case .plans:
    CreatePlaceholderView(...)  // ← replace with PlansView()
```

No other changes to `ContentView` or `MainMapModels` needed.
