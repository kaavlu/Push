# Push — Design Brief

_A handoff document for Claude Design. Everything here is extracted from the existing
SwiftUI codebase. Nothing about the app has been redesigned or changed._

---

## What Push Is

**Push is a private live map for real friends.** The core promise:
**know the move before the group chat does.**

It helps a small circle of close friends understand what's happening around them —
where people are, what they're doing, who they're with, and whether something social is
forming — without needing to text everyone.

Push is explicitly **not**:

- a tracking / surveillance app
- a generic map app
- a chat app
- a social-media clone
- an enterprise / analytics dashboard

It should read as a **premium, Apple-native social layer for real life** — closer to a
warm, playful Apple app than to a utility.

**Scope note:** This is a high-fidelity SwiftUI prototype (iOS 17+, MVVM, all data
mocked/local). There is no backend, auth, real location, or notifications yet. The design
system therefore lives entirely in the client.

---

## Design Personality

Push should feel:

- **Premium** — considered spacing, soft shadows, glass surfaces, nothing cheap.
- **Playful & warm** — sunbeam yellow, walnut/chocolate brown, cream. Rounded everything.
- **Social & human** — real faces (avatars) are front and center, not pins and abstractions.
- **Calm & trustworthy** — muted, low-contrast surfaces; privacy language that never feels
  like spying. Confidence in status copy scales down when the app is less sure.
- **Native** — SF Symbols, system materials, `.rounded` system font, iOS sheet/modal idioms.

The signature look is a **warm liquid-glass system**: translucent `ultraThinMaterial`
surfaces tinted with cream/sunbeam, hairline white strokes, and **walnut-amber shadows
instead of black**. This warmth is the brand's defining move — the app deliberately avoids
neutral white/gray glass.

---

## Color Story (summary — see `PushThemeAudit.md` for exact values)

| Role | Color | Hex |
|---|---|---|
| Primary accent / highlight | Sunbeam yellow | `#FFEE8C` |
| Primary text / brand ink | Walnut brown | `#8B5B29` |
| Deepest text (names/titles) | Espresso | ~`rgb(0.22,0.12,0.05)` |
| Positive / "joined" | Sage green | `#2E7A47` |
| Soft positive fill | Mint foam | `#C7F0D6` |
| Backgrounds | Cream | ~`#FFF5DE` / `#FAE8C7` |
| Shadows | Warm walnut-amber (never black) | ~`rgb(0.55,0.36,0.16)` |

Availability states each have their own puck accent color (green free-now, amber
maybe-down, orange busy, blue joinable, cyan driving, gray unavailable).

Soft pink/purple accents are part of the intended brand palette but are currently
light in the codebase — call this out to Claude Design as a direction to lean into,
not an existing token.

---

## Core Screens & Surfaces

1. **Live Map** (`ContentView` + `StyledMapView`) — the heart of the app. A MapKit map with
   custom **friend pucks** (round avatars with a colored availability ring, activity badge,
   and pulsing glow) and **cluster pucks** when friends are together. A floating glass
   **bottom navigation bar** overlays the map.

2. **Friend Detail Sheet** (`FriendDetailSheet`) — tap a puck to open a lightweight modal:
   hero avatar, live status, activity card, quick actions. Distinct variants for a single
   friend, a pair, and a small group hangout. A warm sunbeam→walnut gradient background.

3. **Groups** (`GroupsView`) + **Group Detail** (`GroupDetailView`) — real-world circles
   (Michigan, Exec, India, …) shown as image/gradient tiles with member avatars, status
   pills, and stats.

4. **Pushes / Plans** (`PlansView`, `PlansCalendarView`, `YourPushCard`, `ActivePlanCard`,
   `PlansWeeklyRecapDayTile`) — the coordination surface. A calendar/availability heat view,
   "your pushes" cards with avatar stacks and status pills, and a weekly recap.

5. **Start Push flow** (`StartPushFlowView` + `StartPushStep1–4View`) — a 4-step creation
   flow (recipients → activity → timing → review) with a step indicator, glass search bar,
   chips, and a capsule primary button.

6. **Profile / Settings** (`ProfileView`, `ProfileDestinationView`, `ProfileComponents`) —
   large avatar with camera badge, availability/visibility rows, privacy controls. Uses the
   shared `PushModalBackground` (sunbeam→white→walnut gradient).

7. **Create menu** (`CreateActionMenuView`) — a small floating action sheet launched from the
   center nav button.

---

## Signature Components

- **Friend puck** — round avatar, colored availability ring, pulsing glow, activity badge,
  optional count badge for clusters. This is the most brand-defining UI element.
- **Warm glass card** — `pushGlassBackground` / `plansGlassCard`: material + cream tint +
  white hairline stroke + walnut shadow, corner radius ~26.
- **Capsule primary button** — sunbeam fill, walnut label, bold rounded text.
- **Status / availability pills** — capsule chips whose fill and text color encode state.
- **Avatar stack** — overlapping circular avatars with white rings and an overflow "+N" chip.
- **Floating glass bottom nav** — pill container with a raised circular "+" primary action.
- **Step indicator** — numbered active capsule + dimmed dots.

---

## Design Principles (for Claude Design to follow)

1. **Warm over neutral.** Never default to white/gray glass or black shadows. Tint surfaces
   cream/sunbeam and cast walnut-amber shadows.
2. **Faces over pins.** People are represented by real circular avatars, not map markers.
3. **Rounded, soft, generous.** Continuous corner radii (16–32), capsules for actions and
   chips, soft multi-layer shadows. No hard rectangles or sharp corners.
4. **State is color-coded but gentle.** Availability and status use saturated accents only in
   small doses (rings, pills, dots) over calm cream fields.
5. **Copy is casual and socially safe.** Specific when confident, softened when not. Never
   surveillance-flavored.
6. **Native materials, not custom chrome.** Build on `ultraThinMaterial` / `glassEffect`,
   SF Symbols, and system typography (`.rounded` design where possible).
7. **Calm hierarchy.** Walnut-based text tiers (espresso → walnut → walnut@70% → walnut@52%)
   instead of pure black/gray.
8. **Lightweight, not heavy.** Modals and detail sheets are quick glances, not full profiles
   or dashboards.

---

## What The UI Should / Should Not Feel Like

**Should feel like:** a warm Apple-native social app; a cozy live map of your close friends;
soft glassy cards on cream; playful but premium; calm and private.

**Should NOT feel like:** Find My / a tracker; Google Maps / a generic map utility; a
messaging app; Instagram/Snapchat; a data dashboard; anything cold, corporate, high-contrast,
or neon.
