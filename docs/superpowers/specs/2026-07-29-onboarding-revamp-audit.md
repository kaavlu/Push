# Onboarding Revamp — Current-State Audit (Issue #134)

**Date:** 2026-07-29  
**Status:** Audit complete — product interview + specification pending  
**Branch:** `kaavlu/issue-134-onboarding-revamp`  
**Issue:** https://github.com/kaavlu/Push/issues/134

This document records what exists in the repository today. It does **not** decide the new flow.

---

## 1. Two parallel “onboarding” surfaces

| Surface | When | Real backend? | Scope |
|---|---|---|---|
| **Production auth gate** (`Push/Auth/*`) | Live unauthenticated (`BootstrapState.gate`) | Yes — `AuthViewModel` → `AuthService` | Welcome, email sign-up, sign-in, recovery, Google |
| **Post-auth first-run** (`PostAuthOnboarding*`) | Live session prepared **and** `profiles.onboarding_completed_at` is null | Yes — sharing, location session, notifications API, friends, `complete_onboarding` | Privacy → location → notifications → find friends → done |
| **Onboarding Lab** (`Push/OnboardingLab/*`, `#if DEBUG`) | Launch arg `--onboardinglab` (`--screen=` jump) | **No** — static fixtures only | Fuller designed primer (preview map, contacts mock, phone path) |

Theme/components (`OnboardingLabTheme`, `OnboardingLabComponents`, `OnboardingAuthComponents`, `OnboardingPrivacyOption`) are promoted for production reuse. Lab **screens**, fixtures, phone keypad, and mock `completeSignIn()` stay DEBUG-only.

Mock app mode (`AppMode.mock`) **never** shows post-auth onboarding (`LocalProfileRepository.needsPostAuthOnboarding` → `false`).

---

## 2. End-to-end live bootstrap (account → map)

```text
App launch (live)
  ├─ restoreSession()
  │    ├─ nil  → .gate (AuthGateView)
  │    └─ user → .preparing → prepareLive
  │
Auth success (email / Google / open URL callback)
  → .preparing(user)
  → AppDataContainer.prepareLive + installPreparedLive
       ⚠ installPreparedLive Task { locationSession.startIfEligible() }  // can prompt OS location early
       ⚠ presence Realtime bridge start
  → optional soft-fail sign-up photo upload
  → profile.needsPostAuthOnboarding()
       ├─ true  → .onboarding → PostAuthOnboardingView
       │            … steps …
       │            complete_onboarding RPC
       │            "Open Push" → .app
       └─ false → .app → ContentView (map)
  → enter(.app) also calls startIfEligible() again
```

Relevant files:

- `Push/RootView.swift` — `BootstrapState`, prepare, gate, onboarding, app
- `Push/Auth/AuthViewModel.swift` / `AuthGateView.swift`
- `Push/Auth/PostAuthOnboardingViewModel.swift` / `*Screens.swift`
- `Push/Data/AppDataContainer.swift` — `installPreparedLive`
- Migration `supabase/migrations/0019_post_auth_onboarding.sql`

---

## 3. Production authentication flow

### Screens (`AuthGateScreen`)

| Screen | Collects / actions |
|---|---|
| `welcome` | Google sign-in; “Continue with email”; “Already have an account?” → sign-in; legal consent |
| `signUpProfile` | **Required:** display name, handle (3–20, `[a-z0-9_]`). **Optional:** profile photo (PhotosPicker → JPEG held in memory) |
| `signUpCredentials` | **Required:** email, password (≥8) |
| `checkEmail` | After `confirmationRequired` — no new data; path to sign-in (pending photo retained) |
| `signIn` | Email + password; Google; forgot password |
| `forgotPassword` | Email |
| `setNewPassword` | New password + confirm (after `pushapp://auth/reset`) |

### Sign-up outcomes

- `.authenticated` → prepare → onboarding or app  
- `.confirmationRequired` → check email; first successful sign-in later still hits prepare + onboarding gate if incomplete  

