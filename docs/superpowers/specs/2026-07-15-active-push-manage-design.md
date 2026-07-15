# Active Push card: Manage button + layout tightening

## Problem

`ActivePlanCard` (shown in the "Active Pushes" module on the Pushes tab) has
no way to change your RSVP without going through the full "Review N" swipe
queue, which only contains pushes still needing a first response. Once
you've responded, there's no way back in. The card also has looser vertical
spacing under the "X going" line than it needs.

## Design

### Card layout (`ActivePlanCard.swift`)

- `groupRow` becomes an `HStack`. Left side keeps the existing "Group · Time"
  text unchanged. Right side adds `plan.locationHint` (right-aligned, footnote/
  tertiary style matching the old location row), shown only when non-empty —
  it sits in the same right-aligned column as the status pill in `headerRow`.
- The old standalone `locationRow` at the bottom of the card is removed; its
  content moved into `groupRow`.
- `socialProofRow` ("X going") merges with a new **Manage →** button into one
  footer row, styled like `YourPushCard`'s `footerRow`: text left, button
  right-aligned via `Spacer()`.
- Final row order: `headerRow` → `groupRow` (with location) → `Divider` →
  `goingSection` (Going: label + avatars) → footer row (going count +
  Manage). No extra top padding is added above the footer row (unlike
  `YourPushCard`), so it sits close under the avatar row.
- `ActivePlanCard` gains a required `onManage: () -> Void` param.

### Manage button behavior

- Always visible, regardless of the push's current status (pending, joined,
  waiting, locked, happening) — lets the user change a response they already
  gave.
- Tapping it opens the existing swipe deck (`ReviewPushesView`), focused on
  just that one push rather than the full "needs response" queue.

### `ReviewPushesView` changes

- New optional `focusPlan: PlanData?` init param (default `nil`, preserving
  today's full-queue "Review N" behavior).
- `currentPlan`: when `focusPlan` is set, returns it directly instead of
  reading `viewModel.plansNeedingResponse`.
- `commit(plan:direction:)`: when `focusPlan` is set, call
  `viewModel.respond(to:with:)` then `dismiss()` immediately instead of
  incrementing `deckIndex` — there's nothing else queued in this mode.

### Wiring (`PlansViewModel.swift`, `PlansView.swift`)

- New `@Published var reviewFocusPlan: PlanData?` and `func openReview(plan:
  PlanData)` on `PlansViewModel`. Kept separate from the existing
  `managedPlan` / `openManage(plan:)`, which drives a different action
  (editing push details via `StartPushFlowView`).
- `PlansView` adds `.fullScreenCover(item: $viewModel.reviewFocusPlan) {
  ReviewPushesView(viewModel: viewModel, focusPlan: $0) }`.
- `ActivePushesModule` wires `ActivePlanCard`'s new `onManage` to
  `viewModel.openReview(plan: first)`.

## Out of scope

- No changes to `ReviewPushCard` (the swipe card's own layout/content).
- No changes to the full-queue "Review N" flow's behavior.
- No new list view for all active pushes (none exists today; only the single
  first card is shown on the Pushes tab).
