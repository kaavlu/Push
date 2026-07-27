# Restyle group/friend selection cards on Start Push step 1 (Issue #89)

## Problem

`Push/StartPushStep1View.swift` — `groupSection` → private `GroupSelectCard`,
shown in step 1 ("Who's this for?") of `StartPushFlowView`. Selected state
fills the whole card with `PushControlColors.activeFill`; unselected state
uses a raw `.white.opacity(StartPushColor.rowFillOpacity)` fill — no
glass/cream card surface. The selected checkmark is a bespoke
`checkmark.circle.fill` badge on a plain white circle, offset into the
avatar's corner, rather than a shared DS treatment.

The adjacent `FriendSelectRow` in the same step has the same ad hoc
`.white.opacity` fill and full-fill selected state — confirmed in scope too.

This bypasses the catalog surfaces called out in `docs/design-system.md`
(`pushSolidCreamCard`) that the rest of the app uses for cards (e.g.
`PushHistoryRow`, `PushPersonRow` use `.pushSolidCreamCard`). Avatars already
route through `RecipientAvatarView` → `PushPersonAvatar` (sunbeam fallback),
so that part of the original issue text is already satisfied and out of
scope for this change.

## Existing convention this restyle should match

Two other friend/member-picker flows already solved this same problem:
`AddGroupStep2MembersView` (Add Group step 2) and `GroupDetailSheets`
(invite/transfer sheets). Both use: a solid cream card base
(`pushSolidCreamCard` via `FriendRowCard`) + a light `PushControlColors
.activeFill` tint/stroke overlay when selected + a trailing
`checkmark.circle.fill` / `circle` indicator. `FriendSelectRow`'s
`selectionIndicator` already matches this exactly — only its card
*background* is out of step.

**Bug found in the existing convention, and how this change handles it:**
In both existing call sites, the "selected tint" is added via
`.background { tint }` chained *after* `FriendRowCard`, which already paints
its own **opaque** cream fill across the full row. In SwiftUI, an opaque
view fully hides anything drawn behind it, so that tint fill never actually
renders on screen today — only the stroke ring (`.overlay`, drawn on top)
and the checkmark are visible. This change fixes the layering **for step 1
only** (compose fill + tint in one background layer, correct z-order, so the
tint genuinely renders). `AddGroupStep2MembersView` and `GroupDetailSheets`
are left untouched — out of scope for issue #89.

## Scope

`Push/StartPushStep1View.swift` only:
- Private `GroupSelectCard` (grid tile, shown in `groupSection`)
- Private `FriendSelectRow` (list row, shown in `friendSection`)
- `StartPushColor` enum (in `Push/StartPushStyle.swift`) — token changes only

Pure view/token restyle. No `StartPushViewModel` or data-flow changes.

## Design

### New file-scoped helper: `SelectableCardSurface`

A private `View` added to `StartPushStep1View.swift`, used as the
`.background` for both `GroupSelectCard` and `FriendSelectRow`, so the same
~15-line fill/tint/stroke block isn't duplicated twice in one file. Not a
new cross-file DesignSystem component — scoped to this file only.

```swift
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
```

Both fill and stroke reuse the existing `PushCreamTokens` values that back
`pushSolidCreamCard`, rather than introducing new magic numbers for the
unselected state.

### `StartPushColor` token changes (`Push/StartPushStyle.swift`)

- `selectedStrokeOpacity`: repurpose existing token, `0.3` → `0.5`. Its only
  current consumer is the `GroupSelectCard` stroke being rewritten here, so
  this is safe.
- Add `selectedTintOpacity = 0.14`.
- Add `selectedStrokeWidth: CGFloat = 1.5`.

Values match `AddGroupStep2Color`/`GroupDetailManageColor` in the other two
picker flows, for cross-flow visual consistency.

### `GroupSelectCard`

- Background: `.background(SelectableCardSurface(cornerRadius:
  StartPushLayout.cardCornerRadius(layout), isSelected: isSelected))`,
  replacing the current `.background` + `.overlay` pair.
- Name text: always `PushControlColors.textEspresso` — drop the `isSelected
  ? activeForeground : textEspresso` ternary. Matches how other cream-card
  rows in the app (`PushPersonRow`) render identity text regardless of
  selection; the tint/stroke/checkmark already carry the selected state.
- Member-count text: unchanged (`textTertiary`).
- Checkmark badge: unchanged position/size/icon. Adds a stroke ring —
  `Circle().stroke(PushControlColors.activeFill, lineWidth:
  StartPushColor.avatarOverlayStroke)` — reusing the existing
  `avatarOverlayStroke` token (already defined, used elsewhere in this file
  for an avatar ring) rather than introducing a new one. Same fill+stroke
  recipe as `ProfileComponents`' avatar edit badge (`ProfileBadge`).

### `FriendSelectRow`

- Background: `.background(SelectableCardSurface(cornerRadius:
  StartPushLayout.rowCornerRadius, isSelected: isSelected))`, replacing the
  current single `.background` fill.
- `selectionIndicator` (`checkmark.circle.fill` / `circle`): unchanged — it
  already matches the established convention exactly.
- Name text: unchanged (already fixed `textEspresso`).

## Out of scope

- `AddGroupStep2MembersView.swift`, `GroupDetailSheets.swift` — the
  invisible-tint layering bug found in their existing pattern is left as-is.
- Any change to `StartPushViewModel`, recipient selection logic, or other
  Start Push steps (2–4).
- Extracting a shared cross-file DesignSystem selection-card component —
  considered and explicitly deferred; `SelectableCardSurface` stays local to
  `StartPushStep1View.swift`.

## Testing

Manual only (pure UI restyle, no new logic):
- Build and run Start Push step 1 in the simulator (mock data has multiple
  groups and friends).
- Toggle selection on grid tiles (`GroupSelectCard`) and rows
  (`FriendSelectRow`); confirm cream base, visible tint, stroke, and
  checkmark all render correctly in both states.
- Confirm existing `#if DEBUG` SwiftUI previews in the touched file (if any)
  still compile.
- Spot-check light/dark appearance.