### Profile row creation

Sign-up sends Supabase user metadata `first_name` + `handle` (`AuthService.signUp`). OAuth uses migration `0017` handle/name hardening. Photo uploads only after prepare via `ProfileRepository.updateProfilePhoto` (soft-fail).

### Deep links (auth only)

| URL | Behavior |
|---|---|
| `pushapp://auth/callback` | Email confirm / OAuth → signed-in → prepare |
| `pushapp://auth/reset` | Password recovery → gate held on set-password until update |

**No friend-invite, group-invite, or referral deep links** exist for first-run activation.

Sign in with Apple is removed. Phone/SMS is lab-only.

---

## 4. Production post-auth onboarding (new accounts)

### Ordered steps

| # | Screen | Teaches | Asks / enables | Persist / side effects |
|---|---|---|---|---|
| 1 | **Privacy** | “You’re in control.” Four modes | Choose `OnboardingPrivacyOption` (default `.exactActivity`) | `set_global_sharing_defaults` RPC; Ghost via `setPresencePublishingEnabled`; mirrors Profile toggle maps via `updatePrivacy` |
| 2 | **Location** | “Push runs on location.” Chip echoes privacy choice | **Enable** → `locationSession.startIfEligible()`; **Not now** skips | When-in-use OS prompt only if still `.notDetermined` (may already have been requested — see §6) |
| 3 | **Notifications** | Sample notification cards | **Turn on** → `UNUserNotificationCenter.requestAuthorization`; **Maybe later** skips | System prompt; result ignored (errors swallowed); **no push backend** yet |
| 4 | **Friends** | “Find your people.” | Add/send requests from `discoverPeople` (limit 20); Continue always available | `sendFriendRequest`; load failures → empty list + copy, still continuable |
| 5 | **Done** | “You’re in.” | **Open Push** | `complete_onboarding` RPC already called on continue-from-friends before this screen |

Progress UI: 4 capsules (privacy…friends). Back from location/notifications/friends; **not** from privacy or done. No per-step resume cursor on disk — only binary completion flag.

### Privacy option → policy mapping

| Option | Location | Activity | Availability | Presence publish |
|---|---|---|---|---|
| Exact location + activity | exact | full | full | on |
| Exact location only | exact | hidden | full | on |
| Vague location | vague | vague | full | on |
| Ghost mode | hidden | hidden | hidden | off (`is_published` orthogonal) |

---

## 5. Information collected from the user

### At account creation (auth)

| Field | Required? | Where stored |
|---|---|---|
| Email | Yes (email path) | Auth |
| Password | Yes (email path) | Auth |
| Display name (`first_name`) | Yes (email path); OAuth may derive | `profiles` |
| Handle | Yes (email path); OAuth hardened in `0017` | `profiles` |
| Profile photo JPEG | Optional | Storage `avatars` + `profiles.image_asset_path` after prepare |
| Legal consent | Displayed (links via `LegalDestinations`) | Not a stored boolean flag in app code |

### During post-auth onboarding

| Input | Required to finish? |
|---|---|
| Privacy mode selection | Effectively yes (Continue always selects current, default exact+activity) |
| Location permission | **No** — skippable |
| Notification permission | **No** — skippable |
| Friend requests | **No** — zero adds allowed |
| Contacts book | **Not requested in production** |

### Not collected in production first-run

- Phone number  
- Contacts access  
- Birthday / age  
- Invite code  
- Home city / campus  
- Group membership at signup  

---

## 6. System permissions — when and what happens

### Location (when-in-use)

**Entry points that call `LocationSession.startIfEligible()`:**

1. `AppDataContainer.installPreparedLive` — **immediately after every successful live prepare** (including users about to enter post-auth onboarding)  
2. `PostAuthOnboardingViewModel.enableLocation()` — intentional CTA  
3. `RootView.enter(.app)` — again when shell becomes ContentView  

**`startIfEligible` behavior** (`LocationSession`):

