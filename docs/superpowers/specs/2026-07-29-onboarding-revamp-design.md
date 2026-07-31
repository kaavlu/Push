# Onboarding Revamp — Design Spec (Issue #134)

**Date:** 2026-07-29  
**Status:** Approved  
**Issue:** https://github.com/kaavlu/Push/issues/134  
**Audit:** `docs/superpowers/specs/2026-07-29-onboarding-revamp-audit.md`  
**Approach:** 2 — Location-critical path first, soft graph last  

---

## 1. Goals

By the end of first-run, a new live user should:

1. **Grant when-in-use location** (required — product is location-core).
2. **Understand** that Push is a private live social layer for real friends (not a generic tracker).
3. **Understand** friends appear on the map with useful real-world context.
4. **Understand** Ghost mode exists and can be turned on later in the app (default: visible / publishing on).
5. **Understand** they can start / use / contribute to **Pushes** and **Moments**.
6. Have a chance (optional) to enable **notifications**, match **contacts**, and **add people already on Push**.
7. Land on the **live map** (empty-friends overlay is OK).

### Non-goals (v1)

- Invite-link / referral deep-link onboarding (footnote only; same organic flow for everyone).
- Phone auth, Sign in with Apple.
- Multi-option privacy picker (exact / vague / ghost) during onboarding.
- Choosing Ghost as a first-run mode that avoids location.
- Full feature tour, interactive live map during teaching, or demo seed friends in the real graph.
- Push notification **delivery** backend (primer may still request OS permission).
- Redesigning the auth gate (welcome / sign-up / sign-in) beyond what is needed to hand off cleanly.
- New isolated visual language — extend the existing onboarding lab shell.

### Length constraint

- Each **teaching section** (one concept: value/location reasoning, Ghost, coordinate/Pushes+Moments) is **at most 1–2 screens**.
- Prefer **1 screen per concept** unless a second screen is required for a permission primer immediately before a system dialog.
- Optional action steps (notifications, contacts, find people) are not “teaching tours”; each is **one screen**.

---

## 2. Success = activated user (v1)

A user is **activated** only when all of the following hold:

| Requirement | Rule |
|---|---|
| Authenticated + session prepared | Live container installed |
| Location authorization | OS when-in-use is **authorized** (`.authorizedWhenInUse` / always if already elevated — treat as success) |
| Onboarding completion flag | `profiles.onboarding_completed_at` set via `complete_onboarding` |
| Default sharing | Global defaults = **exact location + full activity + full availability**; presence **publishing on** |

**Not required for activation:** notifications allow, contacts allow, any friend requests, profile photo, completing optional steps with non-skip actions.

**Denied / restricted location:** user is **not** activated; must not receive `complete_onboarding` or enter `ContentView`.

---

## 3. Ordered screen and state flow

### 3.1 High-level bootstrap (live)

```text
Launch
  restoreSession?
    no  → Auth gate (unchanged product surface)
    yes → Prepare
Auth success → Prepare

Prepare
  prepareLive + installPreparedLive
  ⚠ MUST NOT request location here (fix race)
  soft-fail pending sign-up photo upload
  needsPostAuthOnboarding?
    false → App (map)   // may startIfEligible only here / when eligible
    true  → Post-auth onboarding flow
```

### 3.2 Auth gate (unchanged contract)

Keep existing multi-step email sign-up and sign-in:

| Screen | User provides |
|---|---|
| Welcome | Method choice (Google / email); legal consent |
| Sign-up profile | Name, handle; optional photo |
| Sign-up credentials | Email, password |
| Check email | — |
| Sign-in / forgot / set password | Credentials as today |

Profile essentials stay here — **no second profile step** in post-auth.

### 3.3 Post-auth onboarding spine (new)

Linear, non-skippable **structure**. Optional **actions** inside steps 5–7 only.

```text
Step 0  [internal] ensure defaults + entry
Step 1  Value / location reasoning     (teach, 1 screen)
Step 2  Location permission            (primer 1 screen → OS dialog)
        └─ Denied/Restricted → Location recovery (hard gate, not a teach tour)
Step 3  Ghost                          (teach, 1 screen)
Step 4  Pushes + Moments               (teach, 1 screen)
Step 5  Notifications                  (optional action, 1 screen)
Step 6  Contacts                       (optional action, 1 screen)
Step 7  Find people on Push            (soft nudge, 1 screen; 0 adds OK)
Step 8  Done                           (1 screen) → App
```

