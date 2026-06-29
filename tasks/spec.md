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
