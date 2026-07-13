# Responsive Layout System Audit

## Goal
Make Push adapt cleanly across supported iPhone widths while preserving the iPhone 17 Pro Max
as the visual reference.

## Audit Findings
- Hardcoded dimensions causing crowding: map annotation frames, bottom-nav margins/button sizes,
  top map filter widths, Start Push group cards, Push card fixed heights, Friends row avatars and
  trailing chips, group-card avatars/stats, profile avatar/cards, onboarding top insets, and fixed
  detail-sheet heights.
- Repeated values that should be semantic: page horizontal padding, section spacing, card padding,
  card corner radius, row/avatar/icon sizes, modal spacing, puck sizes, button/tap sizes, and
  bottom-safe-area clearance.
- Components that should reflow: Friends rows, group stats, Start Push group selection, detail-sheet
  action rows, calendar/header controls, and plan-card headers/footers.
- Limited proportional scaling is appropriate for decorative avatars, pucks, icon circles, card
  padding, spacing, and non-critical fixed card dimensions. It is not appropriate for body text,
  primary controls, or minimum tap targets.

## Contract
- Add one shared adaptive layout source keyed by available container width, with compact, standard,
  and large tiers.
- Keep large-tier metrics equal or very close to the current iPhone 17 Pro Max treatment.
- Use adaptive semantic tokens inside existing feature layout enums instead of scattered screen checks.
- Replace brittle fixed widths/heights with adaptive grids, `ViewThatFits`, flexible frames, wrapping,
  or scrolling where those choices preserve usability.
- Keep controls comfortably tappable and let vertically dense screens scroll.
- Do not change business logic, repository/data flow, navigation, copy meaning, or brand styling.

## Acceptance Criteria
- App builds after adding the shared adaptive layout file to the Xcode project.
- Major app screens inherit compact/standard/large metrics from container width.
- Preview matrix covers a small iPhone, a standard iPhone, iPhone 17 Pro, and iPhone 17 Pro Max.
- Layout changes are scoped to SwiftUI geometry/spacing/adaptive presentation only.

# Issue #24 — Your Pushes Wiring + UI Fix

## Goal
Let owned Push cards edit their existing Push through the Start Push flow and repository layer,
and make the Your Pushes list use the same cream page background as the main Pushes screen.

## Contract
- Tapping `Manage` on a Your Push card opens the first step of `StartPushFlowView`.
- Edit mode pre-populates recipients, title, start time, location, and notes from the existing
  `PushPlan` and `PushResponse` rows.
- Saving an edit updates the existing `PushPlan` and response rows through `PushRepository`;
  it must not create a duplicate Push or mutate ViewModel-only state.
- Store mutation bumps the in-memory revision once so existing Pushes views reload.
- The Your Pushes "See all" screen uses the shared cream `FriendsBackground`.
- Do not redesign cards or unrelated Pushes behavior.

## Acceptance Criteria
- Existing owned Pushes open editable Start Push flow from step 1.
- Edited data persists anywhere Push cards are derived from the repository.
- Added/removed recipients update response rows without duplicating the Push.
- Focused data-layer and ViewModel tests cover edit persistence and refresh behavior.
- Relevant Push tests/build validations pass.

# Issue #22 — Onboarding Lab Style-System Migration

## Goal
Refactor the DEBUG-only onboarding lab so its visual styling is sourced from the shared Push
design system while preserving the current onboarding UX and visual treatment.

## Contract
- Keep screen order, copy, spacing, layout hierarchy, animation timing, and interactions unchanged.
- Keep `OnboardingLabMetric` only for onboarding layout measurements.
- Make `OnboardingLabColor` a thin semantic alias layer over shared Push palette/control/puck tokens.
- Move onboarding-specific color, glass, and press/button variants into shared Push style files.
- Keep onboarding-specific components intact: mini map, keypad, chips, privacy rows, progress chrome,
  notification rows, and add-friends list.
- Keep onboarding DEBUG-only; do not add production auth, permissions, contacts, backend, or navigation.

## Acceptance Criteria
- Onboarding screens look the same or extremely close after the refactor.
- No standalone `Color(labHex:)` usage remains in `Push/OnboardingLab`.
- Onboarding glass cards use a shared Push glass variant rather than a local material stack.
- Onboarding button press styling uses a shared Push control variant.
- App builds successfully and onboarding preview/source compiles.
- Manually inspect every onboarding screen for obvious visual regressions.