**Screen budget**

| Section | Screens | Notes |
|---|---|---|
| Value / why location | **1** | Static mini-map + copy; ends with Continue → location primer |
| Location | **1 primer** + recovery loop | Primer immediately before OS prompt; recovery is gate UI, not teaching |
| Ghost | **1** | |
| Pushes + Moments | **1** combined | Do not split into two tour screens |
| Notifications | **1** | Later skips |
| Contacts | **1** | Later skips |
| Find people | **1** | Continue with 0 |
| Done | **1** | |

**Total post-auth content screens:** 7 happy-path (+ recovery only if denied).  
Auth remains separate and already required for account creation.

### 3.4 State machine (conceptual)

```text
                    ┌──────────────────┐
                    │     prepare      │
                    └────────┬─────────┘
                             │ needs onboarding
                             ▼
                    ┌──────────────────┐
              ┌────►│      value       │
              │     └────────┬─────────┘
              │              │ continue
              │              ▼
              │     ┌──────────────────┐     enable
              │     │ locationPrimer   │──────────────► request OS when-in-use
              │     └────────┬─────────┘                      │
              │              │                         ┌──────┴──────┐
              │              │                         ▼             ▼
              │              │                   authorized     denied/restricted
              │              │                         │             │
              │              │                         │             ▼
              │              │                         │    ┌─────────────────┐
              │              │                         │    │ locationBlocked │◄── open Settings / retry
              │              │                         │    └────────┬────────┘
              │              │                         │             │ becomes authorized
              │              │                         ◄─────────────┘
              │              │                         │
              │              │                         ▼
              │              │                applySharingDefaults + start pipeline
              │              │                         │
              │              │                         ▼
              │     ┌──────────────────┐      ┌──────────────────┐
              │     │      ghost       │◄─────│  (advance)       │
              │     └────────┬─────────┘      └──────────────────┘
              │              │
              │              ▼
              │     ┌──────────────────┐
              │     │    coordinate    │  (Pushes + Moments)
              │     └────────┬─────────┘
              │              │
              │              ▼
              │     ┌──────────────────┐
              │     │  notifications   │── later / after prompt ──┐
              │     └──────────────────┘                          │
              │              │                                    │
              │              ▼                                    │
              │     ┌──────────────────┐                          │
              │     │    contacts      │── later / after prompt ──┤
              │     └──────────────────┘                          │
              │              │                                    │
              │              ▼                                    │
              │     ┌──────────────────┐                          │
              │     │   findPeople     │◄─────────────────────────┘
              │     └────────┬─────────┘
              │              │ continue (0+ adds)
              │              ▼
              │     complete_onboarding (requires location still authorized)
              │              │
              │              ▼
              │     ┌──────────────────┐
              │     │       done       │ → Open Push → .app
              │     └──────────────────┘
              │
              └── back navigation: allowed from ghost→coordinate→…→findPeople
                  back to locationPrimer only if still authorized or re-check;
                  back never bypasses hard location requirement.
                  value is first screen: no back (or back disabled).
```

Mock mode: still **skips** this entire post-auth flow (`needsPostAuthOnboarding == false`).

---

## 4. Purpose of every step

### Step 1 — Value / location reasoning (teach, 1 screen)

| | |
|---|---|
| **Learns** | Push is a private live map for real friends; friends show with context (place / activity / availability vibe); location is how that works — not surveillance theater. |
| **Provides** | Continue only. |
| **UI** | Lab-style static mini-map with fixture pucks (reuse / promote lab patterns). No live MapKit session required. |
| **Must not** | Request any OS permission. |

### Step 2 — Location permission (primer + OS + recovery)

