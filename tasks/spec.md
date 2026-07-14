# Eliminate Visible Supabase Data Lag

## Goal
Load the live social graph once per authenticated session before presenting the app, so Map,
Friends, Groups, and Profile all begin from one coherent Supabase snapshot rather than filling
incrementally.

## Contract
- A session-scoped, memory-only store owns profile, group, membership, and sharing-policy rows.
- Initial preparation starts the four independent table reads concurrently. The profiles read is
  shared by current-user, friend, and user-profile repository methods.
- Concurrent requests for the same resource coalesce onto one in-flight task.
- `RootView` installs and presents a live `AppDataContainer` only after every resource succeeds.
  Preparation shows branded progress; failure offers Retry and Sign Out.
- Profile and availability updates request the updated `profiles` row from PostgREST, replace that
  row in the shared store only after success, and publish exactly one live revision.
- Repository protocols, mock mode, RLS, schema, and empty live presence/push/feed behavior do not
  change. The synchronous live constructor remains for isolated no-network tests.
- Later ViewModel refreshes preserve already-loaded content instead of reverting to placeholders.
- Signing out discards the session container by removing it from the rendered tree; a future login
  prepares a new store. No snapshot persists across sessions or process launches.

## Acceptance Criteria
1. Four initial resources overlap in flight and duplicate callers do not create duplicate reads.
2. All live social repositories map values from the same warmed snapshot without further reads.
3. Successful profile/availability writes update every profile-backed read and emit one revision;
   failed writes change neither cache nor revision.
4. Restored-session and fresh-sign-in paths prepare before app presentation; failure, retry, sign
   out, and mock-mode routing are covered.
5. Opening Map, Friends, Groups, and Profile after preparation causes no new social-graph requests.
6. Focused tests, the full PushTests suite, and a generic simulator build pass; authenticated live
   smoke verification is recorded separately when credentials/session are available.

## Live identity regression
- Snapshot row order is never identity. Current-user and `UserProfile` reads must locate the row
  matching the authenticated user ID case-insensitively.
- Live preparation validates that the authenticated profile exists before installing the container;
  a missing row routes to recoverable preparation failure instead of presenting partially valid data.
- Tests must place the current user's profile after another visible profile to prevent accidental
  dependence on PostgREST response order.

---

# Issue #27 — Supabase Migration (Day 1)

## Goal
Stand up a real Supabase backend behind the existing repository seam so that **two real
users can authenticate, keep their session across launches, load their own profiles, see
each other as friends, load their shared group + memberships, and load sharing policies —
all from Supabase** — while the existing mock mode, deterministic tests, previews, and
current UI/MVVM architecture stay fully intact.

This is a **reads-only** slice for the migrated social data. No writes to live data on Day 1.

## Approved Design Decisions (locked)
- **Parallel composition modes** on `AppDataContainer`: `.mock` (today's `InMemoryDatabase`
  + `Local*` repos + seed) and `.live` (Supabase repos + identity from the auth session).
  `AppDataContainer(seed:)` is preserved unchanged.
- **Environment selection (explicit):**
  - DEBUG **defaults to mock**.
  - DEBUG **can opt into live** via the `--live` launch argument.
  - **Release always uses live.**
  - Existing `--pucklab` / `--onboardinglab` / `--friends` DEBUG args keep working.
