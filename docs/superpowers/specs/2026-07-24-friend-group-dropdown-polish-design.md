# Polish the friend-group filter dropdown (Issue #91)

## Context

`Push/ContentView.swift`'s `topControlsLayer` renders the friend-group filter
control: a collapsed pill (`FriendGroupDropdownButton`, showing
`MapViewModel.selectedFilterTitle`) that expands into a panel
(`FriendGroupDropdownPanel`) of selectable rows (`FriendGroupDropdownRow` →
`PushSingleSelectRow`), toggled by `isFilterDropdownExpanded`. Issue #91 asked
for a general polish pass with no specifics given. A code audit (no visual
complaint driving this — see options considered below) surfaced four concrete,
scoped issues. Per `CLAUDE.md`, the design system's appearance is "approved"
and must be preserved, so this is a behavioral/structural polish pass, not a
visual redesign.

## Scope

- `Push/ContentView.swift`: `topControlsLayer` and body `ZStack`,
  `FriendGroupDropdownButton`, `FriendGroupDropdownPanel`, `TopControlLayout`,
  `TopDropdownLayout`.
- `Push/DesignSystem/Components/Selectors/PushSingleSelectRow.swift` (DS-037
  shared row primitive — currently only consumed by this dropdown).
- No new DS surfaces or files. No change to `pushMapControlGlass` (DS-011);
  the issue's open question of whether `topControlBackground` is a one-off is
  resolved — it's a thin private wrapper directly around the named
  `pushMapControlGlass` surface, already compliant.

## Changes

### 1. Outside-tap-to-dismiss

Today, closing the expanded panel requires tapping one of a specific set of
elements that each explicitly reset `isFilterDropdownExpanded` (profile icon,
alerts icon, a map puck, a nav item, an add-friends CTA, selecting a filter
row). Tapping empty map background does nothing — inconsistent with the
create-action menu in the same file, which has a dedicated full-screen
`createMenuBackdrop` for exactly this.

Add a new private `filterDropdownBackdrop` view:

```swift
private var filterDropdownBackdrop: some View {
    Color.clear
        .contentShape(Rectangle())
        .ignoresSafeArea()
        .onTapGesture {
            isFilterDropdownExpanded = false
        }
}
```

Render it conditionally (`if isFilterDropdownExpanded { filterDropdownBackdrop.transition(.opacity) }`)
in the body `ZStack`, declared before `BottomNavigationBar`, alongside the
existing `createMenuBackdrop` block. This mirrors `createMenuBackdrop`'s
existing technique for intercepting taps over `StyledMapView` (a
`UIViewRepresentable`-wrapped `MKMapView`) — a pattern already proven in this
file, not a new one.

Ordering/z-index rationale:
- `topControlsLayer` already carries an explicit
  `.zIndex(TopDropdownLayout.expandedZIndex)` (1.0), so the pill, panel rows,
  and profile/alerts buttons keep winning hit-testing over the backdrop
  regardless of declaration order.
- `BottomNavigationBar` has no explicit `zIndex` and relies on ZStack
  declaration order (later declared = hit-tested first) for its taps. The
  backdrop must be declared **before** `BottomNavigationBar` so the bar keeps
  its current single-tap dismiss-then-navigate behavior (its handlers already
  call `isFilterDropdownExpanded = false` themselves).

Net behavior: tapping the map while the panel is open closes the panel and
swallows that tap — a puck under the tap is not simultaneously selected.

### 2. Dead constant cleanup

Delete unused constants (confirmed zero references outside their own
declarations, via `grep`):

- `TopControlLayout`: `strokeWidth`, `profileRingWidth`, `highlightWidth`,
  `highlightInset`, `pillGlowRadius`, `profileGlowRadius`, `shadowRadius`,
  `shadowYOffset` — leftover duplicates of `PushMapGlassTokens` values from
  before the glass styling moved into the named `pushMapControlGlass` surface
  (DS-011).
- `TopDropdownLayout`: `rowHorizontalPadding`, `rowVerticalPadding`,
  `rowIconSpacing`, `checkmarkSize` — leftover from before row styling moved
  into the shared `PushSingleSelectRow` primitive (DS-037), which defines its
  own `PushSingleSelectRowMetrics`.

Pure deletion, no behavior or appearance change.

### 3. Scroll-safe panel

`FriendGroupDropdownPanel` currently renders every filter in an unbounded
`VStack`. `MapViewModel.filters` has no upper bound on group count (`[.allFriends] + `
the user's groups), so a user in many friend groups could grow the panel past
the map/bottom nav.

Wrap the row `VStack` in `ScrollView(showsIndicators: false)`, capped via
`.frame(maxHeight:)` at a new `TopDropdownLayout.panelMaxHeight` constant,
sized for ~5 visible rows. Like this file's existing hardcoded constants
(`overlayHeight`, `dropdownHeight`), the exact value is calibrated by eye in
the simulator during implementation rather than computed from font metrics —
consistent with the surrounding code's convention.

### 4. Accessibility polish

`PushSingleSelectRow` (DS-037):
- `.accessibilityElement(children: .combine)` so VoiceOver reads the row as
  one element.
- `.accessibilityAddTraits(.isSelected)` when `isSelected`, so selection state
  is conveyed via the standard trait.
- Hide the checkmark `Image` from the accessibility tree
  (`.accessibilityHidden(true)`) — now redundant with the trait, avoids a
  double announcement ("Michigan, checkmark, selected").

This is a shared DS primitive but currently has exactly one consumer
(`FriendGroupDropdownRow`), so the change is low-risk.

`FriendGroupDropdownButton`:
- `.accessibilityHint("Double tap to expand")` / `"Double tap to collapse"`
  based on `isExpanded`, so VoiceOver users know the pill is a disclosure
  control before activating it.

## Non-goals

- No change to the panel/pill's visual styling, colors, glass treatment, or
  spring animation curve — appearance stays as approved.
- No change to `pushMapControlGlass` / `PushMapGlassTokens`.
- No change to `MapViewModel` filter-loading logic.

## Testing

No existing test suite covers these views — `MapViewModelTests`
(`PushTests/DataLayerTests.swift`) cover `MapViewModel.selectedFilterID`
filtering logic only, which this work doesn't touch.

Manual verification in the simulator:
- Expand the panel, tap empty map background → panel closes, no puck gets
  selected.
- Expand the panel, tap bottom nav / profile / alerts → still single-tap
  navigates (dropdown closes and the destination opens together).
- Temporarily stub several extra filters to confirm the panel scrolls past 5
  rows instead of growing unbounded.
- VoiceOver spot-check (Simulator Accessibility Inspector) on the pill
  (expand/collapse hint) and rows (selected trait, single combined
  announcement).