| | |
|---|---|
| **Learns** | Why when-in-use is needed; nothing useful about *their* presence works without it; still private to friends under Push rules. |
| **Provides** | Primary: **Enable location** → system when-in-use dialog. **No “Not now”.** |
| **On Allow** | Start location pipeline (`startIfEligible` path); set global sharing defaults to exact+activity+availability full; ensure presence publishing **enabled**. Advance to Ghost. |
| **On Deny / Restricted** | Enter **locationBlocked** hard gate (see §5). Do not advance. Do not complete onboarding. |
| **If already authorized** (reinstall / flipped in Settings mid-flow) | Skip dialog; apply defaults + start pipeline; advance. |

### Step 3 — Ghost (teach, 1 screen)

| | |
|---|---|
| **Learns** | Ghost hides you from friends while you can still use the app; find it later in Profile; **default right now is visible**. |
| **Provides** | Continue only — **no Ghost toggle** in onboarding. |
| **Must not** | Call `setPresencePublishingEnabled(false)` or offer Ghost as default. |

### Step 4 — Coordinate: Pushes + Moments (teach, 1 screen)

| | |
|---|---|
| **Learns** | **Pushes** = low-pressure coordination (“who’s down”) without group-chat thrash; **Moments** = shared media from hangs on the Feed. User can start, join/RSVP, and contribute. |
| **Provides** | Continue only. Static illustration or simple cards — not a live create flow. |
| **Must not** | Split into two sequential tour screens; open Start Push / Create Post for real. |

### Step 5 — Notifications (optional, 1 screen)

| | |
|---|---|
| **Learns** | Gentle nudges when friends are near or plans kick off (honest: delivery may be limited until backend ships — copy should not over-promise if product still has no push pipeline; prefer “when we can notify you” / system permission for later use). |
| **Provides** | **Turn on** → `UNUserNotificationCenter.requestAuthorization`; **Maybe later** → advance. |
| **Denied** | Advance; not a gate. |
| **Already determined** | Don’t re-prompt thrash; advance with appropriate secondary CTA (“Continue”). |

### Step 6 — Contacts (optional, 1 screen)

| | |
|---|---|
| **Learns** | See who from Contacts is already on Push; Push won’t message contacts unless the user acts. |
| **Provides** | **Continue** → request Contacts access → show matches; **Not now** → advance to find-people (discover list only). |
| **Denied** | Advance; find-people still available via discover/search-style list. |
| **Matched list** | Tap to send friend request (same soft rules as find-people). Primary CTA still allows continuing with 0 adds. |

*Implementation note:* Production has no Contacts pipeline today (lab mock only). Phase contacts as P2 if needed; flow slot remains in the spec.

### Step 7 — Find people on Push (soft nudge, 1 screen)

| | |
|---|---|
| **Learns** | People already on Push; adding them makes the map useful. |
| **Provides** | Optional Add → `sendFriendRequest`; **Continue** / **Continue with N** always enabled (including 0). |
| **Empty discover** | Honest empty copy; still can finish. |
| **Load failure** | Inline error + retry; still can continue without adds. |

### Step 8 — Done (1 screen)

| | |
|---|---|
| **Learns** | They’re in; friends and map are the product. |
| **Provides** | **Open Push** → transition to main app. |
| **Completion** | Prefer calling `complete_onboarding` on leave of find-people (before Done) **only if location still authorized**; Done is celebration + entry. If complete fails, stay on find-people with retry (don’t show false Done). |

### Post-app: zero friends

- Enter **map** with existing empty treatment (`MapEmptyOverlay` / Add friends) — **not** a forced divert to Add Friends.
- Location already running from onboarding success path.

---

## 5. Permission matrix

### 5.1 Location (required)

| OS / user state | Onboarding behavior | `complete_onboarding` | Enter `.app` |
|---|---|---|---|
| notDetermined → Allow | Apply defaults, start pipeline, continue flow | Allowed later at finish | After Done |
| notDetermined → Deny | **locationBlocked** hard gate | **No** | **No** |
| restricted | Hard gate with restricted copy (Settings may not help) | **No** | **No** |
| previously denied, opens Settings, returns Allow | Re-check on foreground; exit gate; continue from Ghost (or resume cursor) | As normal | As normal |
| Skip control | **None** | — | — |

**locationBlocked UI**