- **Identity:** in live mode `currentUserID` comes from the authenticated Supabase session
  (the user's `auth.users.id`, as its UUID string). Domain IDs stay opaque `String`; UUIDs
  map directly (`uuid.uuidString`). No domain-model ID change. Seed slugs remain mock-only.
- **Version-controlled migrations are the source of truth.** The remote project
  (`tzzvwjhvjduyqywlszqc`) is greenfield (no tables, no migrations, no users). All schema,
  RLS, helpers, and triggers are authored as repo migrations, then applied to remote via MCP
  `apply_migration` (recorded in migration history). The remote is never the sole source.
- **No mock data leaks into live sessions** (see Revision 1).

## Revisions Applied (from design approval)

**R1 — Live presence stays empty on Day 1.** Do not mix mock presence, location, pushes, or
feed into authenticated live sessions. In live mode the presence/push/feed reads return
empty results. Friends with no live presence render naturally as the existing calm
"Hidden right now" row via `FriendsContentBuilder` (confirmed: it never drops a friend).
The live map is expected to be sparse; Friends, Groups, and Profile are the verification
surfaces.

**R2 — Reuse the completed OnboardingLab sign-in/sign-up experience for production**, rather
than building a separate auth flow. Promote **only** the production-ready presentation
pieces needed for real app use — theme tokens (`OnboardingLabTheme`), shared components
(`OnboardingLabComponents`: header, CTA, auth field, `OnboardingAuthSwitchLink`, etc.), and
the **sign-in** (`OnboardingSignInScreen`) + **sign-up/welcome** (`OnboardingWelcomeScreen`)
layouts — out of `#if DEBUG` so production can render them. Wire them to **real Supabase
auth/session state**. Keep the DEBUG `OnboardingLab` as a sandbox around the **same**
components where practical. Lab-only fixtures, the phone/keypad + code flow, the 11-step
setup flow, and the mock `completeSignIn()`→`.done` behavior stay DEBUG-isolated. Prefer the
**smallest refactor**; do not reorganize files solely for architectural purity. Apple/Google
buttons are out of scope for Day 1 (hide/disable in the production surface); the sign-up
cross-link maps to Supabase `signUp`.

**R3 — One canonical source of truth for visibility.** `sharing_policies` is the sole
authority for presence visibility (resolution friend → group → globalDefault, matching
`VisiblePresenceBuilder`). `group_memberships` is about membership only and carries **no**
`sharing_level` column. `GroupMembership.sharingLevel` (vestigial — no builder reads it) is
mapped by the Supabase group repo to a documented default (`.full`). Group-scoped visibility
is expressed exclusively via a `sharing_policies` row with `audience_type = 'group'`.

**R4 — Never SQL-seed `auth.users` for deterministic test users.** Create the two test
identities through **real Supabase Auth** (production sign-up flow and/or a documented
GoTrue-signup helper — never direct `auth.users` inserts, never a service-role key in the
app). The `handle_new_user` trigger auto-creates their `profiles` rows. Then `supabase/seed.sql`
(idempotent, resolves the two users **by email** from `auth.users` — no hardcoded UUIDs)
seeds the public social graph (friendship, group, memberships, sharing policies) using their
**actual** IDs. Schema, migrations, policies, and public-data seed all reproducible from repo.

**R5 — Environment behavior explicit.** (Captured in Approved Design Decisions above.)

**R6 — Harden every `SECURITY DEFINER` helper**: fixed safe `search_path` (`set search_path
= ''`, fully schema-qualified references), minimal privileges (revoke `execute` from
`public`/`anon`, grant only to `authenticated` where needed), and narrowly scoped behavior
(single responsibility, no dynamic SQL). Tests must cover **allowed and denied** access,
including an **unrelated third user** where practical.

**R7 — Full-path RLS verification.** MCP/SQL impersonation (`set request.jwt.claims`) may be
used during development, but **final** RLS verification must also exercise **real
authenticated client requests** so we prove the complete Auth → JWT → RLS → PostgREST path.

**R8 — Testing beyond DTO decoding.** DTO→domain mapping tests are useful but not the primary
layer. Add focused coverage for: environment selection (mock vs live resolution incl.
`--live` and Release), auth/bootstrap state transitions, live-vs-mock isolation (no mock data
in a live container), session-restoration behavior, and authenticated RLS behavior.

**R9 — Abstraction rule.** No direct Supabase access from Views or application ViewModels. An
**auth-specific `AuthViewModel`** may call an injected `AuthService` if that is the cleanest
MVVM design. Do **not** overcentralize auth into a root coordinator unnecessarily. Existing
application ViewModels continue to consume repositories only.

**R10 — Advisor gate (softened).** Instead of requiring `get_advisors(security)` to be
completely clean: **no unresolved high-severity findings** caused by the new schema, RLS
policies, or `SECURITY DEFINER` functions.

## Database Schema (`public`) — mirrors existing domain structs
Follow the repo Supabase skills (`supabase`, `supabase-postgres-best-practices`): lowercase
snake_case identifiers, explicit primary keys, indexes on foreign keys, appropriate
constraints, and the RLS-performance pattern (`(select auth.uid())`).

| Table | Maps to | Key columns / rules |
|---|---|---|
| `profiles` | `Person` + `UserProfile` | `id uuid pk references auth.users(id) on delete cascade`, `first_name text`, `handle text unique`, `image_asset_path text null`, `availability_choice text`, `visibility_note text`, `created_at`, `updated_at` |
| `friendships` | new (mutual, undirected) | `id uuid pk`, `user_low uuid`, `user_high uuid`, `status text default 'accepted'`, `created_at`; `check (user_low < user_high)`, `unique (user_low, user_high)`, FK both → `profiles(id)` |
| `groups` | `FriendGroup` | `id uuid pk`, `name text`, `image_asset_path text null`, `created_at` |
| `group_memberships` | `GroupMembership` | `id uuid pk`, `person_id uuid → profiles(id)`, `group_id uuid → groups(id)`, `role text`, `membership_status text`, `joined_at`; **no** `sharing_level` (R3); `unique (person_id, group_id)` |
| `sharing_policies` | `SharingPolicy` | `id uuid pk`, `owner_person_id uuid → profiles(id)`, `audience_type text` (`friend`/`group`/`global_default`), `audience_id uuid null`, `location_visibility text`, `activity_visibility text`, `availability_visibility text`, `expires_at timestamptz null` |

- Friendship is **mutual/undirected**, `status = 'accepted'` for Day 1; no request/invite flow.
- Profile UI scaffolding arrays (`activityVisibility`, `mapPreferences`, `closeFriends`,
  `connectors`, `availabilityOptions`) are **client-side defaults** for Day 1 (not stored);
  `SupabaseProfileRepository` synthesizes them so the profile screen renders unchanged.

## RLS & Security (enabled from creation on every table)
- `profiles`: SELECT if `id = (select auth.uid())` OR `is_friend((select auth.uid()), id)` OR
  `shares_group((select auth.uid()), id)`. INSERT/UPDATE own row only.
- `friendships`: SELECT where `(select auth.uid()) in (user_low, user_high)`. No client writes Day 1.
- `groups` / `group_memberships`: SELECT where `is_group_member((select auth.uid()), group_id)`
  (or own membership row). No client writes Day 1.
- `sharing_policies`: SELECT where `owner_person_id = (select auth.uid())` OR the viewer is the
  policy's audience (friend / group member / global-default of a friend). No client writes Day 1.
- **Helpers** `is_friend`, `shares_group`, `is_group_member` are `SECURITY DEFINER`, hardened
  per R6, and used to avoid RLS recursion.
- **Signup trigger** `handle_new_user()` (`SECURITY DEFINER`, hardened) auto-creates a
  `profiles` row on `auth.users` insert (handle/first_name from signup metadata or email).
- **Secrets:** the iOS app ships only the project URL + **anon/publishable** key (safe to
  embed, e.g. via `.xcconfig`/Info.plist). Service-role key never appears in the app.

## iOS Client Layer
- **SDK:** add `supabase-swift` (Auth + PostgREST) via SwiftPM. Note: `scripts/pbxproj_add.py`
  registers source files only — the SPM package is a separate, carefully-verified
  `project.pbxproj` edit.
- **`SupabaseConfig`** — URL + anon key (non-secret config, not hardcoded secrets).
- **`AuthService`** — the only type that talks to GoTrue: `signIn`, `signUp`, `signOut`,
  `restoreSession`, publishes auth state. Injected (into `AuthViewModel` per R9), never called
  from application Views/ViewModels.
- **`AuthViewModel`** — drives the promoted sign-in/sign-up screens; calls injected
  `AuthService`; surfaces inline errors and `canSubmit` state.
- **`Supabase{Friend,Group,Profile,Sharing}Repository`** — implement the existing protocols
  with PostgREST reads, decoding row DTOs (snake_case CodingKeys) into existing domain structs.
- **Out-of-scope reads in live mode** (`presenceStatuses`, `PushRepository`, `FeedRepository`)
  return **empty** results (R1) — no mock data in a live session.
- **`AppDataContainer`**: lift `currentUserID` / change-notification off the hard `InMemoryDatabase`
  dependency into a tiny internal abstraction. Mock init keeps `InMemoryDatabase` behavior
  verbatim; live init sources `currentUserID` from the session and provides a no-op change
  publisher (reads-only Day 1). Additive; the full mock test suite guards the refactor.
- **Root / bootstrap:** a production entry that, in live mode with no session, shows the
  promoted onboarding sign-in surface; once authenticated (or session restored), builds the
  live `AppDataContainer` and renders `ContentView`. Mock mode renders `ContentView` exactly
  as today.

## Session Restoration
`supabase-swift` persists the session (Keychain) and restores it on client init;
`AuthService.restoreSession()` is awaited at launch to route app-vs-gate. No manual token handling.

## Migrations, Seed & Reproducibility
- `supabase/migrations/NNNN_*.sql`: extensions/helpers → each table + RLS → signup trigger.
  Authored in repo, applied to remote via MCP `apply_migration`.
- Test identities created via **real Supabase Auth** (R4); `supabase/seed.sql` idempotently
  resolves the two users by email and seeds friendship + group + memberships + sharing
  policies against their real IDs.
- No Supabase CLI installed; Day 1 applies via MCP with the `.sql` files as the record.

## Out of Scope
Real location, realtime/subscriptions, feed, pushes, push notifications, activity inference,
invite/complete-friend-request flow, broad/unrelated UI redesign, Apple/Google social auth,
and any writes to live social data.

## Testing (R8 — layered, not DTO-only)
- All existing deterministic mock tests + previews stay green, unchanged.
- Environment selection: mock default in DEBUG, `--live` opt-in, Release forces live.
- Auth/bootstrap state transitions (no session → gate; signed-in → app; restore → app).
- Live-vs-mock isolation: a live container exposes no mock/seed presence/push/feed data.
- Session restoration behavior.
- Authenticated RLS behavior (R7: real Auth → JWT → RLS → PostgREST), plus SECURITY DEFINER
  allow/deny incl. an unrelated third user (R6).
- DTO→domain mapping (supporting layer, not primary).

## Day-1 Success Criteria
1. Launch in `--live` with no session → onboarding-styled Supabase-backed sign-in surface.
2. Sign in as test user A (real Auth) → session persists; **relaunch stays signed in**.
3. Profile screen shows A's real profile from Supabase.
4. Friends screen shows user B as a friend (calm hidden-presence row).
5. Groups screen shows the shared group with both members.
6. Sharing policies load without error and resolve.
7. Sign in as B → symmetric: sees A as friend + the same shared group.
8. Default DEBUG build (no `--live`) is today's mock app; **all existing tests pass**.
9. Schema + migrations + `seed.sql` reproduce the state from the repo; **no unresolved
   high-severity `get_advisors(security)` findings** from the new schema/RLS/`SECURITY DEFINER`
   objects (R10).

## Key Risks & Mitigations
- **RLS recursion** → hardened `SECURITY DEFINER` helpers (R6).
- **Hand-editing `project.pbxproj` for SPM** → isolate and verify a clean build.
- **`AppDataContainer` refactor on a shared root** → keep additive; full mock suite as guard.
- **Non-deterministic auth IDs** → email-lookup, idempotent `seed.sql` (R4).
- **Promotion out of `#if DEBUG`** → smallest refactor; lab keeps compiling against the same
  promoted components; lab-only mock/fixtures stay isolated (R2).

---
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
