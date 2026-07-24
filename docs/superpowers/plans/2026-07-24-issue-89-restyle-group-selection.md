# Restyle Group/Friend Selection Cards (Start Push Step 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle `GroupSelectCard` and `FriendSelectRow` in `Push/StartPushStep1View.swift` onto the app's standard cream-card surface with a correctly-layered selected-state tint, matching the convention already used in `AddGroupStep2MembersView` and `GroupDetailSheets`.

**Architecture:** Pure SwiftUI view/token restyle, one existing file (`Push/StartPushStyle.swift`) gets three token additions, one existing file (`Push/StartPushStep1View.swift`) gets a new private `SelectableCardSurface` helper view plus two rewired `.background` call sites. No ViewModel, model, or data-flow changes.

**Tech Stack:** Swift, SwiftUI, iOS 17+, existing `Push` Xcode project (no new dependencies).

## Global Constraints

- Files ≤ 400 lines; functions ≤ 40 lines, single responsibility (CLAUDE.md coding standards). `StartPushStep1View.swift` is currently 303 lines — adding one small helper struct keeps it well under the limit.
- No magic numbers — reuse existing `PushCreamTokens` / `StartPushColor` tokens; new tokens go in `StartPushColor`.
- No new cross-file DesignSystem component — `SelectableCardSurface` stays private and scoped to `StartPushStep1View.swift` (explicit spec decision).
- Do not touch `AddGroupStep2MembersView.swift` or `GroupDetailSheets.swift` — out of scope for this issue.
- Build verification command: `scripts/test.sh build` (compiles `Push` for generic iOS Simulator; no test target needed for this pure-styling change).
- Manual verification command: `scripts/run-ios-sim.sh run` (builds + installs + launches on the worktree-labeled simulator).

---

### Task 1: Add selection tokens to `StartPushColor`

**Files:**
- Modify: `Push/StartPushStyle.swift:83-90`

**Interfaces:**
- Produces: `StartPushColor.selectedTintOpacity: Double`, `StartPushColor.selectedStrokeWidth: CGFloat`. `StartPushColor.selectedStrokeOpacity` value changes from `0.3` to `0.5` (same name/type, existing consumer in Task 2 is being rewritten in this same plan).

- [ ] **Step 1: Edit the `StartPushColor` enum**

Current code at `Push/StartPushStyle.swift:83-90`:

```swift
enum StartPushColor {
    static let rowFillOpacity = 0.28
    static let selectedStrokeOpacity = 0.3
    static let textEditorFill = 0.24
    static let textEditorStrokeOpacity = 0.18
    static let pillSelectedStrokeOpacity = 0.3
    static let avatarOverlayStroke: CGFloat = 1.5
}
```

Replace with:

```swift
enum StartPushColor {
    static let rowFillOpacity = 0.28
    static let selectedTintOpacity = 0.14
    static let selectedStrokeOpacity = 0.5
    static let selectedStrokeWidth: CGFloat = 1.5
    static let textEditorFill = 0.24
    static let textEditorStrokeOpacity = 0.18
    static let pillSelectedStrokeOpacity = 0.3
    static let avatarOverlayStroke: CGFloat = 1.5
}
```

- [ ] **Step 2: Verify the project builds**

Run: `scripts/test.sh build`
Expected: `** BUILD SUCCEEDED **`. (`selectedStrokeOpacity`'s only consumer, `GroupSelectCard`, still compiles unchanged until Task 2 — this step just confirms the token edit alone doesn't break anything.)

- [ ] **Step 3: Commit**

```bash
git add Push/StartPushStyle.swift
git commit -m "$(cat <<'EOF'
Add selection tint/stroke tokens to StartPushColor

EOF
)"
```

---

### Task 2: Add `SelectableCardSurface` and rewire `GroupSelectCard`

**Files:**
- Modify: `Push/StartPushStep1View.swift:158-216`

