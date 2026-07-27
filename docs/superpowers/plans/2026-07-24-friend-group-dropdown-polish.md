# Friend-Group Dropdown Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the friend-group filter dropdown on the main map (`Push/ContentView.swift`) with four scoped, behavioral/structural fixes — no visual redesign.

**Architecture:** All changes live in `Push/ContentView.swift` (the dropdown's collapsed pill, expanded panel, and their layout constants) plus one shared DS primitive, `Push/DesignSystem/Components/Selectors/PushSingleSelectRow.swift` (DS-037). No new files, no new DS surfaces.

**Tech Stack:** SwiftUI, iOS, XCTest via `scripts/test.sh`.

## Global Constraints

- Preserve the design system's approved appearance — no visual/color/animation-curve changes (`CLAUDE.md`).
- MVVM: this work is view-only; no `MapViewModel` changes.
- No magic numbers — new sizes are named constants in the existing `TopControlLayout`/`TopDropdownLayout` enums, consistent with sibling constants already there (e.g. `overlayHeight`).
- Comments explain WHY, not WHAT.
- Deployment target compatibility: use `ScrollView(showsIndicators:)`, not the iOS 17-only `.scrollIndicators(_:)` modifier (per `tasks/lessons.md`, this project's actual deployment target is iOS 16.4 — single-parameter `.onChange` is used elsewhere for the same reason).
- Build/test via `scripts/test.sh build` (compile-only) — there is no existing test target covering these views; `PushTests/DataLayerTests.swift`'s `MapViewModel` filter tests are unaffected and don't need to be re-run for these tasks, but running them once at the end is cheap reassurance.

Full design context: `docs/superpowers/specs/2026-07-24-friend-group-dropdown-polish-design.md`.

---

### Task 1: Remove dead layout constants

**Files:**
- Modify: `Push/ContentView.swift:433-476` (`TopDropdownLayout`, `TopControlLayout` enums)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — this is pure deletion. Confirms no later task depends on the deleted names.

- [ ] **Step 1: Confirm zero references before deleting**

Run:
```bash
grep -n "TopControlLayout\.\(strokeWidth\|profileRingWidth\|highlightWidth\|highlightInset\|pillGlowRadius\|profileGlowRadius\|shadowRadius\|shadowYOffset\)" Push/ContentView.swift
grep -n "TopDropdownLayout\.\(rowHorizontalPadding\|rowVerticalPadding\|rowIconSpacing\|checkmarkSize\)" Push/ContentView.swift
```
Expected: no output (only the declaration lines themselves would match, and even those aren't matched by this pattern since it requires a `.` accessor — so truly zero output confirms the constants are unused).

- [ ] **Step 2: Delete the unused constants**

In `TopDropdownLayout` (around line 433), remove these four lines:
```swift
    static let rowHorizontalPadding: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 10
    static let rowIconSpacing: CGFloat = 8
```
and
```swift
    static let checkmarkSize: CGFloat = 12
```
so the enum reads:
```swift
private enum TopDropdownLayout {
    static let collapsedOverlayHeight = TopControlLayout.topMargin + TopControlLayout.dropdownHeight
    static let overlayHeight: CGFloat = 340
    static let horizontalPadding: CGFloat = 18
    static let labelSpacing: CGFloat = 6
    static let panelSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 6
    static func panelWidth(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 196, standard: 208, large: 218) }
    static let panelCornerRadius: CGFloat = 24
    static let rowSpacing: CGFloat = 2
    static let chevronSize: CGFloat = 11
    static let expandedChevronRotation = 180.0
    static let panelTransitionScale = 0.96
    static let animationResponse = 0.28
    static let animationDamping = 0.86
    static let expandedZIndex = 1.0
}
```

In `TopControlLayout` (around line 455), remove these eight lines:
```swift
    static let strokeWidth: CGFloat = 1
    static let profileRingWidth: CGFloat = 1.15
    static let highlightWidth: CGFloat = 0.8
    static let highlightInset: CGFloat = 1.2
    static let pillGlowRadius: CGFloat = 58
    static let profileGlowRadius: CGFloat = 24
    static let shadowRadius: CGFloat = 22
    static let shadowYOffset: CGFloat = 10
```
so the enum reads:
```swift
private enum TopControlLayout {
    static let topMargin: CGFloat = 10
    static func horizontalMargin(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 12, standard: 14, large: 16) }
    static func dropdownWidth(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 124, standard: 132, large: 139.4) }
    static let dropdownHeight: CGFloat = 46
    static let iconButtonSize: CGFloat = 44
    static let cornerRadius: CGFloat = iconButtonSize / 2
    static let iconSize: CGFloat = 17
    static let indicatorSize: CGFloat = 10
    static let indicatorStrokeWidth: CGFloat = 1
    /// Insets the unread badge from the control edge so it sits on the icon, not outside the button.
    static let indicatorInset: CGFloat = 9
    static let minimumTextScale = 0.78
}
```

- [ ] **Step 3: Build to confirm no breakage**

Run: `scripts/test.sh build`
Expected: build succeeds (this confirms nothing else referenced the deleted constants — if something did, this would fail with "cannot find X in scope").

- [ ] **Step 4: Commit**

```bash
git add Push/ContentView.swift
git commit -m "chore: remove dead top-controls layout constants

Leftover from before glass styling moved into pushMapControlGlass
(DS-011) and row styling moved into PushSingleSelectRow (DS-037)."
```

---

### Task 2: Outside-tap-to-dismiss backdrop

**Files:**
- Modify: `Push/ContentView.swift:28-79` (body `ZStack`), and add one new private computed property near `createMenuBackdrop` (~line 245).

**Interfaces:**
- Consumes: `isFilterDropdownExpanded` (existing `@State` on `ContentView`).
- Produces: new private `filterDropdownBackdrop: some View` on `ContentView`, following the exact shape of the existing `createMenuBackdrop`.

- [ ] **Step 1: Add the `filterDropdownBackdrop` view**

Add this new private computed property directly after `createMenuBackdrop` (after line 253, i.e. right after its closing brace):

```swift
    /// Invisible tap-catcher over the map so tapping outside the panel closes
    /// it — mirrors `createMenuBackdrop`'s interception technique, but stays
    /// transparent since this control doesn't need to dim the map.
    private var filterDropdownBackdrop: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
                isFilterDropdownExpanded = false
            }
    }
```

- [ ] **Step 2: Render it in the body `ZStack`, before `BottomNavigationBar`**

In `body` (around line 44-56), add a conditional block for the new backdrop right after the existing `isCreateMenuPresented` block and before the `VStack { topControlsLayer ... }` block:

```swift
            if isCreateMenuPresented {
                createMenuBackdrop
                    .transition(.opacity)

                CreateActionMenuView(action: selectCreateAction)
                    .padding(.bottom, CreateActionMenuLayout.cardBottomPadding(layout))
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: CreateActionMenuLayout.transitionScale, anchor: .bottom))
                    )
            }

            if isFilterDropdownExpanded {
                filterDropdownBackdrop
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                topControlsLayer
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .zIndex(TopDropdownLayout.expandedZIndex)
```

This placement is load-bearing: it must come **before** `BottomNavigationBar` in the `ZStack` (it already does, since `BottomNavigationBar` is declared later at line 65) so the nav bar keeps winning hit-testing for its own taps via normal ZStack front-to-back order. `topControlsLayer`'s existing `.zIndex(TopDropdownLayout.expandedZIndex)` (1.0) independently keeps the pill/panel/profile/alerts buttons in front of the backdrop regardless of declaration order.

- [ ] **Step 3: Build**

Run: `scripts/test.sh build`
Expected: build succeeds.

- [ ] **Step 4: Manual simulator verification**

Boot the worktree simulator and run the app (`scripts/run-ios-sim.sh ensure-booted-udid`, then run `Push` from Xcode or `xcodebuild ... -destination ...` per `scripts/test.sh`'s resolved destination). With the app running:
- Tap the friend-group pill to expand the panel.
- Tap an empty area of the map (not a puck, not the panel). Expected: panel collapses, no puck detail sheet appears.
- Expand the panel again, tap a map puck. Expected: panel collapses; the puck is **not** selected (no `FriendDetailBottomSheet` — the backdrop should have swallowed that tap). This matches the "backdrop swallows first tap" design decision.
- Expand the panel again, tap the profile icon. Expected: single tap opens the profile screen directly (no need to tap twice).
- Expand the panel again, tap the alerts icon. Expected: single tap opens alerts directly.
- Expand the panel again, tap a bottom-nav item (e.g. Pushes). Expected: single tap navigates directly.

- [ ] **Step 5: Commit**

```bash
git add Push/ContentView.swift
git commit -m "feat: add outside-tap-to-dismiss for friend-group dropdown

Mirrors the create-action menu's existing backdrop pattern — tapping
the map while the panel is open now closes it instead of doing
nothing."
```

---

### Task 3: Scroll-safe panel

**Files:**
- Modify: `Push/ContentView.swift:336-360` (`FriendGroupDropdownPanel`), `Push/ContentView.swift:433-449` (`TopDropdownLayout`, after Task 1's edits).

**Interfaces:**
- Consumes: `TopDropdownLayout.panelMaxHeight` (new constant this task adds).
- Produces: `FriendGroupDropdownPanel` now scrolls internally past its max height. No signature changes — `items`/`selectedID`/`select` stay the same.

- [ ] **Step 1: Add the `panelMaxHeight` constant**

In `TopDropdownLayout` (post-Task-1 version), add a new constant next to `panelWidth`:

```swift
    static func panelWidth(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 196, standard: 208, large: 218) }
    /// Caps the panel at ~5 visible rows before it scrolls; eyeballed against
    /// current row metrics, same convention as `overlayHeight`/`dropdownHeight`.
    static let panelMaxHeight: CGFloat = 240
```

- [ ] **Step 2: Wrap the row `VStack` in a capped `ScrollView`**

Change `FriendGroupDropdownPanel.body` from:

```swift
    var body: some View {
        VStack(spacing: TopDropdownLayout.rowSpacing) {
            ForEach(items) { item in
                Button {
                    select(item)
                } label: {
                    FriendGroupDropdownRow(
                        item: item,
                        isSelected: selectedID == item.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(TopDropdownLayout.panelPadding)
        .frame(width: TopDropdownLayout.panelWidth(layout))
        .topControlBackground(cornerRadius: TopDropdownLayout.panelCornerRadius)
    }
```

to:

```swift
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: TopDropdownLayout.rowSpacing) {
                ForEach(items) { item in
                    Button {
                        select(item)
                    } label: {
                        FriendGroupDropdownRow(
                            item: item,
                            isSelected: selectedID == item.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(TopDropdownLayout.panelPadding)
        }
        .frame(width: TopDropdownLayout.panelWidth(layout))
        .frame(maxHeight: TopDropdownLayout.panelMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .topControlBackground(cornerRadius: TopDropdownLayout.panelCornerRadius)
    }
```

`.fixedSize(horizontal: false, vertical: true)` lets the `ScrollView` size itself to its content's natural height (so a 2-row panel stays short) while `.frame(maxHeight:)` still caps it once content exceeds that — without this, a `ScrollView` wrapped only in `.frame(maxHeight:)` would greedily expand to fill available space even for a short list.

- [ ] **Step 3: Build**

Run: `scripts/test.sh build`
Expected: build succeeds.

- [ ] **Step 4: Manual simulator verification — short list (regression check)**

With the app's default mock data (a small number of friend groups), expand the panel. Expected: panel height still hugs its content (2-4 rows), same visual size as before this change — no empty scroll space, no visual regression.

- [ ] **Step 5: Manual simulator verification — overflow**

Temporarily add extra items for a manual check only (do not commit this): in `MapViewModel`, find the `filters =` assignment (search `grep -n "filters = \[.allFriends\]" Push/MapViewModel.swift`) and temporarily append several synthetic entries, e.g.:
```swift
filters = [.allFriends] + groupList.map { GroupFilterItem(id: $0.id, title: $0.name) } + (1...10).map { GroupFilterItem(id: "test-\($0)", title: "Test Group \($0)") }
```
Rebuild and run. Expected: panel stops growing at `panelMaxHeight`, and the row list scrolls internally to reach the extra items. Adjust `panelMaxHeight` up/down by eye if 5 rows doesn't look right at the current row height, then revert this temporary `MapViewModel` edit (`git checkout -- Push/MapViewModel.swift`) before committing — it must not ship.

- [ ] **Step 6: Commit**

```bash
git add Push/ContentView.swift
git commit -m "feat: cap friend-group panel height and make it scroll

Panel VStack was unbounded; a user in many friend groups could grow
it past the map/bottom nav. Caps at ~5 rows, scrolls beyond that."
```

---

### Task 4: Accessibility polish

**Files:**
- Modify: `Push/DesignSystem/Components/Selectors/PushSingleSelectRow.swift`
- Modify: `Push/ContentView.swift:305-334` (`FriendGroupDropdownButton`)

**Interfaces:**
- Consumes: existing `PushSingleSelectRow(title:isSelected:)` and `FriendGroupDropdownButton(selectedTitle:isExpanded:action:)` — no signature changes.
- Produces: nothing new consumed by later tasks (this is the last task).

- [ ] **Step 1: Add accessibility traits to `PushSingleSelectRow`**

Change the end of `PushSingleSelectRow.body` from:

```swift
        .padding(.horizontal, PushSingleSelectRowMetrics.horizontalPadding)
        .padding(.vertical, PushSingleSelectRowMetrics.verticalPadding)
        .background {
            if isSelected {
                Capsule().fill(PushControlColors.activeFill)
            }
        }
    }
}
```

to:

```swift
        .padding(.horizontal, PushSingleSelectRowMetrics.horizontalPadding)
        .padding(.vertical, PushSingleSelectRowMetrics.verticalPadding)
        .background {
            if isSelected {
                Capsule().fill(PushControlColors.activeFill)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

And hide the checkmark glyph from the accessibility tree — since selection is now conveyed by the `.isSelected` trait, the glyph would otherwise be announced as a redundant second element before `.combine` merges it in (VoiceOver would read "Michigan, checkmark" instead of just "Michigan, selected"). Change:

```swift
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: PushSingleSelectRowMetrics.checkmarkSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
```

to:

```swift
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: PushSingleSelectRowMetrics.checkmarkSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .accessibilityHidden(true)
            }
```

- [ ] **Step 2: Add an expand/collapse hint to `FriendGroupDropdownButton`**

Change:

```swift
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("Friend group")
        .accessibilityValue(selectedTitle)
    }
}
```

to:

```swift
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("Friend group")
        .accessibilityValue(selectedTitle)
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }
}
```

- [ ] **Step 3: Build**

Run: `scripts/test.sh build`
Expected: build succeeds.

- [ ] **Step 4: Manual VoiceOver verification**

In the simulator, enable VoiceOver (Settings → Accessibility → VoiceOver, or `xcrun simctl` doesn't toggle this — use the Simulator's Accessibility Inspector, or enable via device Settings app inside the simulator). Swipe to the friend-group pill. Expected: announces "Friend group, All Friends" (or current selection) followed by the hint "Double tap to expand" (or "collapse" if already open). Expand the panel and swipe to a row. Expected: each row announces its title once, and the currently selected row's announcement includes "selected" — no duplicate "checkmark" announcement.

- [ ] **Step 5: Commit**

```bash
git add Push/DesignSystem/Components/Selectors/PushSingleSelectRow.swift Push/ContentView.swift
git commit -m "feat: add VoiceOver traits to friend-group dropdown

