# Data Architecture Standardization (issue #15)

## Goal
Replace six scattered mock-data enums with one local data layer: normalized seed →
in-memory store → async-throws repositories → view-model builders. See
`docs/data-architecture.md` and `docs/superpowers/specs/2026-07-05-data-architecture-design.md`.

## Completed
- [x] Domain entities with opaque String IDs + `LoadState` (`Push/Data/Domain`, `Push/Data/LoadState.swift`).
- [x] Centralized `SeedData` reproducing every screen's content (`Push/Data/Seed`).
- [x] `InMemoryDatabase`, async-throws repositories, `AppDataContainer` (`Push/Data/Store`, `Push/Data/Repositories`).
- [x] `VisiblePresence` + sharing-policy resolution (`Push/Data/Derived/VisiblePresence.swift`).
- [x] Derivation builders: map pucks, group cards, push cards/calendar, profile (`Push/Data/Derived`).
- [x] Rewired Map, Groups, Pushes, Profile, Start Push view models onto repositories + `LoadState`.
- [x] PuckLab renamed to `PuckLabFixtures` (self-contained design fixtures).
- [x] Deleted `RealWorldMockData`, `ProfileMockData`, `MapPuckMockData`, `GroupsMockData`, `SeededGroupFriends`, `PlansMockData`, `FriendGroupFilter`.
- [x] Documented content changes and Supabase migration path in `docs/data-architecture.md`.
- [x] Added `scripts/pbxproj_add.py` to register new files in the objectVersion-56 project.

## Verification
- [x] `xcodebuild build` (generic iOS Simulator): BUILD SUCCEEDED.
- [x] `xcodebuild test -only-testing:PushTests -parallel-testing-enabled NO`: 89 tests, 0 failures.

## Notes
- Run tests with `-parallel-testing-enabled NO`; the parallel runner intermittently
  drops the simulator connection (`DTXProxyChannel` / Mach `-308`) in this environment.
  A `simctl shutdown all` + kill of `CoreSimulatorService` clears it.

---

# Profile Page Production Pass

## Goal
Build the profile page into a complete local-only SwiftUI experience with functional Settings/Privacy mock screens, Ghost Mode status control, and a Connect section for GSuite Calendar.

## Completed
- [x] Updated `tasks/spec.md` with the profile contract, local-only constraints, Ghost Mode behavior, Connect behavior, acceptance criteria, and test stubs.
- [x] Split profile implementation into models, mock data, view model, reusable components, main view, and destination views.
- [x] Moved `MainMapRoute` into `MainMapModels.swift`.
- [x] Expanded `ProfileViewModel` to own editable local profile basics, selected status, Ghost Mode, visibility toggles, trusted friends, map preferences, privacy audiences, plan sharing, connectors, and connector alert state.
- [x] Added navigable Settings routes: Edit profile, Activity visibility, Trusted friends, Map preferences.
- [x] Added navigable Privacy routes: Close Friends, Friend Groups, Plans.
- [x] Added Set Status with all MVP availability states plus a prominent Ghost Mode toggle.
- [x] Added Connect section below Privacy with a design-only `GSuite Calendar` connector and clickable alert.
- [x] Added unit coverage for Ghost Mode, route metadata, local profile editing, local toggles, and GSuite connector metadata/alert.
- [x] Revised Set Status to exactly four mutually exclusive cards: Ghost Mode, Free now, Maybe down, Busy.
- [x] Removed Trusted friends, Friend Groups, and Plans tabs.
- [x] Removed the root close button from pushed profile detail screens.
- [x] Replaced the default iOS detail back button with a custom glass back button.
- [x] Removed the description under the compact profile status pill.

## Verification
- [x] Passed: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build`
- [x] Passed: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator'`
- [ ] Blocked locally: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests`

## Test Runner Blocker
The unit test target compiles, but launching the simulator test runner fails locally with:

`xcrun: error: unable to find utility "simctl", not a developer tool or in PATH`

The same failure occurred with escalated permissions. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find simctl` resolves to `/Applications/Xcode.app/Contents/Developer/usr/bin/simctl`, so this appears to be a local simulator runner environment issue, not a compile or assertion failure.

## Resuming From Here
- Profile production pass implementation is complete.
- Latest profile change request is complete.
- Next useful step is to run the unit suite from a fully working Xcode simulator environment.
- Existing unrelated files still exceed the 400-line limit (`FriendPuck.swift`) from prior work; this pass kept all new profile files under 400 lines.

---

# Real Friends Asset Seed Migration

## Completed
- [x] Added centralized real friend/profile/group seed data from the `assets` folder structure.
- [x] Updated profile, map pucks, puck lab examples, group filters, and groups data to use real names and nested image paths.
- [x] Updated tests to assert real groups, memberships, and image asset paths.
- [x] Switched Xcode resources to bundle the full `assets` folder.
- [x] Removed root-level asset files outside `assets/profile`, `assets/friends`, and `assets/groups`.
- [x] Verified build.

## Verification
- [x] Passed: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator' build`
- [x] Passed: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project Push.xcodeproj -scheme Push -destination 'generic/platform=iOS Simulator'`
- [x] Unit assertions passed before simulator teardown failure: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests`

## Test Runner Note
All `PushTests` and `GroupsTests` cases printed as passed, then `xcodebuild` exited 65 because the local simulator service failed during diagnostics/teardown with `xcrun: error: unable to find utility "simctl", not a developer tool or in PATH`.