- If authorization `.notDetermined` → `requestAuthorization(mode: .whenInUse)` (native dialog)  
- If denied / restricted / cannot run pipeline → tracking stays off; no custom Settings deep-link from onboarding  
- If authorized → starts updates, inference pipeline, presence publish subject to Ghost / publish policy  

**Gap vs product intent in #134:** The OS location prompt can appear **during/after prepare while the user is still on Privacy** (or even before any Push-designed explanation), because install fires `startIfEligible` in a `Task`. Enable Location on the primer may then be a no-op for the dialog (already determined).

**Denied / restricted:** Onboarding still advances. Map later shows friends without self presence; empty map CTA is driven by **zero friends**, not missing location (`MapViewModel.surfacePhase`).

**Ghost chosen earlier:** Publishing disabled, but location auth may still be requested so the device can run the pipeline when Ghost is turned off later.

### Notifications

- Only from post-auth **Turn on notifications**  
- `requestAuthorization(options: [.alert, .badge, .sound])`  
- Result discarded (`try?`); no branching UI for denied  
- Product copy promises nudges; **push notification backend is out of MVP** (`Agents.md` What NOT to Build)

### Photos (sign-up avatar)

- `PhotosPicker` only — no full Photos library permission string path beyond picker  

### Contacts

- Lab has a **mock** contacts primer UI (`OnboardingContactsScreen`)  
- Production uses `discover_profiles` RPC only — **no `CNContact` / contacts permission**  
- `docs/app-store-privacy.md` still notes contacts DB not used  

### Camera / microphone / critical alerts

- Not requested in onboarding  

---

## 7. How onboarding completion is stored

| Layer | Mechanism |
|---|---|
| DB | `profiles.onboarding_completed_at timestamptz` (`0019`) |
| Mark complete | `complete_onboarding()` SECURITY DEFINER — sets coalesce(now()) — **idempotent** |
| Existing users | Migration backfill: all null rows set to `now()` at deploy time |
| Client gate | `ProfileRow.hasCompletedOnboarding` → `needsPostAuthOnboarding()` |
| Mock | Always complete / no-op complete |

**Partial progress is not stored.** Kill mid-flow → next launch restarts at Privacy (re-saves defaults). Friends already requested remain pending in friendships. Location/notification OS answers persist at OS level.

**Failure modes:**

- `needsPostAuthOnboarding` fetch fails → treated as **false** (`?? false`) → user may skip onboarding into app  
- `complete_onboarding` fails → stay on friends step with error; not finished  
- Privacy save fails → stay on privacy with error  

---

## 8. Account variants

| Variant | Behavior today |
|---|---|
| **New email/Google account** | `onboarding_completed_at` null → full post-auth flow |
| **Returning completed account** | restore/sign-in → prepare → `.app` |
| **Partially onboarded** | Still null flag → full flow again from privacy |
| **Confirm-email pending** | No session until confirm/sign-in; then same as new if incomplete |
| **Password recovery** | Gate held on set-password; after update, prepare → app/onboarding as usual |
| **Mock / DEBUG without `--live`** | Skip auth + skip post-auth onboarding; seed map immediately |
| **Invite-link user** | **Not implemented** — no invite deep link product path |
| **OAuth with incomplete profile** | Still subject to null `onboarding_completed_at`; name/handle may be auto-derived |

---

## 9. Between account creation and first useful map

1. Auth success  
2. Full session warm (`LiveDataStore.warm` — profiles, groups, memberships, policies, pushes, responses, presence, friendships, blocks)  
3. Optional avatar upload  
4. Possibly OS location prompt (early)  
5. Post-auth steps (if incomplete) — mostly settings/permissions/friends, **not** an interactive map tutorial  
6. Done → `ContentView` live map  

**First useful map experience depends heavily on graph state:**

- Zero friends → `MapEmptyOverlay` “Add friends” empty (not a location empty state)  
- Friends exist but not sharing / not present → map content phase stays content with few/no pucks  
- Discover step uses global newest profiles (not contacts/mutuals ranking beyond excluding self/friends/blocks)  