PushSingleSelectRow rows now expose .isSelected via trait instead of
a redundant checkmark announcement; the collapsed pill announces
whether it will expand or collapse."
```

---

### Task 5: Full regression pass

**Files:** none (verification only).

**Interfaces:** none.

- [ ] **Step 1: Full build**

Run: `scripts/test.sh build`
Expected: succeeds.

- [ ] **Step 2: Run the existing data-layer suite**

Run: `scripts/test.sh suite DataLayerTests`
Expected: all pass, including the `selectedFilterID` filtering tests (`PushTests/DataLayerTests.swift:128,130`) — confirms Tasks 1-4 didn't touch `MapViewModel` filtering behavior.

- [ ] **Step 3: End-to-end manual pass in the simulator**

Repeat the Task 2 and Task 3 manual checks together in one session: expand/collapse via pill tap, outside-tap dismiss (with and without a puck underneath), single-tap-through on profile/alerts/bottom-nav while expanded, scroll behavior with the temporary extra-groups check (revert after), and a VoiceOver pass over the pill and a couple of rows. Confirm no visual regression versus a `git stash`-compared baseline screenshot of the collapsed pill and expanded panel (colors, glass treatment, corner radii, spacing should look identical to before this branch).

- [ ] **Step 4: Update `tasks/todo.md`**

Add a completed entry documenting this work, following the existing format in the file (see the `Issue #84` / `Issue #83` sections at the top):

```markdown
# Issue #91 — Polish the Friend-Group Filter Dropdown

## Status

- [x] Design spec approved
- [x] Implementation plan
- [x] Outside-tap-to-dismiss backdrop
- [x] Dead layout constants removed
- [x] Scroll-safe panel (~5 rows, then scrolls)
- [x] Accessibility traits (row selection, pill expand/collapse hint)

## Done

See `docs/superpowers/specs/2026-07-24-friend-group-dropdown-polish-design.md`
and `docs/superpowers/plans/2026-07-24-friend-group-dropdown-polish.md`.

---
```
Insert this above the existing top entry in `tasks/todo.md`.

- [ ] **Step 5: Commit**

```bash
git add tasks/todo.md
git commit -m "docs: mark Issue #91 friend-group dropdown polish complete"
```