- Explain Push needs location to work.
- Primary: **Open Settings**
- Secondary: **Try again** (re-call authorization / re-check status)
- Optional: Sign out (reuse root sign-out) so the user is not trapped without exit from the *account*, but they cannot enter the map shell.
- No “Continue without location.”

### 5.2 Notifications (optional)

| State | Behavior |
|---|---|
| Allow | Advance |
| Deny | Advance |
| Later | Advance without prompt |
| Error requesting | Advance or soft error; never hard gate |

### 5.3 Contacts (optional)

| State | Behavior |
|---|---|
| Allow | Show matches; continue with 0+ |
| Deny | Advance to find-people |
| Later | Advance |
| Restricted | Advance; empty matches |

### 5.4 Photos

- Only via existing sign-up `PhotosPicker` (auth). Not re-requested in post-auth.

---

## 6. Defaults applied when location is granted

Single write path on first successful authorization during onboarding:

1. `setGlobalDefaults(location: .exact, activity: .full, availability: .full)`  
2. `setPresencePublishingEnabled(true)`  
3. Align profile privacy toggles to “place + activity on, soft-place off” (same intent as today’s `.exactActivity` mirror), without showing a picker.  
4. `startIfEligible()` / ensure pipeline running.

If defaults write fails: show recoverable error on location step; **do not** advance or complete until defaults succeed or user retries (location may already be authorized — still block completion until policy write succeeds, so friends don’t see inconsistent first paint).

---

## 7. Returning, partial, and edge accounts

| Situation | Behavior |
|---|---|
| **Completed user** (`onboarding_completed_at` set) | Prepare → app; no post-auth flow |
| **New user** (null timestamp) | Full spine from Value |
| **Partial progress** (null timestamp, killed mid-flow) | Resume policy: **v1 = restart at Value** is acceptable; better: persist `onboarding_step` client-side or server later. **Minimum v1:** restart at Value but **re-check location** — if already authorized, skip primer dialog and jump to first incomplete *logical* step if cheap; else linear restart with auto-skip of location prompt when authorized |
| **Location denied then kill** | Still incomplete; re-enter flow → location primer/recovery |
| **needsOnboarding check fails** | **Must not** default to skip into app without location. Prefer fail closed: retry prepare UI or treat as needs onboarding if profile row missing completion. **Change from today:** replace `?? false` with safer handling (retry / fail prepare / assume incomplete when unknown) |
| **Mock** | No post-auth onboarding |
| **OAuth new user** | Same spine after prepare |
| **Invite-link user** | v1: **same organic flow** (no special path) |

### Invite-link (future footnote only)

Later phase may: deep link → auth → prepare → shorter social step with pre-associated friend/group. **Out of v1 implementation.**

---

## 8. Transition into main app

1. Location authorized + defaults applied.  
2. `complete_onboarding` succeeded.  
3. User taps **Open Push** (or auto-advance after short delay — prefer explicit CTA for control).  
4. `RootView` → `.app` → `ContentView`.  
5. `startIfEligible` allowed on app entry **only if** already authorized (no surprise dialog for completed users who somehow lost auth — if revoked later, handle in-app, not by re-running full onboarding unless product adds that later).  
6. Zero friends → map + empty overlay (Add friends).

**Revoking location after completion:** Out of first-run scope; existing/future in-app handling. Do not clear `onboarding_completed_at` automatically in v1.

---

## 9. Prepare / location race fix (mandatory)

Today `installPreparedLive` and `enter(.app)` can call `startIfEligible()` and trigger the OS prompt before any primer.

**Required behavior:**

| Call site | When onboarding incomplete | When complete / mock |
|---|---|---|
| `installPreparedLive` | **Do not** request authorization; may construct session but leave pipeline idle until onboarding enables it | May `startIfEligible` |
| Onboarding Enable location / post-Allow | **Only** place that first-requests for new users | — |
| `enter(.app)` | N/A (shouldn’t enter incomplete without location) | `startIfEligible` OK |

Implementation options (plan can pick): pass a flag, gate inside `LocationSession.startIfEligible` with an “onboarding holds prompt” policy, or split `prepareSessionWithoutLocationPrompt` vs `startIfEligible`.

---

## 10. Analytics events

No analytics stack is assumed; define **event names** for when instrumentation exists.

