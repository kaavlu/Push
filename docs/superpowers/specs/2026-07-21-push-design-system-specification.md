# Push Design System — Specification & Migration Plan

**Status:** Approved — **Waves 0–9 implemented** (Issue #63); system operational  
**Date:** 2026-07-21  
**Decision source:** `tasks/design-system-decision-log.md` (DS-001–DS-089)  
**Handoff:** `tasks/design-system-handoff.md`  
**Catalog:** `docs/design-system.md` (agent entry)  
**Code:** `Push/DesignSystem/`  
**Scope:** iOS SwiftUI UI centralization for discoverability and reuse by humans and coding agents  
**Non-goals this pass:** Visual redesign, onboarding/auth restyle into main app, freeform glass APIs, custom destructive alerts, Feed/activity-row design

---

## 1. Purpose

Push already has strong visual identity (walnut/sunbeam, cream pages, glass chrome, person rows, map pucks) but it is **fragmented**: feature-local `*Style` files, duplicated circular buttons, parallel person rows, multiple glass recipes, and empty-state forks. Agents recreate near-duplicates because there is no single catalog or module boundary.

This specification turns the interview decisions into:

1. An **approved inventory** of tokens, surfaces, and components  
2. **Agent rules** for discovery and reuse  
3. An **incremental migration plan** that preserves approved appearance  

**Specification is approved.** Do **not** start code until a session is explicitly tasked to implement (see handoff). Appearance-preserving extraction only — no redesign.

---

## 2. Principles

1. **You are the source of truth** for what remains. Similar is not automatically the same component unless the decision log says so.  
2. **Preserve approved appearance** during extraction — renames and file moves, not restyles.  
3. **Named surfaces only** — no public freeform tint/stroke/shadow knobs for feature code (DS-016).  
4. **Semantic components over mega-widgets** — person row, group row, request card stay separate (DS-023).  
5. **Discover before create** — catalog first; new families require a design-system decision (DS-086).  
6. **Onboarding/auth is temporarily separate** — domain-local until a future alignment pass (DS-006, DS-016, DS-048).

---

## 3. Code organization (post-approval)

### 3.1 Module home (DS-084)

```
Push/DesignSystem/
  README.md                 # Agent entry (mirrors docs catalog highlights)
  Tokens/
    PushColorTokens.swift   # Brand, text, cream roles, destructive, …
    PushAvailabilityTokens.swift
    PushTypographyTokens.swift
    PushSpacingTokens.swift   # or extend PushAdaptiveLayout
    PushRadiusTokens.swift
    PushMotionTokens.swift
    PushOpacityTokens.swift
  Surfaces/
    PushControlGlass.swift
    PushMapGlass.swift
    PushPuckGlass.swift
    PushPlansCardGlass.swift
    PushReviewDeckGlass.swift
    PushCreamSurfaces.swift   # page ivory + solid cream card
    PushModalBackground.swift
    # Onboarding surfaces stay under OnboardingLab/Auth until alignment
  Components/
    Buttons/
    Rows/
    Cards/
    Chips/
    Avatars/
    Navigation/
    Sheets/
    EmptyStates/
    Selectors/
  Catalog/                  # Optional DEBUG catalog previews
```

**Migration note:** Existing files may move incrementally; temporary typealiases (`typealias FriendsCircleButton = PushCircleIconButton`) keep the app compiling during renames.

### 3.2 Catalog & project guides (DS-085, DS-086)

| Artifact | Role |
|---|---|
| `docs/design-system.md` | Canonical agent catalog (when-to-use, do-not-recreate, DS links) |
| `Push/DesignSystem/README.md` | In-repo pointer + file map |
| `tasks/design-system-decision-log.md` | Product decisions (law) |
| `AGENTS.md` / `Claude.md` | Session resume → open catalog; hard bans |

### 3.3 Naming (DS-087)

| Kind | Convention | Example |
|---|---|---|
| System chrome | `Push…` | `PushCircleIconButton`, `PushPersonRow`, `PushSolidSunbeamButton` |
| Surfaces | `Push…` + role | `pushControlGlass`, `PushIvoryPageBackground` |
| Feature flows | Feature name OK | `StartPushFlowView`, `FriendsView` |
| Deprecated feature-prefixed shared chrome | Migrate | `FriendsCircleButton` → `PushCircleIconButton` |

---

## 4. Approved surface catalog (Category 2)

Feature code **selects a named surface**. No local glass/cream/gradient recipes.

| Surface | Decision | Use when |
|---|---|---|
| Generic control glass | DS-010 | Circular buttons, bottom nav, create menu, toasts, map empty overlay, lightweight floating chrome |
| Map glass family | DS-011 | Map top controls, filter pills, profile control, map popup sheets |
| Puck glass | DS-012 | Map annotations only |
| Plans card glass | DS-013 | Push cards & calendar module shell on cream pages |
| Review deck glass | DS-013 | Review swipe deck over gradient only |
| Ivory page | DS-014, DS-015 | Persistent destinations (Friends, Plans, Alerts, …) |
| Solid cream card | DS-014, DS-017 | Dense list cards on ivory |
| Modal gradient | DS-015 | Focused full-screen flows (Start Push, Profile, Review, …) |
| Onboarding/auth surfaces | DS-016 | Auth domain only; future alignment |

**Background rule (DS-015):** Ivory = browse/persist; Modal gradient = enter → complete → exit.

**If nothing fits:** reuse, add approved variant, or new named surface via design-system decision — never a local near-duplicate (DS-016).

---

## 5. Approved component catalog

### 5.1 Buttons & controls (Cat 1)

| Component / pattern | DS | Notes |
|---|---|---|
| `PushCircleIconButton` | DS-001 | Generic circular utility (same size); symbol + a11y; not map profile / nav+ / product-specific circles |
| Solid sunbeam primary CTA | DS-002 | Multi-step flows (Start Push, Add Group) |
| Glass + walnut-rim primary CTA | DS-002 | Plans “Start Push”; strong primary without solid fill |
| Recovery CTAs | DS-003 | Empty/error/retry use one of the two primaries only |
| Accept/Deny pair | DS-004 | Request UIs; states: accept, deny, resolving, disabled, added |
| Bottom nav center + | DS-005 | Nav-only |
| Onboarding/auth primary | DS-006 | Domain-only; future alignment |
| Create-menu icon circle | DS-007 | Menu/action-list only |
| Expandable action rail | DS-008, DS-028, DS-065 | Configurable actions; flush cream rail surface |
| System destructive confirms | DS-009 | confirmationDialog; no branded alert kit this pass |

### 5.2 Cards (Cat 3)

| Component / pattern | DS | Surface |
|---|---|---|
| Solid cream list-card foundation | DS-017 | Solid cream |
| Person row | DS-018, DS-027 | Cream foundation |
| Group row | DS-019 | Cream foundation |
| Request cards (person/group variants) | DS-020, DS-030 | Cream + Accept/Deny lifecycle |
| History row | DS-021 | Cream foundation |
| Action error banner | DS-022 | Cream foundation; not a list identity row |
| Plans-glass plan card (owner / invited) | DS-024 | Plans card glass |
| Review deck card | DS-025 | Review deck glass; share subcomponents only |
| Weekly calendar module | DS-026 | Standalone; appearance frozen; day tiles internal |
| Create-action menu panel | DS-026 | Control glass + menu icons |
| Map empty overlay | DS-026, DS-072 | Control glass |
| Modal settings cards | DS-026 | Modal gradient |
| Modal selection rows | DS-026, DS-031 | Modal gradient |

**New card process (DS-026):** Surface → existing component → extend → new layout only if needed → DS decision for new family/recipe. New layout ≠ new surface.

### 5.3 Rows & people (Cat 4)

| Pattern | DS | Rule |
|---|---|---|
| Flat person row | DS-027 | **Default** for person lists |
| Expandable wrapper | DS-028 | Optional; owns expand + rail + confirms |
| Group members | DS-029 | Flat row + trailing/overflow (not Friends rail) |
| Request lifecycle | DS-030 | Owned by request-card system |
| Ivory discovery vs modal multi-select | DS-031 | Two systems; share primitives only |
| Blocked users | DS-032 | Person row config (handle, neutral ring, Unblock) |
| Feed/activity rows | DS-033 | Deferred until Feed ships |
| Alerts structure | DS-034 | Section headers + request cards |
| Nested participant rows / avatar strips | DS-034, DS-053 | Subcomponents; no cream list shells |

### 5.4 Selectors (Cat 5)

| Pattern | DS |
|---|---|
| Ivory segmented mode switch | DS-035 |
| Ivory filter chips (walnut selected) | DS-036 |
| Map dropdown shell + shared sunbeam+check row primitive | DS-037 |
| Bottom-nav selection | DS-038 (scoped) |
| Modal choice pills + date/time pickers | DS-039 |
| Settings checkmark rows | DS-040 |
| Calendar week chevrons | DS-041 (module-local) |
| Fixed selector menu | DS-042 |

### 5.5 Status chips (Cat 6)

| Pattern | DS |
|---|---|
| Availability token table | DS-043 (preserve freeSoon vs maybeDown chip fills) |
| Compact availability chip (+ sheet size variant) | DS-044 |
| Map activity badge | DS-044 |
| Brand sunbeam pill (profile / plan time / group status) | DS-045 |
| Plan status pill | DS-046 |
| Live dot + timestamp | DS-047 |
| Onboarding chips | DS-048 (domain) |
| Chip menu rule | DS-049 |

### 5.6 Avatars & pucks (Cat 7)

| Pattern | DS |
|---|---|
| Person avatar (dark / sunbeam fallback) | DS-050 |
| Rings: static / pulse / neutral; self rings on self puck | DS-051 |
| Map puck family (friend, group/cluster, regional, self) | DS-052 |
| Avatar stack vs horizontal strip | DS-053 |
| Group list avatar + group hero | DS-054 |
| Profile hero | DS-055 |
| Avatar/puck menu rule | DS-056 |

### 5.7 Navigation (Cat 8)

| Pattern | DS |
|---|---|
| Bottom nav (map shell only) | DS-057 |
| Map top chrome | DS-058 |
| fullScreenCover + nesting | DS-059 |
| Cream page header | DS-060 |
| Modal flow chrome | DS-061 |
| Create menu hub + text links | DS-062 |
| Map attribution margins | DS-063 |

### 5.8 Sheets & actions (Cat 9)

| Pattern | DS |
|---|---|
| Map bottom-sheet chrome | DS-064 |
| Expandable rail surface | DS-065 |
| System Menu / contextMenu / confirmationDialog | DS-066 |
| Sheet vs fullScreen rule | DS-067 |
| Toast (reference → centralize on 2nd use) | DS-068 |
| Sheet/action menu rule | DS-069 |

### 5.9 Empty / loading / error (Cat 10)

| Pattern | DS |
|---|---|
| `SurfaceContentPhase` | DS-070 |
| EmptySurface empty/loading/failed | DS-071 |
| Map overlay empty/failed | DS-072 |
| Mutation banner vs load fail vs soft reload | DS-073 |
| Deferred empty | DS-074 |
| Inline no-results + local busy | DS-075 |
| Empty/error menu rule | DS-076 |

---

## 6. Token system (Category 11)

| Token domain | DS | Rules |
|---|---|---|
| Color | DS-077 | Semantic only in features; no hex/RGB |
| Typography | DS-078 | Semantic SF first; rounded limited; section-label style |
| Spacing | DS-079 | `PushAdaptiveLayout` cross-screen; no ad-hoc page margins |
| Radii | DS-080 | Named roles; continuous corners |
| Borders / shadows | DS-081 | Inside named surfaces; no freeform elevation API; no black shadows |
| Motion | DS-082 | selection, expand, sheet, press, map pulse |
| Opacity / min scale | DS-083 | disabled, inactive, scrim, minimumTextScale |
| Discipline | DS-083 | New values → token or DS decision |

Cream roles (DS-014): page ivory, solid card cream, glass-card fill, generic glass tint, secondary accents, divider/metadata cream — consolidate literals without flattening Plans glass appearance.

---

## 7. Agent operating rules (Category 12)

### 7.1 Mandatory checklist (DS-086)

1. Open `docs/design-system.md` (and decision log if changing families).  
2. Choose **surface** from §4.  
3. Choose **component** from §5.  
4. Prefer **variant/slot** over new type.  
5. If no fit → **propose design-system decision**; do not ship a near-duplicate.

### 7.2 Hard bans (DS-088) — for AGENTS.md after approval

- No new glass/material/cream recipes in feature files  
- No `.borderedProminent` as product chrome  
- No second person-row, circular utility button, or full empty/error implementation  
- No raw color literals in feature views  
- No third primary CTA treatment  
- No DIY live-map pucks  
- No custom popover/action panels (use system Menu/contextMenu/confirmationDialog)  
- No secondary tab bars on ivory screens  

### 7.3 Allowed feature-local (DS-088)

Screen composition, ViewModels, routing, unique copy, DS-approved one-offs, onboarding/auth domain until alignment.

### 7.4 Previews (DS-089)

Every system component ships `#if DEBUG` previews; use `PushPreviewMatrix` for adaptive-sensitive chrome.

---

## 8. Migration plan

### 8.1 Goals

- Extract without visual change  
- Point call sites at system types  
- Delete forks (`BlockedPersonRow`, inline close buttons, empty-state clones, `.borderedProminent` recovery)  
- Document as you go (catalog + decision log sync)

### 8.2 Non-regression rules

- Prefer screenshot/comparison on cream pages, map chrome, plan cards, Start Push  
- Scoped tests per area (`scripts/test.sh suite …`) after each wave  
- `scripts/test.sh build` minimum per wave; `full` before PR  

### 8.3 Waves (DS-089 priority)

#### Wave 0 — Scaffolding (no visual change)

- Create `Push/DesignSystem/` skeleton + README  
- Add `docs/design-system.md` catalog (inventory from this spec)  
- Link from `AGENTS.md` / `Claude.md`  
- Optional: re-export shims so existing imports keep working  

**Exit:** Agents have a discoverable home; app unchanged.

#### Wave 1 — Buttons & primary CTAs

- `PushCircleIconButton` ← FriendsCircleButton, PushModalIconButton, Start Push/Add Group close/back/trash  
- `PushSolidSunbeamButton` ← StartPushPrimaryButton  
- `PushGlassRimButton` ← Plans StartPlanButton  
- Replace empty/error `.borderedProminent` with branded CTAs  
- Create-menu icon circle as named style  
- Accept/Deny remains shared; ensure all request UIs use it  

**Exit:** No generic circular utility reimplementation; two named primaries only.

#### Wave 2 — Cream list foundation & person system

- Solid cream foundation + ivory page as system surfaces  
- `PushPersonRow` ← FriendRowCard; migrate BlockedUsers  
- Expandable wrapper + rail extraction  
- Group row, request cards, history row on foundation  
- ActionErrorBanner on foundation  
- Section header shared for Alerts/Friends  

**Exit:** No BlockedPersonRow fork; list density unified.

#### Wave 3 — Empty / loading / error

- EmptySurface family as sole full-page states  
- Migrate Blocked/Add Friends/Friends empty forks  
- Map overlay branded CTAs  
- Document error-routing (load vs mutation vs soft reload)  

**Exit:** One empty/loading/failed language; banner for mutations.

#### Wave 4 — Named surfaces

- Promote control glass, map glass, puck glass, plans card glass, review deck glass, modal gradient  
- Cream token consolidation (preserve Plans glass look)  
- Remove private duplicate surface modifiers where possible  

**Exit:** Feature code only calls named surface APIs.

#### Wave 5 — Availability, chips, avatars, pucks

- Availability token module  
- Shared availability chip; migrate Friend Detail inline chips  
- Brand sunbeam pill primitive  
- Person avatar fallback variants; merge RecipientAvatarView  
- Document map puck family (already components — ensure catalog + no DIY)  

**Exit:** One availability color path; one person avatar API.

#### Wave 6 — Selectors, navigation chrome, sheets

- Ivory segmented switch + filter chips extraction  
- Map dropdown + single-select row primitive  
- Modal choice pills + date/time pickers naming  
- Cream page header + modal flow chrome  
- Map bottom-sheet chrome extraction  
- Text link style  

**Exit:** Headers/sheets/selectors discoverable as system pieces.

#### Wave 7 — Plan cards & subcomponents

- Plans-glass plan-card family (owner/invited)  
- Review card separate; extract shared subcomponents (status pill, avatar strip, metadata)  
- Calendar module left whole (no redesign)  

**Exit:** Plan UI reuses one plan-card family + subcomponents.

#### Wave 8 — Tokens & motion cleanup

- Color/type/radius/motion/opacity tokens  
- Replace scattered springs with `PushMotion`  
- Sweep remaining magic numbers in migrated files  

**Exit:** Token discipline enforceable via catalog + code review.

#### Wave 9 — Docs polish & optional lint

- Complete catalog “do not recreate” list  
- Update Design/ theme audit pointer if needed (read-only)  
- Optional banned-API notes for future lint (not required)  

**Exit:** Specification fully operational for agents.

### 8.4 Explicitly deferred

| Item | When |
|---|---|
| Onboarding/auth visual alignment with main app | Future DS pass |
| Feed / activity-row system | When Feed is implemented |
| Custom branded destructive alerts | Future DS pass |
| Freeform parametric glass API | Never (unless decision overturns DS-016) |
| Calendar day tiles as global card type | Not this pass |
| Unifying Review + Plans cards into one component | Not this pass |

### 8.5 Suggested verification per wave

| Wave | Tests / checks |
|---|---|
| 0 | build |
| 1–3 | EmptySurfaceTests, relevant UI-adjacent suites, build |
| 4–5 | MapRenderTests, AdaptiveLayoutTests, build |
| 6–7 | PushLifecycleTests / Plans-related if present, build |
| 8–9 | full before merge |

---

## 9. Success criteria

1. A new agent can open `docs/design-system.md` and find the correct component for circular buttons, person rows, empty states, and surfaces without reading the entire app.  
2. No second implementation of person-row, circular utility button, control glass, or full empty/error chrome.  
3. Ivory list UI shares cream foundation; plan cards share Plans glass family; map chrome stays map glass.  
4. Primary CTAs are only solid sunbeam or glass+rim.  
5. Appearance matches pre-migration approved UI (pixel-level intent, not redesign).  
6. Decision log and catalog stay synchronized.

---

## 10. Approval gate

| Item | Status |
|---|---|
| Specification matches interview decisions | **Approved** (2026-07-21) |
| Migration wave order | **Accepted** as written (§8.3) |
| Module path | **`Push/DesignSystem/`** |
| Implementation | **Complete** — Waves 0–9 (Issue #63); catalog operational |

Ongoing work: open `docs/design-system.md` first; new families need an explicit design-system decision.

---

## 11. Decision index

Full detail: `tasks/design-system-decision-log.md`.

| Range | Topic |
|---|---|
| DS-001–009 | Buttons & circular controls |
| DS-010–016 | Surfaces & backgrounds |
| DS-017–026 | Cards |
| DS-027–034 | Rows & people |
| DS-035–042 | Selectors |
| DS-043–049 | Status chips |
| DS-050–056 | Avatars & pucks |
| DS-057–063 | Navigation |
| DS-064–069 | Sheets & modal actions |
| DS-070–076 | Empty / loading / error |
| DS-077–083 | Tokens |
| DS-084–089 | Agent discovery & migration |
