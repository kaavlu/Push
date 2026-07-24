# Push — Theme Audit

> **Read-only historical snapshot** (pre–design-system interview).  
> **Do not implement from this file.** For current UI rules use:
>
> - **`docs/design-system.md`** — agent catalog (when-to-use / do-not-recreate)
> - **`tasks/design-system-decision-log.md`** — DS-001–DS-089 product law
> - **`Push/DesignSystem/`** — live code
>
> Where this audit conflicts with decisions or the catalog (e.g. “three glass implementations,”
> cream scatter), the **design system has centralized** those concerns. Issues flagged below
> that are now resolved in `Push/DesignSystem/` should not be re-opened as new local forks.

_A consolidated audit of every visual/theme decision discovered in the codebase, with the
source file for each. This is an extraction only — **no inconsistencies were fixed in the
audit pass.** Known inconsistencies are flagged at the bottom (many later addressed by Issue #63)._

Paths are relative to the repo root. Where a value lives in a copied file, the same file is
in `CoreDesignFiles/`.

---

## 1. Color System

### 1.1 Brand accent palette
Source: `Push/PushColorPalette.swift`

| Token | Value | Notes |
|---|---|---|
| `Accent.sunbeam` | `#FFEE8C` | Primary highlight / active fill |
| `Accent.walnut` | `#8B5B29` | Primary text & brand ink |
| `Accent.sageGreen` | `#2E7A47` | "Joined" / positive |
| `Accent.mintFoam` | `#C7F0D6` | Soft positive fill |

Colors are built from hex via a private `Color(hex:opacity:)` extension in the same file.

### 1.2 Text hierarchy (walnut-based, no black)
Source: `Push/PushGlassStyle.swift` → `PushControlColors`

| Token | Value |
|---|---|
| `textEspresso` | `rgb(0.22, 0.12, 0.05)` — names/titles |
| `textPrimary` | `walnut` |
| `textSecondary` | `walnut @ 0.70` |
| `textTertiary` | `walnut @ 0.52` |
| `activeForeground` | `walnut` |
| `inactiveForeground` | `walnut @ 0.70` |
| `activeFill` | `sunbeam @ 1.0` |

### 1.3 Cream / background family
Source: `Push/PlansStyle.swift` → `PlansColor`

| Token | Value |
|---|---|
| `creamBase` | `rgb(1.00, 0.96, 0.87)` ≈ `#FFF5DE` |
| `creamSoft` | `rgb(0.98, 0.91, 0.78)` ≈ `#FAE8C7` |
| `metadata` | `rgb(0.43, 0.29, 0.17)` |
| `metadataSecondary` | `rgb(0.55, 0.43, 0.31)` |
| `metadataTertiary` | `rgb(0.68, 0.58, 0.47)` |
| `cleanCardFill` | `creamBase @ 0.42` |
| `warmCardTint` | `sunbeam @ 0.10` |
| `glassStroke` | `creamBase @ 0.74` |
| `innerGlassStroke` | `white @ 0.46` |
| `cardShadow` | `walnut @ 0.14` |
| `primaryGlow` | `sunbeam @ 0.32` |
| Page bg (top/mid/bottom) | `creamSoft@0.54` / `creamBase@0.68` / `walnut@0.11` |

### 1.4 Availability / puck state colors
Source: `Push/FriendPuckStyle.swift` → `PuckColorTokens` + `FriendAvailabilityState` extensions

| State | Accent color |
|---|---|
| `freeNow` | `rgb(0.43, 0.91, 0.62)` green |
| `maybeDown` / `freeSoon` | `rgb(1.00, 0.78, 0.24)` amber |
| `busy` | `rgb(1.00, 0.50, 0.25)` orange |
| `joinable` | `rgb(0.25, 0.55, 1.00)` blue |
| `driving` | `rgb(0.22, 0.88, 1.00)` cyan |
| `unavailable` | `rgb(0.55, 0.58, 0.64)` gray |
| `avatarGradientBase` (fallback) | `rgb(0.18, 0.15, 0.22)` deep plum |

Chip fill/text colors per state are also defined here (`chipFillColor`, `chipTextColor`),
e.g. freeNow text `rgb(0.04,0.30,0.16)`, busy text `rgb(0.52,0.15,0.02)`, driving text
`rgb(0.02,0.30,0.42)`.

### 1.5 Asset catalog colors
Source: `Push/Assets.xcassets/AccentColor.colorset/Contents.json`

- `AccentColor` is **empty / unspecified** (falls back to system) — the app drives color
  through code tokens, not the asset catalog. Flagged below.

---

## 2. Gradients

| Gradient | Colors / stops | Source |
|---|---|---|
| **Modal background** (`PushModalBackground`) | `sunbeam@0.62` → `white` → `walnut@0.18`, topLeading→bottomTrailing | `Push/ProfileStyle.swift` |
| **Friend detail sheet bg** | `sunbeam@0.38 (0.0)` → `sunbeam@0.08 (0.25)` → `walnut@0.08 (1.0)` | `Push/FriendDetailSheet.swift:81` |
| **Group fallback tile** | `activeFill(sunbeam)@top` → `white@bottom`, topLeading→bottomTrailing | `Push/GroupsView.swift:176`, `Push/GroupDetailView.swift:135` |
| **Weekly recap day tiles** | cream/sunbeam/walnut multi-stop; per-state `tileBackgroundColors`, `glowGradient`, `heatBarGradient` | `Push/PlansWeeklyRecapDayTile.swift:67,150,207` |
| **Start Push step-1 fade** | `.clear` → `white@0.92` (scrim) | `Push/StartPushStep1View.swift:38` |

---

## 3. Glass / Blur / Material Surfaces

The brand's signature. Three related implementations exist (flagged as duplication below).

### 3.1 `pushGlassBackground` / `pushMaterialBackground`
Source: `Push/PushGlassStyle.swift`
- iOS 26+: native `.glassEffect(.regular, in: RoundedRectangle(...))`.
- Fallback: layered `ultraThinMaterial` + `regularMaterial@0.68` + warm tint + stroke + shadow.
- Tokens (`PushGlassStyle`):
  - `materialPresenceOpacity` `0.68`
  - `warmTint` `rgb(1.0, 0.95, 0.84)` @ `tintOpacity 0.22`
  - `strokeOpacity` `0.52`, `strokeWidth` `0.8` (white stroke)
  - `shadowColor` `rgb(0.55, 0.36, 0.16)` (walnut-amber) @ `shadowOpacity 0.18`
  - `shadowRadius 24`, `shadowYOffset 10`

### 3.2 `plansGlassCard`
Source: `Push/PlansStyle.swift`
- `ultraThinMaterial` + `cleanCardFill` + `warmCardTint` + **double stroke** (glassStroke +
  inner white@0.46 inset 1) + shadow `cardShadow` radius 20 y 10.

### 3.3 `puckGlassBackground`
Source: `Push/FriendPuckStyle.swift`
- `ultraThinMaterial` + `white@0.16` tint + `white@0.64` stroke (width `0.9`).

### 3.4 Ad-hoc material chips
- `ActivityBadge`: `ultraThinMaterial` capsule + accent tint `@0.48` + white stroke `@0.7`.
  Source: `Push/ActivityBadge.swift`
- Bottom-nav primary button: `ultraThinMaterial` circle + `white@tintOpacity`.
  Source: `Push/BottomNavigationBar.swift`

---

## 4. Shadows

| Usage | Color | Opacity | Radius | Y |
|---|---|---|---|---|
| Global glass | walnut-amber `rgb(0.55,0.36,0.16)` | 0.18 | 24 | 10 | (`PushGlassStyle`) |
| Plans cards | `walnut` | 0.14 | 20 | 10 | (`PlansColor.cardShadow`) |
| Puck status glow | state accent | 0.36 | 14→22 (pulsing) | 6 | (`FriendPuckLayout`) |
| Nav primary glow | `activeForeground@0.34` | — | 10 | 3 | (`BottomNavigationLayout`) |
| Profile avatar | `avatarShadowOpacity 0.18` | — | 18 | 8 | (`ProfileLayout`) |

**Principle:** shadows are warm walnut/amber or the element's own accent — **never black.**

---

## 5. Corner Radii

| Value | Where | Source |
|---|---|---|
| 32 | Bottom-nav container, individual sheet | `BottomNavigationLayout`, `FriendDetailSheetLayout.sheetCornerRadius` |
| 26 | Cards (Plans, Start Push, Profile), calendar | `PlansLayout`, `StartPushLayout`, `ProfileLayout` |
| 22 | Pills, toast | `StartPushLayout.pillCornerRadius`, `FriendDetailSheetLayout.toastCornerRadius` |
| 20 | Status/action cards | `FriendDetailSheetLayout`, `StartPushLayout.rowCornerRadius` (18) |
| 18 | Rows | `ProfileLayout.rowCornerRadius`, `StartPushLayout` |
| 16 | Fields, group action buttons | `ProfileLayout.fieldCornerRadius`, `FriendDetailSheetLayout.actionCornerRadius` |
| capsule / height÷2 | Buttons, chips, search bar, pills | throughout |

All rounded rects use `style: .continuous`.

---

## 6. Typography

Push uses **system fonts** (San Francisco) via SwiftUI text styles, with `.rounded` design
for numeric/avatar-fallback contexts.

### 6.1 Text-style usage (observed)
| Style | Typical use |
|---|---|
| `.largeTitle.weight(.bold)` | Screen titles (Groups, Group Detail) |
| `.title2.weight(.bold)` | Sheet/header titles, Start Push header |
| `.title3.weight(.bold)` | Friend detail names, group tile titles |
| `.headline.weight(.bold)` | Primary button labels, section headers |
| `.subheadline` (.semibold/.medium/.bold) | Body, metadata, rows |
| `.callout.weight(.semibold)` | Subtitles |
| `.footnote.weight(.bold/.semibold)` | Section labels (uppercased, kerned) |
| `.caption / .caption2` (.bold/.semibold) | Chips, badges, pills, tab labels |

### 6.2 `.rounded` design system font
Source: e.g. `FriendPuckStyle.swift`, `StartPushStyle.swift`, `GroupDetailView.swift`,
`ProfileComponents.swift`
- `Font.system(size:weight:design:.rounded)` used for avatar-fallback initials and large
  glyphs (5 occurrences). Sizes: avatar initials `22` (puck), `size*0.32` (recipient avatar),
  large group fallback text.

### 6.3 Letter-spacing
- `StartPushSectionLabel`: `.textCase(.uppercase)` + `.kerning(0.5)`. Source: `StartPushStyle.swift`.

No custom font files are bundled — typography is 100% system.

---

## 7. Spacing & Layout Tokens

Layout is centralized per feature in `enum *Layout` types (no magic numbers in views).
Full tables live in the source files; highlights:

- **Plans** (`PlansStyle.swift → PlansLayout`): horizontalPadding `18`, cardPadding `15`,
  cardCornerRadius `26`, pushCardHeight `188`, calendarCellSize `28`, bottomPadding `110`.
- **Start Push** (`StartPushStyle.swift → StartPushLayout`): horizontalPadding `20`,
  primaryButtonHeight `54`, cardPadding `16`, groupCard `108×94`, searchBarHeight `44`.
- **Profile** (`ProfileStyle.swift → ProfileLayout`): avatarSize `112`, cardCornerRadius `26`,
  closeButtonSize `44`, rowPadding `12`.
- **Friend detail** (`FriendDetailSheetStyle.swift → FriendDetailSheetLayout`):
  individualSheetHeight `250`, hangoutSheetHeight `336`, headerAvatarSize `62`,
  heroGroupSize `80`, statusCardCornerRadius `20`.
- **Bottom nav** (`BottomNavigationBar.swift → BottomNavigationLayout`): containerCornerRadius
  `32`, primaryButtonSize `50`, iconSize `17`, bottomMargin `22`.
- **Puck** (`FriendPuckStyle.swift → FriendPuckLayout`): defaultSize `82`, clusterSize `112`,
  statusRingWidth `3`, pulse scale `1.02→1.16` over `2.4s`.

Common paddings cluster around **8 / 12 / 14 / 16 / 18 / 20** and margins **20 / 22**.

---

## 8. Buttons, Chips, Pills, Nav

| Element | Style | Source |
|---|---|---|
| **Primary button** | Capsule, `activeFill` (sunbeam) fill, walnut label, `.headline.bold`, height 54, disabled → fill@0.45 | `StartPushStyle.swift → StartPushPrimaryButton` |
| **Plans start button** | Capsule, height 50, radius 25 | `PlansStyle.swift → PlansLayout` |
| **Status pill (Plans)** | Capsule; per-`PlanStatus` fill+text (sunbeam / mintFoam / walnut tints) | `PlansStyle.swift → PlanStatusPill` |
| **Availability chip** | Capsule; per-state `chipFillColor`/`chipTextColor` | `FriendPuckStyle.swift` |
| **Activity badge** | Material capsule + accent tint + white stroke | `ActivityBadge.swift` |
| **Group status pill** | Capsule, `activeFill@0.x` | `GroupsView.swift`, `GroupDetailView.swift` |
| **Step indicator** | Active = numbered capsule (`activeFill`), else dot (walnut@0.18/0.45) | `StartPushStyle.swift → StartPushStepIndicator` |
| **Bottom nav** | Glass pill; non-selected items walnut icon+label; selected item capsule `activeFill`; center "+" raised circular material button with glow | `BottomNavigationBar.swift` |
| **Close/back buttons** | 44pt glass circle with `xmark`/chevron | `ProfileStyle.swift`, `StartPushStyle.swift` |
| **Search bar** | Glass capsule + magnifyingglass + clear button | `StartPushStyle.swift → StartPushSearchBar` |

---

## 9. Iconography

- **100% SF Symbols** (`Image(systemName:)`). No custom icon set.
- Seen: `xmark`, `xmark.circle.fill`, `magnifyingglass`, `chevron.*`, `plus`, camera/badge,
  person/group glyphs, activity glyphs passed into `ActivityBadge`, checkmarks.
- Icon weights are typically `.semibold` / `.bold`; sizes are per-feature layout constants
  (e.g. nav `17`, primary nav `21`, badge `9`, close `14`).

---

## 10. Avatars & Imagery

- **Avatar loading:** `Push/PushImageAssets.swift` resolves an asset name via
  `UIImage(named:)`, then bundled-path lookup (e.g. `friends/ohm.png`, `groups/Michigan/…`),
  then file path. Fallback = initials on a colored circle.
- **Avatar components:** `ProfilePhotoAvatar` (`FriendPuckStyle.swift`),
  `RecipientAvatarView` (`StartPushStyle.swift`), `AvatarStack.swift` (overlapping ring
  avatars + "+N" overflow).
- **Bundled images** (copied to `Assets/BundledImages/`): friend avatars, per-group member
  avatars (Michigan / Exec / India), and `profile/manav.jpeg`.
- **Asset catalog** (`Assets.xcassets`): `UserLocationPin.png` (the user's own map pin),
  empty `AppIcon` (1024 slot, **no image supplied**), empty `AccentColor`.

---

## 11. Map Styling

Source: `Push/StyledMapView.swift` (+ `Push/ContentView.swift`)
- `MKMapView` wrapped in `UIViewRepresentable`; background set to `.clear`; custom compass
  placement (`showsCompass = false` then a manually constrained `MKCompassButton`).
- Friend pucks / cluster pucks are hosted SwiftUI annotations. User pin uses
  `UserLocationAnnotation` with `UserLocationPin` asset.
- Create-menu backdrop uses `Color.black @ backdropOpacity` (the one intentional dark scrim).

---

## Inconsistencies & Duplication (observed, NOT fixed)

1. **Three separate glass implementations** with different tints/strokes:
   `pushGlassBackground` (warm cream + walnut shadow), `plansGlassCard` (double stroke,
   different tint), `puckGlassBackground` (plain white tint). They are visually similar but
   not unified into one modifier.
2. **Cream is defined in more than one place / by literal RGB.** `PlansColor.creamBase/creamSoft`
   and `PushGlassStyle.warmTint` are all warm-cream literals that overlap conceptually but
   aren't a single shared token.
3. **Text-color tokens are split.** `PushControlColors` (walnut tiers) vs `PlansColor.metadata*`
   (independent brown tiers `0.43/0.29/0.17`, etc.) describe the same hierarchy differently.
4. **`AccentColor` and `AppIcon` asset slots are empty** — brand accent is code-only, and
   there is no shipped app icon image yet.
5. **Soft pink/purple** described in the brand direction is essentially absent from current
   tokens — a gap to fill, not an existing value.
6. **State color naming overlaps:** `freeSoon` and `maybeDown` share the amber `maybeDown`
   accent but diverge in `chipFillColor`, which can read as two subtly different ambers.
7. **Shadow radius/opacity vary per surface** (24/0.18 global vs 20/0.14 plans) without a
   shared elevation scale.

_These were documented for Claude Design's awareness at audit time. Issue #63 design-system
waves later centralized glass families, cream roles, availability tokens, and named surfaces
in `Push/DesignSystem/` — see `docs/design-system.md`. Do not reintroduce the forks listed above._