---

# Issue #8 — Zoom-Aware Pucks And Regional Clustering

## Goal
Render the live map at different zoom levels without puck overlap by deriving presentation-only
render pucks from privacy-filtered presence data.

## Contract
- Canonical exact-place pucks stay in `MapContentBuilder` and never use a `.regional` overload.
- `MapDisplayPuckBuilder` returns `MapPuckRenderModel.selfPuck`, `.friend`, `.smallGroup`,
  or `.regionalCluster`.
- Close zoom (`latitudeDelta <= 0.22`) renders exact friend/group pucks unchanged plus the
  standalone self puck when the user is not inside another rendered puck.
- Any zoom beyond close (`latitudeDelta > 0.22`) uses final regional clustering immediately,
  folding visible sources within roughly 100 miles into regional pucks, including the current
  user and joined groups.
- Regional clusters expose `RegionalPuckModel` with member count, self/joined flags, active,
  joinable and busy counts, dominant availability, representative avatars, region name,
  activity score, and group IDs.
- Group filters apply before clustering using canonical `groupIDs`.
- Map rendering continues to consume `VisiblePresence`; hidden/status-only users are excluded.
- Vague-location users never produce exact pucks. They can only contribute to regional clusters
  through `Place.vagueCoordinate` neighborhood/city centroids.

## Acceptance Criteria
- Zooming out reduces rendered puck count when nearby sources would overlap.
- Regional pucks show location initials and member count, with no profile photos.
- Regional pucks containing the current user or a joined group use the soft joined/self pulse.
- Tapping a regional puck smoothly requests a centered zoom into that region and does not open
  `FriendDetailSheet`.
- Existing exact friend/group taps still open `FriendDetailSheet`.
- Build succeeds and focused tests cover close, zoomed-out, self-containing, filtering,
  vague-location, and regional tap behavior.

---

# Map Self Puck

## Goal
Replace the current triangular user-location marker with a calm circular Self Puck that uses
the current user's profile photo, warm walnut/gold identity styling, and a subtle location halo.

## Contract
- The self marker derives from the current user's visible presence and uses that place coordinate.
- The self marker is not rendered as a friend puck when the current user is alone.
- If the current user is part of a multi-person puck, keep the existing behavior and hide the standalone self marker.
- The Self Puck is circular, slightly smaller than friend pucks, and never shows venue/activity/location text.
- The Self Puck uses the current user's profile photo with a frosted circular base, walnut outer stroke, subtle champagne inner ring/glow, and soft halo.
- The Self Puck always shows an attached `person.fill` + `You` badge using the same glass badge style as solo friend pucks.
- Tapping the Self Puck does not show an extra callout for now.
- Friend pucks stay visually unchanged.

## Acceptance Criteria
- `UserLocationPin` is no longer used by the live map marker.
- Current user appears as a circular avatar puck when not inside a group puck.
- Self Puck has a muted walnut/champagne double ring, soft halo, frosted base, and attached `You` badge.
- Map build and test build succeed.

---

# Pushes Weekly Calendar

## Goal
Polish the Pushes screen weekly recap and push modules so actions, color hierarchy, and glass treatment feel premium and social while keeping the existing content and mock data.

## Contract
- Show exactly seven Monday-first days for the reference week.
- Calendar top row shows `This week` on the left and `History ›` on the right.
- Calendar second row shows the current week range centered between subtle previous/next chevrons.
- Day cells read as a weekly recap rhythm: weekday, date, then a soft vertical activity tile.
- Keep today and the selected day softly emphasized with sunbeam tint/stroke.
- Active days should use warm, lightweight indicators without making every day equally heavy.
- Footer summarizes weekly Push activity instead of monthly Push activity.
- Day taps still open the lightweight day detail sheet.
- Your Pushes and Active Pushes section actions live in their section headers, not as floating links.
- Main titles use espresso; metadata and recap secondary text use quieter taupe/gray-brown tones.
- Start Push remains a glass pill but reads as the primary action with a subtle warm glow.
- Pushes cards use cleaner white/glass strokes and softer shadows against a warmer, less intense background.

## Acceptance Criteria
- Pushes calendar renders one row of seven days.
- ViewModel exposes weekly calendar data and weekly total state.
- Tests cover week length, Monday-first behavior, week label, navigation, and weekly total.
- Pushes screen builds successfully after the visual changes.