There is **no demo/preview map in production post-auth**. Lab `OnboardingPreviewScreen` shows fixture pucks only under `--onboardinglab`.

---

## 10. Duplication / scatter outside a single onboarding feature

| Concern | Locations |
|---|---|
| Visual system | Lab theme/components shared with Auth + PostAuth; not full Design System catalog components (onboarding CTAs are domain-local per Agents.md) |
| Privacy choice model | Shared `OnboardingPrivacyOption`; Profile privacy UI is separate toggle maps |
| Location start | Onboarding Enable, `installPreparedLive`, `RootView.enter(.app)` — triple entry |
| Friend discovery | Onboarding `discoverPeople` vs Add Friends `searchPeople` — different APIs/UX |
| Auth gate vs lab | Parallel screen sets; lab phone + contacts not in production |
| “You’re in” done | Lab + PostAuthDoneScreen similar copy |
| Notification samples | Hardcoded in PostAuth + Lab fixtures |
| Progress chrome | Reimplemented in Auth gate vs PostAuth vs Lab |
| Legal | `LegalConsentText` on welcome only, not re-shown in post-auth |

---

## 11. DEBUG Onboarding Lab vs production post-auth

Lab flow order (fixture-driven):

```text
welcome → (google|phone→verify) → preview → profile → privacy
  → location → notifications → contacts → friends → done
sign-in path → done (skips setup)
```

Production post-auth omits: value **preview**, profile (already in auth), **contacts** permission, phone.

Production auth already owns welcome + profile + credentials before prepare.

---

## 12. Analytics & accessibility (current)

- **Analytics:** No onboarding funnel events found (no completion/drop-off instrumentation).  
- **A11y:** Some labels (back, photo picker); not a full VoiceOver/audit suite for every post-auth control. Dynamic Type relies on shared fonts with limited scaling review.

---

## 13. Tests covering this area

| Suite | Coverage |
|---|---|
| `PostAuthOnboardingTests` | Privacy mapping; mock discover; setGlobalDefaults; mock never needs onboarding; VM advances privacy→location, skip location, finish→done |
| `AuthViewModelTests` / `AuthBootstrapTests` | Auth gate / bootstrap (not full post-auth product flow) |

Gaps: denied location paths, early `installPreparedLive` prompt race, notification outcomes, complete_onboarding failure, resume/partial, invite variants (N/A).

---

## 14. Design-system implications (for later spec)

Existing reusable onboarding building blocks:

- Gradient shell, header, CTA, text button, glass card, mini-map, status chip, privacy rows, progress capsules  

Gaps vs Issue #63 catalog:

- Onboarding primaries remain domain-local (not yet `PushSolidSunbeamButton` alignment pass)  
- No standard “permission primer” component in DS  
- No shared empty-activation template for zero-friend post-onboarding  
- Demo/map teaching would need either lab mini-map promotion or a constrained map chrome reuse  

---

## 15. Audit summary for the revamp

**Works today**

- Clear live gate → prepare → binary onboarding flag → app  
- Privacy defaults + Ghost wiring to real sharing/presence  
- Skippable location & notifications; optional friends  
- Shared warm visual language with lab  

**Misaligned with Issue #134 goals**

1. **Location prompt timing race** with prepare/`installPreparedLive`  
2. Little **teach-then-ask** alternation (mostly ask/setup; no value preview in production)  
3. **Notifications** requested though backend push is not shipped  
4. **No invite-link** activation path  
5. **No partial progress** persistence  
6. **Activation** poorly defined — user can “complete” with no location, no friends, no notifications  
7. First map experience often **empty** without further teaching  
8. Contacts discovery only in DEBUG lab  
9. Duplicated location-start and parallel lab/production flows  

---

## Next steps (per issue)

1. Product interview (activation definition, permissions policy, invite variants, skippability, demo content, visual style).  
2. Proposed specification for approval.  
3. Implementation only after approval.
