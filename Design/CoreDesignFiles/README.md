# CoreDesignFiles — What Each File Is & Why It Matters

These are **verbatim copies** of the most design-relevant SwiftUI files from the Push app
(`Push/…`). They are here so Claude Design can read the actual implementation of the theme,
components, and screens. Nothing here has been edited. Copies are grouped below by role
(theme → components → screens → state models → mock data). Original filenames preserved.

---

## 1. Theme / Design-System Foundations (read these first)

| File | Why it matters |
|---|---|
| `PushColorPalette.swift` | The brand palette: sunbeam, walnut, sage green, mint foam. The root of every color. |
| `PushGlassStyle.swift` | The signature warm liquid-glass surface (`pushGlassBackground`), control colors, and the walnut text hierarchy. The single most important theme file. |
| `PlansStyle.swift` | Cream/background family, `plansGlassCard`, `PlanStatusPill`, and Plans layout tokens. |
| `StartPushStyle.swift` | Reusable flow primitives: primary button, step indicator, header, search bar, section label, recipient avatar + all Start Push layout tokens. |
| `ProfileStyle.swift` | `PushModalBackground` (sunbeam→white→walnut gradient), modal close bar, Profile layout/color tokens. |
| `FriendPuckStyle.swift` | Puck avatar, availability colors + per-state chip fill/text, pulsing glow modifier, `puckGlassBackground`. Defines the map's visual state language. |
| `FriendDetailSheetStyle.swift` | Layout tokens and content-string helpers for the friend/pair/group detail sheet. |
| `PushImageAssets.swift` | How avatar/image names resolve to bundled images (explains the `Assets/BundledImages` folder). |

## 2. Reusable Components

| File | Why it matters |
|---|---|
| `BottomNavigationBar.swift` | The floating glass tab bar with a raised circular "+" primary action — a signature surface. |
| `ActivityBadge.swift` | The small material capsule badge attached to pucks (activity + availability tint). |
| `AvatarStack.swift` | Overlapping ringed avatars with "+N" overflow, used across cards and sheets. |
| `FriendPuck.swift` | The single-friend map puck: avatar + availability ring + badge + glow. |
| `FriendClusterPuck.swift` | The "friends together" cluster puck with count badge. |
| `YourPushCard.swift` | The primary Push card (avatars, time chip, status) on the Pushes tab. |
| `ActivePlanCard.swift` | Compact active-push card variant. |
| `CreateActionMenuView.swift` | Floating create menu launched from the center nav button. |
| `ProfileComponents.swift` | Reusable profile rows, pills, avatar + camera badge, selection rows. |
| `PlansWeeklyRecapDayTile.swift` | Rich gradient/heat day tile — good example of the warm multi-stop gradient style. |

## 3. Major Screens

| File | Why it matters |
|---|---|
| `ContentView.swift` | The Live Map root — composes map, nav bar, create menu, sheets. The app's home. |
| `StyledMapView.swift` | MapKit styling, custom compass, hosted puck annotations, user pin. |
| `FriendDetailSheet.swift` | Friend / pair / small-group detail modal with warm gradient background. |
| `GroupsView.swift` | Friend Groups grid: image/gradient tiles, member avatars, status pills, stats. |
| `GroupDetailView.swift` | A single group's detail: hero, members, actions. |
| `PlansView.swift` | The Pushes tab: calendar, your pushes, weekly recap, start button. |
| `PlansCalendarView.swift` | Availability/heat calendar UI. |
| `ProfileView.swift` | Profile/settings screen (uses `PushModalBackground`). |
| `ProfileDestinationView.swift` | Profile sub-destinations (settings rows/detail). |
| `StartPushFlowView.swift` | Container/coordinator for the 4-step Start Push flow. |
| `StartPushStep1View.swift`–`Step4View.swift` | The 4 creation steps: recipients → activity → timing → review. |
| `StartPushTimingPickers.swift` | Custom calendar + time-clicker pickers for the timing step. |

## 4. State-Defining Models (they enumerate the visual states)

| File | Why it matters |
|---|---|
| `PuckModels.swift` | `FriendAvailabilityState` and puck data — the states that drive puck/chip colors. |
| `MapPuckModels.swift` | Map puck data model + defaults (region, etc.). |
| `PlansModels.swift` | `PlanStatus` (pending/joined/open/waiting/locked/happening) → drives pill styling. |
| `GroupsModels.swift` | Group data + `PushGroupStatus`, fallback symbols/initials for tiles. |
| `ProfileModels.swift` | Profile/settings/visibility option models. |
| `StartPushModels.swift` | Start Push flow state, activity/timing options. |

## 5. Mock Data (included because it explains real UI states)

| File | Why it matters |
|---|---|
| `SeedData.swift` | The seeded world (people, groups, places) — what actually renders in the prototype. |
| `SeedData+Presence.swift` | Seeded presence/availability — determines which availability states you see on the map. |

---

### Not copied (and why)
Data-layer plumbing (`Data/Repositories`, `Data/Store`, `Data/Derived`, remaining `Data/Domain`
and `Seed` files), view models, app entry point, and tests were left out — they define
behavior/architecture, not visual style. See the repo's `docs/data-architecture.md` if the
data model is ever needed.