| Event | When | Props (suggested) |
|---|---|---|
| `onboarding_started` | Enter post-auth flow | `auth_method` |
| `onboarding_step_viewed` | Each step appear | `step` |
| `onboarding_step_completed` | Leave step successfully | `step` |
| `onboarding_location_prompt_shown` | Before/as OS prompt | |
| `onboarding_location_result` | After determination | `result=allow\|deny\|restricted\|already` |
| `onboarding_location_settings_opened` | Open Settings from gate | |
| `onboarding_notification_result` | | `result=allow\|deny\|later\|skipped` |
| `onboarding_contacts_result` | | `result=allow\|deny\|later` |
| `onboarding_friend_request_sent` | Each send | |
| `onboarding_find_people_continue` | | `added_count` |
| `onboarding_completed` | After RPC success | `duration_ms`, `added_count`, notif/contacts booleans |
| `onboarding_open_app` | Done CTA | |
| `onboarding_abandoned` | Sign out from flow / background kill if detectable | `last_step` |

Funnel drop-off = step_viewed without step_completed / completed.

---

## 11. Accessibility

- Every primary/secondary control has an accessibility label; permission primers explain purpose before the system dialog (VoiceOver order: title → body → CTA).
- Hard gate announces location required and focus moves to primary action.
- Dynamic Type: prefer existing onboarding fonts; avoid fixed heights that clip 1–2 line titles at larger sizes.
- Don’t rely on color alone for selected friend rows (checkmark + text).
- Reduce Motion: skip non-essential pulse rings on mini-map if `accessibilityReduceMotion` is on.
- Back chevron labeled “Back”; progress indicators are decorative (`accessibilityHidden`) with optional “Step x of y” on the screen title for VoiceOver.

---

## 12. Visual and components

**Style:** Extend current lab shell (warm gradient, `OnboardingHeader`, `OnboardingCTAButton`, mini-map, glass cards) shared with auth — not a new brand language.

**Design system**

| Need | Approach |
|---|---|
| Permission primer layout | Promote a reusable `OnboardingPermissionPrimer` (icon/hero, title, body, primary, optional secondary) used by location / notifications / contacts |
| Teaching screen | `OnboardingTeachScreen` (hero slot + header + CTA) |
| Hard gate | Variant of primer with no dismiss/skip |
| Progress | Existing capsule progress; map steps 1…N excluding recovery |
| Primary CTAs | Domain-local onboarding CTAs OK for v1 (Agents.md); optional later alignment to `PushSolidSunbeamButton` |

Do **not** invent one-off glass recipes outside onboarding tokens already used by the lab.

---

## 13. Copy outline (direction, not final marketing freeze)

| Step | Title direction | Body direction |
|---|---|---|
| Value | See what your friends are up to | Private live map for real friends — context without the group chat |
| Location | Push runs on location | How you show up and see who’s around; used for friends on Push |
| Location blocked | Location is required | Push can’t work without it; enable in Settings |
| Ghost | You’re visible to friends | Go invisible anytime with Ghost in Profile |
| Coordinate | Make plans. Keep moments. | Start a Push when something’s forming; share Moments from the hang |
| Notifications | Stay in the loop | Optional gentle nudges — not a feed of noise |
| Contacts | Find friends already here | We don’t text your contacts for you |
| Find people | Add people on Push | Continues even if the list is empty |
| Done | You’re in | Your map is ready |

Final copy pass can tighten without changing structure.

---

## 14. Architecture sketch (implementation later)

| Piece | Role |
|---|---|
| `PostAuthOnboardingViewModel` (evolve) | Screen state machine, permission orchestration, completion rules |
| `PostAuthOnboardingView` + screen splits | Dumb UI |
| `ProfileRepository.completeOnboarding` / `needsPostAuthOnboarding` | Unchanged RPC contract |
| `SharingRepository.setGlobalDefaults` | Defaults on location allow |
| `LocationSession` | Prompt only when onboarding asks; hard gate re-check |
| `FriendRepository.discoverPeople` / `sendFriendRequest` | Find people |
| New: Contacts matching (P2) | Permission + match against profiles (RPC TBD; may start with local numbers/emails hashed — **plan must not invent insecure bulk upload**; prefer Apple Contacts UI + existing search/discover constraints) |
| `RootView` | Bootstrap; fail-closed onboarding gate; no app without complete+location for new users |
| DEBUG lab | Optional later align to new spine; not blocking production |