**Interfaces:**
- Consumes: `StartPushColor.selectedTintOpacity`, `StartPushColor.selectedStrokeOpacity`, `StartPushColor.selectedStrokeWidth`, `StartPushColor.avatarOverlayStroke` (Task 1). `PushCreamTokens.solidCard`, `PushCreamTokens.solidCardStrokeOpacity`, `PushCreamTokens.solidCardStrokeWidth` (existing, `Push/DesignSystem/Surfaces/PushCreamSurfaces.swift`). `PushControlColors.activeFill`, `PushControlColors.activeForeground`, `PushControlColors.textEspresso`, `PushControlColors.textTertiary` (existing, `Push/PushGlassStyle.swift`).
- Produces: `private struct SelectableCardSurface: View` with `init(cornerRadius: CGFloat, isSelected: Bool)` — consumed by Task 3 as well.

- [ ] **Step 1: Replace the `GroupSelectCard` struct and add `SelectableCardSurface` above it**

Current code at `Push/StartPushStep1View.swift:158-216`:

```swift
private struct GroupSelectCard: View {
    @Environment(\.pushLayout) private var layout
    let item: PushRecipientItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    RecipientAvatarView(
                        imageAssetName: item.imageAssetName,
                        initials: item.initials,
                        size: StartPushLayout.groupAvatarSize(layout)
                    )
                    if isSelected { checkmark }
                }
                Text(item.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.textEspresso)
                    .lineLimit(1)
                if let count = item.memberCount {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: StartPushLayout.memberCountIconSize))
                        Text("\(count)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(PushControlColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: StartPushLayout.groupCardHeight(layout))
            .background(
                RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                    .fill(isSelected ? PushControlColors.activeFill : .white.opacity(StartPushColor.rowFillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                    .stroke(
                        isSelected ? PushColorPalette.Accent.walnut.opacity(StartPushColor.selectedStrokeOpacity) : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: StartPushLayout.groupCheckmarkSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .background(Circle().fill(.white))
            .offset(x: StartPushLayout.groupCardCheckOffset, y: StartPushLayout.groupCardCheckOffset)
    }
}
```

Replace with:

```swift
/// Shared cream card fill/tint/stroke for step 1's group and friend
/// selection cells. File-scoped — not a cross-file DS component (see
/// docs/superpowers/specs/2026-07-24-issue-89-restyle-group-selection-design.md).
private struct SelectableCardSurface: View {
    let cornerRadius: CGFloat
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(PushCreamTokens.solidCard)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(PushControlColors.activeFill.opacity(StartPushColor.selectedTintOpacity))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected
                            ? PushControlColors.activeFill.opacity(StartPushColor.selectedStrokeOpacity)
                            : PushColorPalette.Accent.walnut.opacity(PushCreamTokens.solidCardStrokeOpacity),
                        lineWidth: isSelected
                            ? StartPushColor.selectedStrokeWidth
                            : PushCreamTokens.solidCardStrokeWidth
                    )
            }
    }
}

private struct GroupSelectCard: View {
    @Environment(\.pushLayout) private var layout
    let item: PushRecipientItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    RecipientAvatarView(
                        imageAssetName: item.imageAssetName,
                        initials: item.initials,
                        size: StartPushLayout.groupAvatarSize(layout)
                    )
                    if isSelected { checkmark }
                }
                Text(item.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(1)
                if let count = item.memberCount {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: StartPushLayout.memberCountIconSize))
                        Text("\(count)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(PushControlColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: StartPushLayout.groupCardHeight(layout))
            .background(
                SelectableCardSurface(
                    cornerRadius: StartPushLayout.cardCornerRadius(layout),
                    isSelected: isSelected
                )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: StartPushLayout.groupCheckmarkSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .background(Circle().fill(.white))
            .overlay(
                Circle().stroke(PushControlColors.activeFill, lineWidth: StartPushColor.avatarOverlayStroke)
            )
            .offset(x: StartPushLayout.groupCardCheckOffset, y: StartPushLayout.groupCardCheckOffset)
    }
}
```