---

# Profile Page Production Pass

## Goal
Turn the profile page into a complete local-only SwiftUI experience where every Settings and Privacy row opens a polished mock screen, status editing includes Ghost Mode, and the page exposes a future-ready Connect section.

## Inputs / Outputs
- Input: User opens Profile from the map, taps Settings, Privacy, Set Status, or Connect controls.
- Output: Local profile state updates in the current ViewModel session, rows navigate to functional mock detail screens, and GSuite Calendar connect shows a local alert.

## Constraints
- SwiftUI only; no new dependencies.
- MVVM: `ProfileViewModel` owns editable profile, privacy, status, connector, and alert state.
- Mock/local only: no persistence, backend, auth, Google OAuth, calendar access, real location, or real settings writes.
- Reuse `PushGlassStyle`, `PushControlColors`, `PushControlStyle`, and walnut/sunbeam palette.
- Keep files under 400 lines with named layout constants.
- Detail copy must feel privacy-safe and avoid surveillance language.

## Profile Contract
- Header shows identity, selected availability, and current visibility summary.
- `Set Status` includes exactly four mutually exclusive cards: `Ghost Mode`, `Free now`, `Maybe down`, and `Busy`.
- Selecting `Ghost Mode` clears any visible availability selection, and selecting a visible status turns Ghost Mode off.
- When Ghost Mode is enabled, the visibility summary says the user is hidden from friends' map and social context.
- Settings routes:
  - `Edit profile`: edit name, handle, and photo placeholder.
  - `Activity visibility`: toggle social context fields.
  - `Map preferences`: tune default map visibility behavior.
- Privacy routes:
  - `Close Friends`: manage close-friend audience visibility.
- Profile header shows identity and a compact current status pill without a description underneath.
- Connect section sits below Privacy and is modeled as a list of connectors.
- First connector is `GSuite Calendar` with availability-only permission copy.
- `Connect with GSuite` is clickable and shows an alert without changing connection state.

## Edge Cases
- Only one Set Status card can be selected at a time.
- Text edits are local only and reset on app restart.
- Connector taps are design-only and do not launch external auth.
- Route metadata stays stable so rows remain testable.

## Out of Scope
- Backend persistence, authentication, OAuth, real calendar sync, contacts access, real location sharing, notifications, and Ghost Mode behavior outside the profile mock state.

## Acceptance Criteria
- All remaining Settings and Privacy rows navigate to a detail screen with controls.
- Profile edit actions update the local header state.
- Status selection updates locally and Ghost Mode updates the visibility summary.
- Activity, trusted friend, group, plan, and map preference toggles update locally.
- Connect section appears after Privacy with `GSuite Calendar` and availability-only copy.
- Tapping `Connect with GSuite` shows an alert.
- The requested app build and build-for-testing commands pass.

## Test Stubs
- `testProfileViewModelDefaultsGhostModeOff`
- `testProfileViewModelTogglesGhostModeAndHidesVisibilitySummary`
- `testProfileRoutesExposeSettingsAndPrivacyMetadata`
- `testProfileViewModelEditsProfileBasicsLocally`
- `testProfileViewModelUpdatesSelectedAvailabilityLocally`
- `testProfileViewModelTogglesActivityVisibilityLocally`
- `testProfileConnectSectionExposesGSuiteCalendarFirst`
- `testProfileConnectAlertUsesAvailabilityOnlyCopy`

---

# Real Friends Asset Seed Migration

## Goal
Replace placeholder friend and group mock data with local real-life seed data represented by the `assets` folder structure.

## Asset Contract
- `assets/profile`: current user profile image.
- `assets/friends`: every friend profile image, named `firstname.extension`.
- `assets/groups/<group_name>`: one folder per real group, containing the friend images that belong to that group.

## Implementation Contract
- Keep the app mock/local only.
- Centralize real friend and group seed metadata in one Swift source file.
- Use nested asset paths for profile, friend, and group images.
- Bundle the full `assets` folder so nested files resolve at runtime.
- Remove root-level files under `assets` that are not inside `profile`, `friends`, or `groups`.

## Acceptance Criteria
- Profile uses `assets/profile/manav.jpeg`.
- Friend pucks and group members use images under `assets/friends`.
- Groups list is derived from the real folders: `India`, `Exec`, and `Michigan`.
- Tests assert the real seed names, memberships, and asset paths.