---

## 15. Phased implementation plan

### Phase 0 — Foundation (must ship with any UI)

- Spec approval (this doc).
- Fix location prompt race (`installPreparedLive` / prepare path).
- Fail-closed `needsPostAuthOnboarding` error handling.
- Completion requires authorized location.
- Remove skip location; remove privacy multi-option step from production first-run (replace with defaults-on-allow).
- Hard location recovery UI.
- Unit tests for state machine + race + completion guards.

### Phase 1 — Core teach + location + finish

- Value (1), Location primer + gate, Ghost (1), Coordinate (1), Find people (1), Done (1).
- Wire defaults + `startIfEligible` only after allow.
- Notifications **and** Contacts **slots** can be temporarily skipped in navigation **only if** explicitly cut for a smaller PR — preferred: include Notifications (already exists) in Phase 1.

### Phase 2 — Notifications polish

- Optional notifications primer with honest copy; already-determined handling.

### Phase 3 — Contacts match

- Optional contacts permission + “on Push” list + send request.
- Privacy/App Store disclosure update (`docs/app-store-privacy.md`).
- Matching approach reviewed for security (no naive full address-book upload without design).

### Phase 4 — Analytics + lab alignment + invite footnote

- Event hooks.
- DEBUG lab spine parity (optional).
- Invite-link design spike (not build).

---

## 16. Focused test plan

### Unit / VM

- Step order advances only on allowed transitions.
- Location deny → blocked; no `completeOnboarding` call.
- Location allow → defaults invoked → ghost.
- Complete blocked if authorization lost before finish.
- Notifications later / deny still reach find people.
- Find people continue with 0 adds completes when location OK.
- Complete RPC failure stays off Done.
- Privacy picker path removed / not shown.
- Mock never enters flow.

### Integration / bootstrap

- `installPreparedLive` does not increment authorization request when onboarding incomplete (test double).
- New profile null `onboarding_completed_at` → onboarding; completed → app.
- needsOnboarding fetch failure does not silently enter app without location (new behavior).

### UI / manual

- First install: primer appears **before** system location dialog.
- Deny → Settings → Allow → return resumes.
- VoiceOver smoke on primer + hard gate.
- Zero friends after Done → map empty overlay.
- Sign out from hard gate returns to auth.

### Regression

- Returning user with location already allowed: no post-auth; map loads.
- Sign-up photo soft-fail still works.
- Auth recovery deep links unchanged.

### Suites to extend

- `PostAuthOnboardingTests` (primary).
- `AuthBootstrapTests` / location session container tests for prompt gating.
- New contacts tests when Phase 3 lands.

---

## 17. Open items resolved by interview

| Topic | Resolution |
|---|---|
| Activation | Location + understanding friends / Pushes·Moments / Ghost |
| Location | Forced; hard gate on deny |
| Ghost | Teach only; default visible |
| Notifications | Optional |
| Contacts | Optional |
| Find friends | Must show; 0 OK |
| Invites | Organic only v1 |
| Demo map | Static fixtures |
| Teaching | Linear; **≤1–2 screens per teaching section** (spec uses 1 each) |
| Empty map | Existing overlay |
| Profile | Auth only |
| Visual | Lab shell |

---

## 18. Approval checklist

Please confirm or amend:

- [ ] Approach 2 spine and step order  
- [ ] Location hard gate (no skip, no complete, no map)  
- [ ] One screen each for Value, Ghost, Coordinate (Pushes+Moments combined)  
- [ ] Optional Notifications + Contacts + soft Find people  
- [ ] Defaults = exact + activity, publishing on  
- [ ] Prepare/location race fix required in Phase 0  
- [ ] Fail-closed onboarding gate when completion state unknown  
- [ ] Phased contacts (P3) acceptable if core ships earlier  
- [ ] Invite links out of v1  

---

*After approval: write implementation plan (`docs/superpowers/plans/…`) via writing-plans skill; then implement. No production code before that.*
