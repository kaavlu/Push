# Your Push Card — Design Spec
_2026-07-03_

## Goal

Replace the generic `ActivePlanCard` used in the "Your Pushes" module with a distinct `YourPushCard` that feels ownership-oriented and manageable, while staying warm, compact, and native to the existing Pushes screen aesthetic.

---

## Layout

Two-zone card with `pushGlassBackground(cornerRadius: 26)`:

```
┌──────────────────────────────────────────────┐
│  Gym later               ┌───────────────┐   │
│  (headline semibold,     │  ~7:45 PM     │   │
│   textEspresso)          └───────────────┘   │
│                                              │
│  Exec · Crunch Fitness                       │
│                                              │
│ · · · · · · · · · · · · · · · · · · · · · · │
│                                              │
│  Joined:                                     │
│  ◉  ◉  ◉  ◉  +2                            │
│                                              │
│  4 going                  Manage →           │
└──────────────────────────────────────────────┘
```

### Zone 1 — Info (above divider)
- **Row 1:** push title (`.headline.weight(.semibold)`, `textEspresso`) left; time chip right
- **Row 2:** `"\(group) · \(locationHint)"` (`.subheadline.weight(.medium)`, `textSecondary`)

### Divider
`walnut.opacity(0.12)` — same token as `ActivePlanCard`

### Zone 2 — Social + Footer (below divider)
- **Label:** `"Joined:"` (`.caption.weight(.medium)`, `textTertiary`)
- **Avatar row:** horizontal `HStack`, 28 pt circles, 6 pt spacing, no overlap. `ProfilePhotoAvatar` for each participant. White stroke border (0.8 pt). Max 4 shown; overflow rendered as `"+N"` circle (same size, sunbeam fill, walnut text).
- **Footer row:** `"N going"` (`.footnote`, `textSecondary`) left; `"Manage →"` (`.footnote.weight(.semibold)`, `textPrimary`) right

### Time chip
Walnut outline pill — no fill, `.stroke(walnut.opacity(0.40))`, text `.caption.weight(.semibold)`, `textPrimary`. Horizontal padding 8 pt, vertical 4 pt.

---

## Model Changes

Add to `PlanData`:
```swift
let participants: [HangoutPerson]   // empty for non-owned plans
```

Populate with mock participants for the two owned plans in `PlansMockData`:
- `"gym-later"`: 4 participants (chitty, ishan, viplove, ram) → shows 4 + "+0" (no overflow if exactly 4)
- `"drinks-friday"`: 2 participants (rohan, ryan)

`socialProof` continues to drive the "N going" footer text.

---

## New Files

| File | Purpose |
|---|---|
| `Push/YourPushCard.swift` | Card view + sub-components (`YourPushTimeChip`, `YourPushAvatarRow`) |
| `Push/ManagePushView.swift` | Placeholder full-screen cover |

## Modified Files

| File | Change |
|---|---|
| `Push/PlansModels.swift` | Add `participants: [HangoutPerson]` to `PlanData`; update mock data |
| `Push/PlansStyle.swift` | Add `YourPushCardLayout` constants |
| `Push/PlansView.swift` | Wire `YourPushesModule` to use `YourPushCard`; add `ManagePushView` cover |
| `Push/PlansViewModel.swift` | Add `isManagePushPresented: Bool` |

---

## Constraints

- No large filled "Manage" button — text CTA only
- No overlapping avatars (unlike `AvatarStack` which overlaps)
- `ManagePushView` is a placeholder — no real content
- All colors stay within `PushControlColors` / `PushColorPalette` tokens
- File stays under 400 lines; sub-components split if needed