- [ ] **Step 2: Verify the project builds**

Run: `scripts/test.sh build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Push/StartPushStep1View.swift
git commit -m "$(cat <<'EOF'
Restyle GroupSelectCard onto cream card surface

EOF
)"
```

---

### Task 3: Rewire `FriendSelectRow` onto `SelectableCardSurface`

**Files:**
- Modify: `Push/StartPushStep1View.swift` (line numbers shifted by Task 2's insertion — locate by the `private struct FriendSelectRow` declaration, immediately after `GroupSelectCard`)

**Interfaces:**
- Consumes: `SelectableCardSurface(cornerRadius:isSelected:)` (Task 2).

- [ ] **Step 1: Replace `FriendSelectRow`'s background**

Current code (the `FriendSelectRow` struct, unchanged by Task 2):

```swift
private struct FriendSelectRow: View {
    let item: PushRecipientItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RecipientAvatarView(
                    imageAssetName: item.imageAssetName,
                    initials: item.initials,
                    size: StartPushLayout.friendRowAvatarSize
                )
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                Spacer(minLength: 0)
                selectionIndicator
            }
            .padding(.horizontal, StartPushLayout.rowHorizontalPadding)
            .padding(.vertical, StartPushLayout.rowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: StartPushLayout.rowCornerRadius, style: .continuous)
                    .fill(isSelected ? PushControlColors.activeFill : .white.opacity(StartPushColor.rowFillOpacity))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: StartPushLayout.selectionCircleSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
        } else {
            Image(systemName: "circle")
                .font(.system(size: StartPushLayout.selectionCircleSize, weight: .regular))
                .foregroundStyle(PushControlColors.textTertiary)
        }
    }
}
```

Replace only the `.background(...)` block inside `body` with:

```swift
            .background(
                SelectableCardSurface(
                    cornerRadius: StartPushLayout.rowCornerRadius,
                    isSelected: isSelected
                )
            )
```

(Everything else in `FriendSelectRow` — including `selectionIndicator` — stays exactly as-is.)

- [ ] **Step 2: Verify the project builds**

Run: `scripts/test.sh build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Push/StartPushStep1View.swift
git commit -m "$(cat <<'EOF'
Restyle FriendSelectRow onto cream card surface

EOF
)"
```

---

### Task 4: Manual verification in simulator

**Files:** None (no code changes — verification only).

**Interfaces:** None.

- [ ] **Step 1: Launch the app on the worktree simulator**

Run: `scripts/run-ios-sim.sh run`
Expected: Build succeeds, app installs and launches on the worktree-labeled simulator (e.g. `Push - <worktree> - iPhone 17`).

- [ ] **Step 2: Navigate to Start Push step 1**

In the running app (mock data, DEBUG build): open the map create menu or Pushes tab → Start Push. Land on step 1 ("Who's this for?"), which shows the Groups grid and Friends list from `StartPushStep1View`.

- [ ] **Step 3: Check unselected state**

Confirm both `GroupSelectCard` tiles and `FriendSelectRow` rows render an opaque cream fill with a subtle walnut hairline border (no more raw translucent white fill, no borderless look).

- [ ] **Step 4: Check selected state**

Tap a group tile and a friend row. Confirm both show: the cream base still visible, a visible soft sunbeam tint over it, a stronger sunbeam/walnut stroke ring, and the checkmark indicator (corner badge with a stroke ring on the group tile; trailing `checkmark.circle.fill` on the friend row). Tap again to deselect and confirm it reverts cleanly.

- [ ] **Step 5: Spot-check appearance modes**

Toggle the simulator between light and dark appearance (Settings app or `xcrun simctl ui <udid> appearance dark|light`) and re-check steps 3–4 still read clearly in both.

- [ ] **Step 6: Report result**

No commit for this task (verification only). If any visual issue is found, fix it in the relevant file from Task 2/3 and re-run this task's steps before proceeding.
