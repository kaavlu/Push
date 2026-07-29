# Push Design System — Living Decision Log

_Interview complete (Categories 1–12). Decisions DS-001–DS-089. Specification approved. Waves 0–9 implemented (Issue #63) — system operational via `docs/design-system.md` and `Push/DesignSystem/`. Handoff history: `tasks/design-system-handoff.md`._

## Status

| Category | Status |
|---|---|
| 0. Audit overview | Complete (discovery only) |
| 1. Buttons & circular icon controls | **Confirmed** (DS-001–DS-009) |
| 2. Glass surfaces & backgrounds | **Confirmed** (DS-010–DS-016) |
| 3. Cards | **Confirmed** (DS-017–DS-026) |
| 4. Friend / member / request / activity rows | **Confirmed** (DS-027–DS-034) |
| 5. Selectors, dropdowns, segmented controls | **Confirmed** (DS-035–DS-042) |
| 6. Status & availability chips | **Confirmed** (DS-043–DS-049) |
| 7. Avatars, stacks, map pucks, rings | **Confirmed** (DS-050–DS-056) |
| 8. Navigation elements | **Confirmed** (DS-057–DS-063) |
| 9. Sheets, expanded rows, modal actions | **Confirmed** (DS-064–DS-069) |
| 10. Empty / loading / error states | **Confirmed** (DS-070–DS-076) |
| 11. Typography, spacing, radii, borders, shadows, color, motion | **Confirmed** (DS-077–DS-083) |
| 12. Agent discovery & recreation patterns | **Confirmed** (DS-084–DS-089) |

## Decision entries

### Entry template

```
### DS-XXX — [existing UI]
- **My decision:**
- **Must remain consistent:**
- **May vary:**
- **Reuse required for future features:** yes / no / with variants
- **Existing screens need migration:** yes / no / selective
- **Recommended mechanism (if approved):** exact component | base+variants | style | token | reference only | one-off
```

---

## Category 1 — Buttons & circular icon controls

**Source of truth:** User final decisions (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-001 — Generic circular icon buttons (B1)

- **Existing UI:** Friends/Alerts/Blocked header circles (`FriendsCircleButton`); modal close (`PushModalIconButton` / `PushModalCloseButtonBar`); Start Push & Add Group close / back / trash (inline duplicates). Same-size generic utility circles elsewhere.
- **My decision:** Centralize generic circular icon buttons that share the same dimensions and generic navigation/utility role into **one reusable component**. Do **not** force every circular control into this family solely because it is circular.
- **Must remain consistent:** Size, surface treatment, border, icon treatment, press behavior, hit area for members of this family.
- **May vary:** SF Symbol, accessibility label. Purpose-specific controls stay custom when size or role differs intentionally.
- **In scope examples:** Friends buttons, Alerts buttons, Close/X, Back, other same-size generic circular icon controls.
- **Out of scope for now (remain custom):** Smart Push, Add Group product controls (when presentation is distinct), map profile controls, other product-specific circular actions with intentionally different presentation.
- **Reuse required for future features:** **Yes** — if circular + same dimensions + generic nav/utility action → must use the shared component.
- **Existing screens need migration:** **Yes** — unify Friends, Alerts, modal close/back, Start Push / Add Group inline close/back/trash onto the shared component; leave map profile / product-specific controls alone unless later decided.
- **Recommended mechanism:** Exact shared component (symbol + a11y params; fixed chrome).

### DS-002 — Primary in-app CTA styles (B2 + B3)

- **Existing UI:** Solid sunbeam capsule (`StartPushPrimaryButton` in Start Push / Add Group flows); glass capsule with walnut rim (Plans “Start a Push” CTA).
- **My decision:** Keep the two appearances **intentionally different**. Centralize both as **named, reusable Push button styles** (two approved styles, or one component with two explicit visual variants). Do **not** collapse into one look. Do **not** invent a third primary CTA treatment without a design-system decision.
- **Must remain consistent:**
  - **Solid sunbeam capsule** — solid sunbeam fill, walnut label, capsule geometry, disabled treatment as used in multi-step flows.
  - **Glass + walnut rim** — lighter glass fill, stronger walnut rim, capsule geometry as used on the Pushes tab primary CTA.
- **May vary:** Title/label, enabled state, width/placement constraints within the approved style, adaptive height within system metrics.
- **Approved usage:**
  - **Solid sunbeam:** Start Push, Add Group, similar multi-step creation/completion flows.
  - **Glass + walnut rim:** “Start a Push” on Pushes tab; other surfaces that need a strong primary without solid sunbeam fill.
- **Reuse required for future features:** **Yes** — agents must deliberately choose one of the two approved variants; no local recreation.
- **Existing screens need migration:** **Yes** — extract Plans and Start Push / Add Group CTAs into the shared named styles/component.
- **Recommended mechanism:** Shared component with two explicit visual variants, or two named reusable styles.

### DS-003 — Empty / retry / failure / recovery actions (B7)

- **Existing UI:** `EmptySurfaceView` / `EmptySurfaceStateView.failed` / Blocked failed path using system `.borderedProminent` + sunbeam tint.
- **My decision:** **Do not** keep native `.borderedProminent` as a separate visual family for empty, error, retry, or recovery actions. Use one of the two approved branded primary CTA styles (DS-002) based on importance and surrounding surface.
- **Must remain consistent:** Recovery CTAs use only approved branded Push CTA styles (solid sunbeam or glass + walnut rim).
- **May vary:** Which of the two styles is chosen for a given surface; copy; presence of secondary actions.
- **Reuse required for future features:** **Yes** — no new system-style recovery buttons.
- **Existing screens need migration:** **Yes** — empty/error/retry surfaces that use `.borderedProminent`.
- **Recommended mechanism:** Reuse DS-002 primary CTA variants (not a third family).

### DS-004 — Accept / Deny request actions (B4)

- **Existing UI:** `AlertActionButton` + `AlertAddedBadge` (Alerts friend requests, group invites; Add Friends request rows).
- **My decision:** Required **shared component pair** for all request/approval interfaces with the same interaction model.
- **Must remain consistent:** Accept / Deny visual treatments; resolving/loading; disabled; Added/accepted confirmation states as approved today.
- **May vary:** Accessibility labels; which request entity (friend vs group vs future invite types); surrounding row layout.
- **Reuse required for future features:** **Yes** — friend requests, group invites, future approval/invitation surfaces.
- **Existing screens need migration:** **Selective** — already largely shared; ensure all request UIs and any outliers call the shared component only.
- **Recommended mechanism:** Exact shared component pair (with state machine for resolving / added).

### DS-005 — Bottom-navigation center “+” (B5)

- **Existing UI:** Raised material circle in `BottomNavigationBar` (primary create slot).
- **My decision:** Keep **scoped to bottom navigation**. Do not fold into generic circular icon-button family (DS-001) or reuse elsewhere as a generic action button.
- **Must remain consistent:** Elevation, selection scale, glow, stroke, nav-only role within bottom nav.
- **May vary:** N/A outside bottom nav (not reused).
- **Reuse required for future features:** **No** (nav-scoped only).
- **Existing screens need migration:** **No**.
- **Recommended mechanism:** Navigation-specific / one-off component.

### DS-006 — Onboarding & authentication primary buttons (B8)

- **Existing UI:** Dark brown gradient CTA (`PushOnboardingControlStyle` / onboarding auth components) on onboarding lab + production auth.
- **My decision:** Keep as a **separate reusable UI family for now**. Centralize within onboarding/auth domain. Do **not** migrate to in-app CTA styles (DS-002) in this design-system pass. Do **not** use onboarding/auth buttons inside the main application. Separation is **temporary**, not a permanent principle — document as **future alignment** with the broader Push design system.
- **Must remain consistent (within domain):** Current onboarding/auth button treatment while this pass runs.
- **May vary:** Screen-specific labels and enabled state within auth flows.
- **Reuse required for future features:** **Yes within onboarding/auth only**; **no** for main app.
- **Existing screens need migration:** **Within domain only** (centralize if duplicated); **no** cross-app restyle yet.
- **Recommended mechanism:** Domain-scoped shared component/style + explicit “future alignment” note in the eventual spec.

### DS-007 — Create-menu sunbeam icon circles (B6)

- **Existing UI:** Sunbeam-filled circular icons in `CreateActionMenuView` rows.
- **My decision:** Centralize as a **reusable menu icon style** for action menus and menu-like rows. Scope to menu / action-list contexts only.
- **Must remain consistent:** Sunbeam-filled circle + icon treatment used in create menu rows.
- **May vary:** SF Symbol, label row content around the icon.
- **Must stay distinct from:** DS-001 glass circular icon buttons; DS-005 nav “+”; map profile controls; other product-specific circular actions.
- **Reuse required for future features:** **Yes** for menu / action-list contexts; **no** as a generic app-wide circular button.
- **Existing screens need migration:** **Selective** — extract create menu to named style/component; apply when similar menus appear.
- **Recommended mechanism:** Shared style or small menu-scoped component.

### DS-008 — Expandable row action rail (B9)

- **Existing UI:** `ExpandableFriendRow` action rail (Directions, Start push, overflow Remove/Block) under Friends list rows.
- **My decision:** Promote to a **reusable pattern** for future person and group rows. Friends implementation is the initial visual/behavioral reference; actions are context-configurable.
- **Must remain consistent:** Layout, spacing, button treatment, expand/collapse behavior, animation timing, alignment with parent row, overflow handling.
- **May vary:** Action set by feature (e.g. Directions, Start Push, Remove Friend, View Group, Manage, overflow items).
- **Reuse required for future features:** **Yes** — do not rebuild the rail independently per row type.
- **Existing screens need migration:** **Yes** — extract Friends rail into the shared pattern; adopt when other rows need expansion.
- **Recommended mechanism:** Shared base with configurable actions (not a fixed action list).

### DS-009 — Destructive confirmations (B10)

- **Existing UI:** System `confirmationDialog` / destructive roles for delete, remove, block, cancel push, etc.
- **My decision (historical, Issue #63):** Keep **native** system destructive confirmation flows for the design-system extraction pass. Do **not** build a custom branded destructive-alert system in Waves 0–9.
- **Superseded by:** **DS-090** (Issue #83) for destructive confirmation presentation. System dialogs remain for multi-action photo menus only.
- **Must remain consistent:** Explicit confirmation before irreversible actions (now via DS-090 chrome).
- **May vary:** Copy and action titles per flow.
- **Reuse required for future features:** **Yes** — use DS-090 `.pushConfirmation` for destructive confirms.
- **Existing screens need migration:** **Yes** under DS-090.
- **Recommended mechanism:** Shared Push confirmation dialog family (DS-090).

---

## Category 1 — Agent rules (summary for future implementation)

1. **Generic circular utility buttons** (same size + generic nav/utility role) → DS-001 shared component.
2. **Primary in-app CTAs** → choose only **solid sunbeam** or **glass + walnut rim** (DS-002); recovery/empty actions also use these (DS-003), never `.borderedProminent` as a design family.
3. **Request Accept/Deny** → DS-004 shared pair with approved states.
4. **Bottom nav “+”** → DS-005 nav-only.
5. **Onboarding/auth CTAs** → DS-006 domain family only; future alignment planned.
6. **Create-menu icon circles** → DS-007 menu-scoped style.
7. **Expandable row actions** → DS-008 reusable rail pattern.
8. **Destructive confirms** → DS-090 `.pushConfirmation` (DS-009 superseded for destructive).

---

## Category 2 — Glass surfaces & backgrounds

**Source of truth:** User final decisions (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-010 — Generic control glass (G1)

- **Existing UI:** `pushGlassBackground` — bottom nav chrome, generic circular icon buttons, create-action menu card, map empty overlay card, toast-style controls, Plans Start Push CTA base glass.
- **My decision:** Canonical **generic control glass** for standard app controls and floating chrome outside the map-specific family. Default glass primitive for general-purpose controls. Centralize and name explicitly; do not merge with map or puck glass.
- **Must remain consistent:** Current warm material glass recipe (iOS 26 `glassEffect` + warm cream tint + white stroke + walnut-amber shadow; material fallback path).
- **May vary:** Corner radius / shape only as applied by the host control; not freeform tint/stroke/shadow knobs in feature code.
- **Appropriate uses:** Generic circular icon buttons, bottom nav chrome, floating controls outside map family, create-action menus, toast-style controls, similar lightweight interface chrome.
- **Reuse required for future features:** **Yes** for general-purpose control chrome.
- **Existing screens need migration:** **Selective** — ensure call sites use the named surface; no visual redesign.
- **Recommended mechanism:** Named shared style/modifier (`controlGlass` / existing `pushGlassBackground` elevated to system name).

### DS-011 — Map glass family (G4 + G5)

- **Existing UI:** `topControlBackground` (map profile, filter pill, dropdown panel); `MapPopupSheetBackground` (friend detail sheet, day-detail sheet).
- **My decision:** Distinct **map-scoped glass family**. May include separate named styles for map top controls, filter pills, profile controls, and popup sheets. Variants may share map-specific tint/glow/reflection/edge tokens but remain distinct components where shape or behavior differs. **Do not** replace with generic control glass — richer map treatment is intentional over imagery.
- **Must remain consistent:** Map-expressive cream-glass language (glow, reflective highlight, readability on satellite); family distinction from DS-010 and DS-012.
- **May vary:** Named sub-styles within the family (control vs filter vs profile vs sheet); shape.
- **Reuse required for future features:** **Yes** for map overlay chrome and map popup sheets.
- **Existing screens need migration:** **Yes** — extract private map treatments into named map glass styles.
- **Recommended mechanism:** Named family with explicit variants (not one mega-component forced on all shapes).

### DS-012 — Puck glass (G6)

- **Existing UI:** `puckGlassBackground` on friend/cluster pucks and day-detail mini avatars.
- **My decision:** Keep **distinct and restricted to map annotations**. Cooler white tint and lighter material stay separate from warm cream control glass. Do **not** use for buttons, cards, sheets, or general chrome.
- **Must remain consistent:** White-tint material + white stroke treatment used on annotations.
- **May vary:** Size/shape of annotation host.
- **Appropriate uses:** Friend pucks, group/cluster pucks, mini map avatars, annotation-adjacent avatar treatments.
- **Reuse required for future features:** **Yes** within annotation contexts only; **no** for UI chrome.
- **Existing screens need migration:** **Selective** — name and document; keep visual as-is.
- **Recommended mechanism:** Named style (`puckGlass`), annotation-scoped.

### DS-013 — Plans card glass & Review deck glass (G2 + G3)

- **Existing UI:** `plansGlassCard` (YourPushCard, ActivePlanCard, calendar module); `reviewGlassCard` (ReviewPushCard deck).
- **My decision:** Keep **both** as approved, centralized, **named** card-glass styles. Do not collapse. Do not recreate locally.
  - **Plans card glass:** Cards/modules on flat cream pages (Your/Active push cards, calendar, similar prominent cream-page cards). Preserve stronger walnut rim, layered strokes, warm fill, cream-page readability.
  - **Review deck glass:** Premium swipe decks or comparable cards **over gradient backgrounds**. Preserve greater translucency, reflective sheen, layered edges, softer/larger shadow, gradient show-through. **Restricted use** — not a general cream-page card treatment.
- **Must remain consistent:** Each style’s current approved appearance (no silent visual merge).
- **May vary:** Content layout inside the card; corner radius via system metrics where already adaptive.
- **Reuse required for future features:** **Yes** — choose the correct named style by context.
- **Existing screens need migration:** **Yes** — extract to system-named styles; preserve appearance during cream-token consolidation (see DS-014).
- **Recommended mechanism:** Two named shared styles/modifiers.

### DS-014 — Cream page + solid cream card + cream tokens (G7 + G8)

- **Existing UI:** `FriendsBackground` / `FriendsColor.pageIvory`; `.friendsCard` solid cream + walnut stroke; residual `PlansColor.creamBase` / `creamSoft` and related literals.
- **My decision:**
  - **One shared flat ivory page background** for cream-page destinations.
  - **One shared solid cream-card surface** based on current Friends treatment (opaque fill + subtle walnut border) for dense list content.
  - Keep solid cream card **distinct** from Plans card glass — list cards must not automatically become material glass.
  - **Consolidate** duplicate/residual cream literals into centralized **semantic** tokens (page ivory, solid card cream, glass-card fill, generic glass tint, secondary cream accents, divider/metadata cream). Do **not** force all cream values to one numeric color. Preserve Plans glass **approved appearance** during token migration.
- **Must remain consistent:** Ivory page fill; solid card cream + walnut border for list rows; semantic role separation in tokens.
- **May vary:** Content inside cards; which semantic cream token a surface consumes internally.
- **Appropriate solid-card uses:** Friend rows, group rows, request rows, expandable rows, history rows, similar dense list content.
- **Reuse required for future features:** **Yes** for cream pages and solid list cards.
- **Existing screens need migration:** **Yes** — cream destinations and solid cards onto shared page/card; token consolidation without visual change to Plans glass.
- **Recommended mechanism:** Named page background + named solid card style + internal semantic cream tokens.

### DS-015 — Modal gradient vs flat ivory (G9)

- **Existing UI:** `PushModalBackground` (Profile, Start Push, etc.); `FriendsBackground` ivory (Friends, Plans, Alerts, etc.).
- **My decision:** Explicit background rule for future screens:
  - **Flat ivory** — persistent navigation destinations; information-heavy / regularly browsed screens; list, management, history. Examples: Friends, Groups, Alerts, Plans, Plans history, similar primary destinations.
  - **Modal gradient** — focused full-screen flows; temporary task-oriented experiences; creation/editing; review experiences; enter → complete/inspect → exit. Examples: Start Push, Add Group, Profile editing, Review flows, similar modal-style experiences.
- **Must remain consistent:** Agents follow this distinction, not preference or proximity to another feature.
- **May vary:** Content; which flow pattern a new screen falls into (must be classified).
- **Reuse required for future features:** **Yes** — choose ivory page (DS-014) or shared modal gradient by rule.
- **Existing screens need migration:** **Selective** — only if any screen is on the wrong background per this rule (audit at implementation); no redesign of correct usages.
- **Recommended mechanism:** Named `ivoryPage` + named `modalGradient` backgrounds + documented selection rule.

### DS-016 — Onboarding/auth surfaces + constrained surface API (G10 + API)

- **Existing UI:** Onboarding screen gradients, `pushOnboardingGlassBackground`, auth/onboarding domain tokens.
- **My decision (surfaces):** Keep onboarding/auth backgrounds and glass **centralized within their domain** for this pass. Preserve current family; do not migrate to primary Push surfaces; do not reuse onboarding styles in main app; do not restyle onboarding with main-app surfaces. Consolidate repeated styles within domain. Separation is **temporary** — document as **future alignment** with broader Push system.
- **My decision (API strategy):** Expose a **constrained collection of named, approved surfaces** — not a freely configurable glass API. Feature code selects a named semantic style. Shared low-level tokens may exist **internally**. Public feature APIs must **not** expose freeform tint/border/shadow/translucency/glow/stroke knobs for composing new recipes. If no existing surface fits: reuse, add approved variant to a family, or introduce a new named surface via **explicit design-system decision** — never a local near-duplicate.
- **Approved named surfaces (main app + domain):** Generic control glass; Map control glass (and named map sub-styles); Map sheet glass; Puck glass; Plans card glass; Review deck glass; Solid cream card; Ivory page background; Modal gradient; Onboarding/auth surfaces (temporary domain).
- **Must remain consistent:** Named-surface-only selection; no local glass/cream/gradient recipes in features.
- **May vary:** Which approved named surface is chosen per context rules above.
- **Reuse required for future features:** **Yes** — mandatory named surface selection.
- **Existing screens need migration:** **Yes** over time onto named surfaces; onboarding domain-local centralization only.
- **Recommended mechanism:** Named surface catalog + internal tokens; agent discovery docs.

---

## Category 2 — Agent rules (summary for future implementation)

1. **Three glass families only (main app):** generic control glass (DS-010), map glass family (DS-011), puck glass (DS-012). Do not merge recipes.
2. **Two card-glass styles:** Plans card glass (cream pages) and Review deck glass (gradient/deck — restricted) (DS-013).
3. **Cream pages:** one ivory page + one solid cream card for dense lists; distinct from Plans card glass (DS-014).
4. **Cream tokens:** consolidate literals into semantic roles; preserve approved Plans glass look (DS-014).
5. **Background rule:** flat ivory for persistent destinations; modal gradient for focused full-screen flows (DS-015).
6. **Onboarding/auth:** domain-local temporary family; future alignment (DS-016).
7. **Surface API:** named surfaces only; no freeform public recipe parameters; new needs → design-system decision (DS-016).

---

## Category 3 — Cards

**Source of truth:** User final decisions (this session).  
**Implementation:** Deferred until full design-system specification is approved.  
**Note:** Surfaces locked in Category 2; this category defines semantic card families and agent process.

### DS-017 — Solid cream list-card foundation (C1–C4 + C10 shell)

- **Existing UI:** `.friendsCard` + Friends layout density used by person/group/request/history rows and error banner chrome.
- **My decision:** Friend rows, group rows, request cards, history rows, and inline error banners share one **solid cream list-card foundation** on ivory pages. Centralize surface, walnut border, corner radius, internal padding, standard row density, identity/metadata/trailing spacing, and press/selection where applicable. Components share visual foundations **without** forced identical content layouts. New list-oriented cards on ivory pages **must begin** with this foundation — no local cream fill/border/spacing/radius recreation.
- **Must remain consistent:** Solid cream surface, walnut border, radius, padding, density, spacing rules.
- **May vary:** Purpose-specific content hierarchy inside each semantic component.
- **Reuse required for future features:** **Yes** for ivory-page list cards.
- **Existing screens need migration:** **Yes** — extract shared foundation; preserve appearance.
- **Recommended mechanism:** Shared foundation style/modifier + semantic components on top.

### DS-018 — Person list / person-row component (C1)

- **Existing UI:** `FriendRowCard` (+ expandable outer shell).
- **My decision:** Maintain **reusable person-row component**. Supports approved variations: avatar; availability or neutral ring; name; status/venue; optional group tag; optional secondary detail; trailing status chip; custom trailing (e.g. Accept/Deny). May render **without** own card background when inside expandable outer row; internal layout/density stay centralized. Agents reuse/extend — do not recreate person cards.
- **Must remain consistent:** Internal layout density and person-row hierarchy.
- **May vary:** Trailing content, background-on/off, status detail visibility, ring mode.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** — all person list UIs onto this component.
- **Recommended mechanism:** Exact shared component with limited configuration slots (not a universal identity mega-API).

### DS-019 — Group list / group-row component (C2)

- **Existing UI:** `FriendGroupCard`.
- **My decision:** **Separate** reusable group-row on the same solid cream foundation. Preserve group avatar, name, member count, activity/status summary, group trailing. **Do not** force into person-row.
- **Must remain consistent:** Group-specific structure + solid cream foundation.
- **May vary:** Summary copy, trailing content.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Exact shared component.

### DS-020 — Request cards (C3)

- **Existing UI:** Alerts friend-request composition; `GroupRequestCard`; Accept/Deny (DS-004).
- **My decision:** Reusable **request-card system** with person and group **variants**. Reuse solid cream foundation + shared Accept/Deny + resolving/disabled/accepted/added states. Layouts may stay separate per identity type. Future invitation/approval UIs **must** use this system — no new request chrome.
- **Must remain consistent:** Foundation, Accept/Deny pair, approved states.
- **May vary:** Person vs group identity presentation and supporting info.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — ensure one request-card system.
- **Recommended mechanism:** Shared base + person/group variants (or two components on shared request chrome).

### DS-021 — History cards (C4)

- **Existing UI:** `HistoryListRow` in Plans history.
- **My decision:** Reusable **history-specific** component within solid cream list-card system. Content may include single/grouped avatars, title, date/metadata, outcome/status, “Almost happened.” Surface and list density align with foundation; content structure stays history-specific.
- **Must remain consistent:** Solid cream foundation + list density.
- **May vary:** History content fields.
- **Reuse required for future features:** **Yes** for history lists.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Exact shared history row component.

### DS-022 — Error banner as dedicated component on foundation (C10)

- **Existing UI:** `ActionErrorBanner`.
- **My decision:** Dedicated reusable **banner** component. Reuses solid cream list-card foundation but keeps its own semantic structure: message, retry, dismiss, loading/resolving where applicable. **Not** a generic identity/list row.
- **Must remain consistent:** Banner structure + cream foundation chrome.
- **May vary:** Message copy; retry target.
- **Reuse required for future features:** **Yes** for inline mutation/recovery errors.
- **Existing screens need migration:** **Selective** — all mutation error banners through this component.
- **Recommended mechanism:** Exact shared banner component.

### DS-023 — Separate semantic components (architecture)

- **My decision:** Keep **separate** reusable components for person rows, group rows, request cards, history rows, error banners. **Do not** merge into one highly configurable “identity card” / universal card. Shared visual rules live in solid cream foundation; purpose-specific hierarchy/data/behavior stay in each component. Avoid large flag matrices that transform one component into unrelated types.
- **Reuse required for future features:** **Yes** — semantic components, not one mega card.
- **Existing screens need migration:** N/A (architecture rule).
- **Recommended mechanism:** Foundation + discrete components.

### DS-024 — Plans-glass plan-card family (C5)

- **Existing UI:** `YourPushCard`, `ActivePlanCard`.
- **My decision:** One reusable **Plans-glass plan-card family** with explicit **role variants**: owner-created Push; invited/active Push. Centralize Plans card-glass surface, padding/hierarchy, title, time/status, group/location, participant avatars, social proof, footer placement, manage/response actions. Role-specific controls may differ without separate full implementations. Do **not** rebuild plan cards independently for preview lists, expanded lists, or related Plans surfaces.
- **Must remain consistent:** Plans glass + core plan-card structure.
- **May vary:** Owner vs invited actions (Manage/cancel vs response/participation).
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — unify Your/Active into family with variants.
- **Recommended mechanism:** Shared component + role variant.

### DS-025 — Review deck card (C6)

- **Existing UI:** `ReviewPushCard`.
- **My decision:** **Separate** reusable component on Review deck glass. Do **not** combine with ordinary Plans-glass plan-card family. Different purpose/structure (swipe context, depth, attendees, notes, address/distance, decision hierarchy, review interactions). May share **subcomponents** (status pills, avatar groups, participant summaries, metadata/time/location rows) — not one oversized configurable card.
- **Must remain consistent:** Review glass + review decision layout language.
- **May vary:** Plan content fields within review structure.
- **Reuse required for future features:** **Yes** for review/swipe decision cards.
- **Existing screens need migration:** **Selective** — extract shared subcomponents where useful without merging families.
- **Recommended mechanism:** Exact shared review card + shared subcomponents.

### DS-026 — Calendar module, menu panel, map overlay, profile settings, selection rows, new-card rule (C7–C12 + process)

- **C7 Weekly calendar:** Standalone reusable module; **appearance unchanged**. Preserve structure, glass/surface, spacing, type, day tiles, heat gradients, hierarchy, interaction. Do **not** redesign to look like ordinary Plans cards. Day tiles **scoped to module** — not a global card type. Agents reuse complete module — no reconstruct/restyle/partial duplicate.
- **C8 Create-action menu:** Separate reusable **menu-panel** — control glass + create-menu icon circles + row spacing/hierarchy + title/subtitle. Not cream list card; not Plans card family. Future menu panels reuse this or approved variant.
- **C9 Map empty/error overlay:** Separate reusable **control-glass overlay-card** — icon, title, copy, optional action; empty/failed/loading as appropriate. CTAs use approved branded styles only (no `.borderedProminent`). Not cream-page card; not map popup sheet.
- **C11 Profile settings:** Separate reusable **modal settings-card family** for this pass — modal-gradient environment; not forced into solid cream list cards. Covers grouped sections, navigation rows, privacy, toggles, editable profile info, headers/separators. Future modal-gradient settings may reuse.
- **C12 Modal selection rows:** Separate reusable **modal selection-row family** (Start Push–style) — selected/unselected, sunbeam selected, translucent unselected, avatars/icons, titles/support, checkmarks, press/transitions. Task-oriented modal flows only — not solid cream list cards.
- **New card process:** (1) Choose approved surface family first. (2) Search existing semantic component. (3) Reuse with slots/variants. (4) Extend carefully if same semantic role. (5) New layout only if none fits — may still use approved surface. (6) Explicit design-system decision before new reusable card family or visual recipe. No new fill/border/radius/shadow/material/card family in feature code. **New content layout does not justify a new visual surface.**
- **Reuse required for future features:** **Yes** for each named pattern; process is mandatory.
- **Existing screens need migration:** **Yes** where patterns are duplicated or system CTAs still use native chrome (e.g. map empty).
- **Recommended mechanism:** Named components/modules + documented agent process.

---

## Category 3 — Agent rules (summary for future implementation)

1. Ivory list UI → solid cream list-card foundation + semantic component (person / group / request / history / error banner) — never one universal identity card.
2. Plans tab plan previews → Plans-glass plan-card family with owner vs invited variants.
3. Review swipe → separate Review deck card; share subcomponents only.
4. Calendar → whole module reuse; day tiles internal.
5. Create menu → menu-panel pattern; map empty → control-glass overlay; Profile → modal settings family; flow pickers → modal selection rows.
6. New cards: surface first → existing component → extend → new layout only if needed → design-system decision for new families/recipes.

---

## Category 4 — Friend / member / request / activity rows

**Source of truth:** User final decisions (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-027 — Flat person row as default (R1)

- **Existing UI:** `FriendRowCard` used flat in group members, Alerts, Add Friends, etc.
- **My decision:** **Flat person row** is the **default** reusable person-row component across Push. Serves group member lists, Alerts, Add Friends, blocked users, other non-expanding person lists. Row owns identity presentation and content slots; surrounding screen owns navigation and list behavior.
- **Must remain consistent:** Person identity layout/density (DS-018) on solid cream foundation when used as list cards.
- **May vary:** Trailing actions, secondary lines, ring mode, status detail on/off.
- **Reuse required for future features:** **Yes** — default for person lists.
- **Existing screens need migration:** **Yes** where person chrome is reimplemented (e.g. blocked).
- **Recommended mechanism:** Shared flat person-row component.

### DS-028 — Expandable person-row wrapper (R2)

- **Existing UI:** `ExpandableFriendRow` + action rail (DS-008).
- **My decision:** Expansion is an **optional reusable wrapper** around the shared flat person row. Wrapper owns: tap-to-expand, expand/collapse animation, configurable action rail, confirmation flows, expanded-state layout. Do **not** bake expansion into base person-row or require it on every person list.
- **Must remain consistent:** Wrapper behavior/animation/rail pattern when expansion is used.
- **May vary:** Whether a list uses the wrapper; action set on the rail.
- **Reuse required for future features:** **Yes** when multi-action expand is needed; **not** default.
- **Existing screens need migration:** **Selective** — Friends list uses wrapper; extract as shared pattern.
- **Recommended mechanism:** Wrapper component composing flat person-row + rail.

### DS-029 — Group member actions (R3)

- **Existing UI:** Group detail member lists with host-driven remove/cancel.
- **My decision:** Group detail members use **flat person-row** with **trailing or overflow** actions. Keep compact by default. Remove member, cancel invitation, manage role, other member-management actions → trailing/overflow — **not** the expandable Friends action rail.
- **Must remain consistent:** Flat person-row chrome; compact default.
- **May vary:** Specific trailing/overflow actions by ownership and membership state.
- **Reuse required for future features:** **Yes** for group member lists.
- **Existing screens need migration:** **Selective** — ensure identity uses person-row; actions stay trailing/overflow.
- **Recommended mechanism:** Person-row + trailing/overflow configuration.

### DS-030 — Request lifecycle ownership (R4)

- **Existing UI:** Alerts / Add Friends accept-deny phases, Added badge, deny collapse.
- **My decision:** **Complete request lifecycle** lives inside the shared **request-card system** (DS-020 + DS-004): Accept/Deny, loading/resolving, accepted/“Added”, denial/removal transitions, collapse animations, soft reload behavior. Screens provide **data + callbacks only** — no per-screen request animation phases or lifecycle.
- **Must remain consistent:** Centralized lifecycle states and transitions.
- **May vary:** Request entity data and callbacks from the screen/ViewModel.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** if any screen owns local request phases.
- **Recommended mechanism:** Request-card system owns UI state machine for resolve.

### DS-031 — Search vs selection row systems (R5)

- **Existing UI:** Add Friends cream `FriendRowCard`; Start Push modal selection rows.
- **My decision:** **Two distinct systems.** Ivory social-discovery (Add Friends, etc.) → cream person row. Modal multi-select flows (Start Push, etc.) → modal selection-row pattern (DS-026). May share low-level primitives (avatars, typography); must **not** share full row chrome or merge into one universal component.
- **Must remain consistent:** Correct system per surface context (ivory vs modal flow).
- **May vary:** Trailing actions (discovery) vs selection indicators (modal).
- **Reuse required for future features:** **Yes** — pick the correct system; no cross-use of full chrome.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Two named row families.

### DS-032 — Blocked users on person-row (R6)

- **Existing UI:** Private `BlockedPersonRow` near-duplicate of cream person chrome.
- **My decision:** **Migrate** blocked-user rows onto shared person-row. Configure: handle as secondary line; neutral avatar ring; no availability; “Unblock” custom trailing. **Remove** separate blocked-row visual implementation.
- **Must remain consistent:** Person-row density/foundation + above configuration.
- **May vary:** Unblock loading/disabled state.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — BlockedUsersView.
- **Recommended mechanism:** Person-row configuration (not a parallel visual).

### DS-033 — Feed / activity rows deferred (R7)

- **Existing UI:** Feed deferred; no live activity list chrome.
- **My decision:** **Defer** Feed/activity-row design system until Feed is actively implemented. Until then: no generic activity-row component; no ad-hoc Feed/activity-row chrome in unrelated work; separate design-system decision when real Feed content and interaction model are defined.
- **Reuse required for future features:** **N/A until Feed decision**.
- **Existing screens need migration:** **No**.
- **Recommended mechanism:** Explicit future DS decision; forbid interim invention.

### DS-034 — Alerts structure + nested participant subcomponents + Category 4 rule (R8–R10)

- **R8 Alerts:** Reuse shared **section-header** pattern + **request-card** system. Do **not** create a separate notification-row visual language unless a future notification type gets an explicit design-system decision.
- **R9/R10 Nested participants:** Review participant rows and horizontal avatar strips (including “+N” overflow) are **reusable subcomponents**, not full list rows — **no** solid cream list-card shells.
- **Category 4 implementation rule:** Person-oriented UI starts by selecting the correct semantic pattern: flat person row | expandable person-row wrapper | request card | modal selection row | nested participant sub-row | avatar strip. Agents must **not** create a new row implementation merely because trailing action or secondary text differs. **New identity-row chrome requires an explicit design-system decision.**
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** for Alerts headers / subcomponents extraction.
- **Recommended mechanism:** Named patterns + mandatory selection rule.

---

## Category 4 — Agent rules (summary for future implementation)

1. Default person list → **flat person row**.
2. Multi-action expand → **optional wrapper** + rail; not base row.
3. Group members → flat person-row + trailing/overflow (not Friends expand rail).
4. Requests → request-card owns full lifecycle; screens = data + callbacks.
5. Ivory discovery vs modal multi-select → two systems; share primitives only.
6. Blocked → person-row config (handle, neutral ring, Unblock trailing); delete fork.
7. Feed/activity rows → deferred; no ad-hoc chrome.
8. Alerts → section headers + request cards; no parallel notification-row language.
9. Review/plan nested people → subcomponents, not cream list rows.
10. Different trailing/secondary text ≠ new row chrome without a DS decision.

---

## Category 5 — Selectors, dropdowns, and segmented controls

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-035 — Ivory segmented mode switch (S1)

- **Existing UI:** `FriendsModeSwitch` (Friends | Groups) with champagne track, ivory selected segment, optional count capsules, spring + matched geometry.
- **My decision:** Promote to a **reusable ivory segmented control** for cream-page destinations that need 2–N mutually exclusive modes. Support optional count badges. Friends is the visual/behavioral reference.
- **Must remain consistent:** Track/selected segment treatment, optional count styling, spring selection motion language.
- **May vary:** Segment labels, count presence, number of segments.
- **Reuse required for future features:** **Yes** for ivory multi-mode switches.
- **Existing screens need migration:** **Selective** — extract Friends switch to shared component.
- **Recommended mechanism:** Shared segmented control component.

### DS-036 — Ivory filter chips (S2)

- **Existing UI:** `FriendsFilterChipRow` — walnut selected fill + cream text; unselected cream + walnut stroke; counts.
- **My decision:** Standard **multi-option filter chip** for ivory pages. **Walnut-selected** is reserved for this filter pattern on ivory. **Do not** use sunbeam chips for ivory filters (sunbeam selection language is for modal/primary selection contexts).
- **Must remain consistent:** Walnut selected / cream unselected filter chrome + count treatment.
- **May vary:** Filter labels, counts, binding to filter enum.
- **Reuse required for future features:** **Yes** for ivory list filters.
- **Existing screens need migration:** **Selective** — extract Friends filter chips.
- **Recommended mechanism:** Shared filter-chip component/row.

### DS-037 — Map filter dropdown (S3)

- **Existing UI:** Map top filter pill + panel + rows (`topControlBackground` / map glass).
- **My decision:** Dropdown **shell** (trigger + panel) stays **map-glass family only** (DS-011). Do not use generic control glass or cream chrome for this dropdown over the map.
- **Selected row treatment:** Sunbeam capsule fill + checkmark becomes a **shared single-select row primitive** that the map dropdown consumes; other non-map dropdowns may use the same row primitive with their own panel surface.
- **Must remain consistent:** Map shell on map glass; selected-row sunbeam+check primitive when used.
- **May vary:** Item list content; whether a non-map surface reuses only the row primitive.
- **Reuse required for future features:** **Yes** for map group filters; row primitive reusable where single-select lists need the same selected look.
- **Existing screens need migration:** **Yes** — extract map dropdown + shared selected-row primitive.
- **Recommended mechanism:** Map-scoped dropdown component + shared single-select row style/component.

### DS-038 — Bottom nav selection (S4)

- **Existing UI:** Sunbeam capsule behind selected bottom-nav item.
- **My decision:** **Nav-scoped only** with `BottomNavigationBar` (and center “+” remains DS-005). Not a general segmented control.
- **Reuse required for future features:** **No** outside bottom nav.
- **Existing screens need migration:** **No**.
- **Recommended mechanism:** Keep inside bottom nav component.

### DS-039 — Modal choice pills + date/time pickers (S5, S6, S10)

- **Existing UI:** Start Push recipient/suggestion capsules; `AmPmPillButton`; `PushDatePicker` / `PushTimeClicker` field chrome.
- **My decision:**
  - Unify sunbeam-selected / translucent-unselected compact choices into a shared **modal choice-pill** style (chips, AM/PM, similar binary or multi option pills in modal flows).
  - **Date and time pickers** remain specialized reusable components that **consume** modal choice-pill and modal field chrome rather than inventing parallel pill styles.
- **Must remain consistent:** Modal choice-pill selected/unselected language; picker panel chrome (translucent white + walnut stroke) as used today.
- **May vary:** Pill labels; picker value bindings.
- **Reuse required for future features:** **Yes** for modal multi-step flows needing compact choices or date/time.
- **Existing screens need migration:** **Yes** — Start Push timing/selection onto named pill + picker components.
- **Recommended mechanism:** Shared modal choice-pill + shared `PushDatePicker` / `PushTimeClicker` (or successors).

### DS-040 — Profile / settings checkmark toggles (S7, S8)

- **Existing UI:** `ProfileToggleRow` with circle / checkmark.circle.fill; header `StatusPill` is display (Category 6).
- **My decision:** For this pass, **checkmark-style binary rows** are the only approved binary control inside **modal settings** (DS-026). Do **not** introduce system `Toggle` or ivory filter chips on Profile. Availability **display** pills are Category 6; if a full availability option list is needed later, it must use an approved selector pattern (modal selection rows or settings checkmark list) via explicit reuse — not a new chrome family without decision.
- **Must remain consistent:** Settings row structure + checkmark on/off affordance.
- **May vary:** Title, subtitle, icon, enabled binding.
- **Reuse required for future features:** **Yes** for modal-gradient settings binaries.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Modal settings toggle-row component.

### DS-041 — Calendar week navigation (S9)

- **Existing UI:** Plans weekly recap prev/next chevrons.
- **My decision:** **Scoped to the calendar module** (DS-026 C7). Not a global selector or circular icon-button generalization unless it already matches DS-001 dimensions/role (week chevrons currently stay module-local).
- **Reuse required for future features:** Via calendar module only.
- **Existing screens need migration:** **No**.
- **Recommended mechanism:** Module-local controls.

### DS-042 — Selector menu + new-selector rule

- **My decision:** Agents **must** choose from this fixed menu when building option-selection UI:
  1. Ivory segmented mode switch (DS-035)
  2. Ivory filter chips (DS-036)
  3. Map filter dropdown shell (DS-037) + shared single-select row primitive
  4. Modal selection rows (DS-026 / DS-031)
  5. Modal choice pills (DS-039)
  6. Date/time pickers (DS-039)
  7. Settings checkmark rows (DS-040)
  8. Bottom-nav-local selection (DS-038)
  9. Module-local controls (e.g. calendar chevrons, DS-041)
- **Any new selector chrome** (new selected colors, tracks, chip recipes, dropdown shells) requires an **explicit design-system decision**. Do not recreate near-duplicates because labels or option count differ.
- **Reuse required for future features:** **Yes** — mandatory menu selection.
- **Existing screens need migration:** Over time onto named components above.
- **Recommended mechanism:** Documented selector catalog in final DS spec.

---

## Category 5 — Agent rules (summary for future implementation)

1. Ivory multi-mode → segmented switch; ivory filters → walnut filter chips (not sunbeam).
2. Map filters → map-glass dropdown; selected row may use shared sunbeam+check primitive.
3. Modal compact choices → modal choice pills; date/time → specialized pickers consuming those pills.
4. Modal settings binary → checkmark rows only (this pass).
5. Bottom nav selection and calendar chevrons stay scoped.
6. New selector visual recipes require a design-system decision.

---

## Category 6 — Status & availability chips

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-043 — Availability color tokens (A1)

- **Existing UI:** `FriendAvailabilityState` accent/chip fill/chip text + `PuckColorTokens` in `FriendPuckStyle`.
- **My decision:** Lock one **availability token table** (per state: accent, chip fill, chip text). Rings, list chips, map badges, live dots, and related accents **must** consume these tokens — no local free-now greens or ad-hoc state colors. Preserve **current** freeSoon vs maybeDown chip-fill difference as the approved appearance for this pass (tokenized as-is; no silent visual merge).
- **Must remain consistent:** Semantic mapping from availability state → accent/chip colors app-wide.
- **May vary:** Which component uses accent vs chip fill (ring vs chip vs badge).
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — replace local color literals with tokens where they diverge from the table.
- **Recommended mechanism:** Central tokens (extend `PuckColorTokens` / availability extensions into design-system token module).

### DS-044 — Compact availability chip + map activity badge (A2, A3, A5)

- **Existing UI:** `FriendsAvailabilityChip`; inline capsules in `FriendDetailSheet`; `ActivityBadge` on map pucks.
- **My decision:**
  - **Canonical availability chip** for cream lists and sheet headers (compact density; optional size variant for sheet header if needed). Migrate Friend Detail inline chips onto this component — no parallel implementations.
  - **Map `ActivityBadge`** stays a **separate map-scoped** component (material capsule + icon + text + availability tint) for annotation readability. Consumes availability tokens; not used as list trailing chip.
- **Must remain consistent:** Chip fill/text from DS-043; badge material recipe on map.
- **May vary:** Size variant (list vs sheet); badge text/symbol content.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — FriendDetailSheet and any inline availability capsules.
- **Recommended mechanism:** Shared availability chip component + named map ActivityBadge.

### DS-045 — Brand sunbeam pill primitive (A4, A7, A8)

- **Existing UI:** Profile `StatusPill` (icon+title, sunbeam); `YourPushTimeChip` (time text, sunbeam + cream stroke); private `GroupStatusPill` (sunbeam-tinted capsule).
- **My decision:** Shared **brand sunbeam pill** primitive for sunbeam-fill capsule chrome (distinct from multi-color availability chips and from plan-status pills). Named usages/variants:
  - Profile / identity status (symbol + title)
  - Plan time signal (text; may retain cream stroke as approved plan-card detail)
  - Group status label (text)
- **Must remain consistent:** Sunbeam brand capsule language for these non-availability labels.
- **May vary:** Icon presence, stroke, copy, slight fill opacity where group pill already differs — tokenize rather than fork whole components.
- **Reuse required for future features:** **Yes** — do not invent new sunbeam status capsules.
- **Existing screens need migration:** **Yes** — Profile, plan time chip, group status onto primitive/variants.
- **Recommended mechanism:** Shared primitive + thin semantic wrappers.

### DS-046 — Plan status pill (A6)

- **Existing UI:** `PlanStatusPill` on Your/Active/Review plan cards.
- **My decision:** **Required** plan status/response pill for all plan-card surfaces (Plans-glass family and Review deck). Domain is plan/RSVP state — **separate** from person availability chips (DS-044).
- **Must remain consistent:** Status → fill/text mapping as approved today.
- **May vary:** Which plan statuses appear for a given plan.
- **Reuse required for future features:** **Yes** for plan UI.
- **Existing screens need migration:** **Selective** — ensure no local plan-status capsules.
- **Recommended mechanism:** Exact shared `PlanStatusPill` (system-named).

### DS-047 — Live timestamp + dot (A9)

- **Existing UI:** Person-row trailing live dot + relative time under availability chip.
- **My decision:** Optional **person-row accessory** using availability **accent** tokens (DS-043). Not freeform decoration; not a standalone chip family.
- **Must remain consistent:** Dot color from availability accent; typography density with person-row.
- **May vary:** Shown/hidden; timestamp string.
- **Reuse required for future features:** **Yes** when showing live freshness on person rows.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Subcomponent or person-row slot.

### DS-048 — Onboarding status chips (A10)

- **Existing UI:** Onboarding lab fixture chips with local colors.
- **My decision:** Remain **onboarding domain-local** (temporary, parallel DS-006/DS-016). Prefer reusing main availability tokens where easy; do not create a third app-wide chip family. Future alignment with main availability system.
- **Reuse required for future features:** Within onboarding only.
- **Existing screens need migration:** Domain consolidation only.
- **Recommended mechanism:** Onboarding-scoped components + token reuse.

### DS-049 — Status/chip menu + new-chip rule

- **My decision:** Agents must choose from:
  1. Availability tokens + compact availability chip (DS-043/044)
  2. Map activity badge (DS-044)
  3. Brand sunbeam pill usages (profile status / plan time / group status) (DS-045)
  4. Plan status pill (DS-046)
  5. Live dot + timestamp accessory (DS-047)
  6. Onboarding-domain chips (DS-048) inside auth/onboarding only
- **No new capsule status recipes** (fills, strokes, state colors) without an explicit design-system decision. Filter chips and modal choice pills remain Category 5 (not status chips).
- **Reuse required for future features:** **Yes**.
- **Recommended mechanism:** Documented chip catalog in final DS spec.

---

## Category 6 — Agent rules (summary for future implementation)

1. Availability colors only from the central token table; preserve current freeSoon vs maybeDown chip fills.
2. List/sheet availability → shared chip; map → ActivityBadge only.
3. Sunbeam label pills → brand sunbeam primitive (profile / time / group) — not availability colors.
4. Plan RSVP/state → PlanStatusPill only on plan cards.
5. Live dot uses availability accent; onboarding chips stay domain-local.
6. New status capsule chrome requires a DS decision.

---

## Category 7 — Avatars, stacks, map pucks, and rings

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-050 — Circular person avatar + fallback variants (V1, V2)

- **Existing UI:** `ProfilePhotoAvatar` (dark plum initials fallback); `RecipientAvatarView` (sunbeam fallback) in Start Push.
- **My decision:** One **canonical circular person avatar** component for all person faces. Support **fallback style variants**: dark list/map vs sunbeam modal (and shared `AvatarImageLoader` pipeline). Eliminate parallel loading implementations (`RecipientAvatarView` merges into this component or a thin wrapper). Size from adaptive metrics / caller.
- **Must remain consistent:** Circle crop, loader behavior, approved fallback styles only.
- **May vary:** Size; fallback style by context; image asset path.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — Start Push recipients and any other sunbeam-fallback forks.
- **Recommended mechanism:** Shared person avatar + `fallbackStyle` (or equivalent).

### DS-051 — Availability rings, neutral rings, self rings (V4, V12)

- **Existing UI:** Map `availabilityPulse`; person-row ring; self-puck champagne/walnut rings.
- **My decision:**
  - **Friend availability ring** primitive: **static** (list) vs **pulsed** (map), colors from availability tokens (DS-043).
  - **Neutral ring** for non-availability list contexts (requests, blocked, etc.).
  - **Self-puck rings** remain part of self-puck identity chrome — not the friend availability ring system.
- **Must remain consistent:** Ring modes and token sources as above.
- **May vary:** Ring width by density (list vs map); shown/hidden.
- **Reuse required for future features:** **Yes** for friend faces with status; self rings only on self puck.
- **Existing screens need migration:** **Selective** — centralize pulse/static ring modifiers.
- **Recommended mechanism:** Shared ring modifiers + person-avatar/row configuration (availability | neutral | none).

### DS-052 — Map puck family (V5, V6, V7)

- **Existing UI:** `FriendPuck`, `FriendGroupPuck`, `FriendClusterPuck`, `RegionalActivityPuck`, `SelfPuckView`; puck glass (DS-012); activity badge (DS-044).
- **My decision:** Named **map-puck family** required on the live map:
  - Friend puck
  - Group / cluster puck variants
  - Regional activity cluster (wide zoom; distinct interaction — zoom, no detail sheet)
  - Self puck (map-only; do not replace with friend puck + flag)
- Agents **must not** assemble ad-hoc live-map pucks from loose parts. Composition stays inside family components (avatar + puck glass + rings + badges as designed).
- **Must remain consistent:** Each named variant’s approved structure and interaction.
- **May vary:** Data inputs (friends, availability, counts); adaptive scale.
- **Reuse required for future features:** **Yes** for map annotations of people/groups.
- **Existing screens need migration:** **Selective** — ensure map only uses family components.
- **Recommended mechanism:** Named puck components under one family documentation.

### DS-053 — Multi-avatar: stack vs horizontal strip (V8, V9)

- **Existing UI:** `AvatarStack` (offset cluster); plan-card `YourPushAvatarRow` / history multi-avatar horizontal.
- **My decision:** Two approved multi-avatar patterns:
  1. **Avatar stack** — overlapping offset circular avatars (map/detail cluster language).
  2. **Horizontal avatar strip** + overflow “+N” — plan cards, history, similar linear summaries (DS-034).
- Do not use solid cream list-card shells on these subcomponents. Use person avatar (DS-050) at the appropriate size.
- **Must remain consistent:** Pattern geometry and overflow rules per pattern.
- **May vary:** Max visible count; size; data source.
- **Reuse required for future features:** **Yes** — pick stack vs strip by layout need.
- **Existing screens need migration:** **Yes** — extract strip; align history with strip.
- **Recommended mechanism:** Two shared subcomponents.

### DS-054 — Group list avatar + group hero (V10, V11)

- **Existing UI:** `GroupListAvatar` (rounded rect lists); `GroupPhotoBadge` (hero + camera).
- **My decision:** Required pair:
  - **Group list avatar** for cream lists, requests, compact group identity — **not** circular person avatar for groups on lists.
  - **Group hero** (`GroupPhotoBadge`) for detail/create editable large photo.
- **Must remain consistent:** Rounded-rect list treatment; hero size/badge language.
- **May vary:** Size/corner radius via layout metrics; override image while uploading.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Exact shared components (already largely exist).

### DS-055 — Profile hero avatar (V3)

- **Existing UI:** `ProfileAvatar` — large, camera badge, stroke, shadow, editable.
- **My decision:** **Modal identity hero** composing person avatar (or same loader) + camera edit badge. For Profile and similar editable self identity on modal gradient — not a map puck, not list density.
- **Must remain consistent:** Hero size language, edit badge, stroke/shadow as approved.
- **May vary:** Initials/image; edit action wiring.
- **Reuse required for future features:** **Yes** for editable profile heroes.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Shared profile hero component.

### DS-056 — Avatar/puck menu + new-face rule

- **My decision:** Agents must choose from:
  1. Person avatar (± fallback style, ± ring mode) (DS-050/051)
  2. Profile hero (DS-055)
  3. Group list avatar (DS-054)
  4. Group hero (DS-054)
  5. Avatar stack (DS-053)
  6. Horizontal avatar strip (DS-053)
  7. Map puck family: friend / group-cluster / regional / self (DS-052)
- **New face, ring, stack, or puck chrome** requires an explicit design-system decision. Different size or secondary text alone does not justify a new avatar implementation.
- **Reuse required for future features:** **Yes**.
- **Recommended mechanism:** Documented avatar/puck catalog in final DS spec.

---

## Category 7 — Agent rules (summary for future implementation)

1. One person avatar component; fallback style by context (dark vs sunbeam modal).
2. Friend rings = static list or pulsed map from availability tokens; neutral ring when no availability; self rings only on self puck.
3. Live map uses named puck family only — no DIY pucks.
4. Multi-avatar: stack (offset) vs horizontal strip (+N) — two patterns.
5. Groups: list rounded-rect vs hero photo — not person circles on group lists.
6. Profile hero for editable self identity on modal flows.
7. New avatar/puck recipes need a DS decision.

---

## Category 8 — Navigation elements

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-057 — Bottom navigation (N1)

- **Existing UI:** `BottomNavigationBar` on map shell only; center + (DS-005); selection (DS-038).
- **My decision:** **Single app bottom nav** lives on the **map shell only**. Primary destinations launch from it. Secondary ivory/modal screens **must not** rebuild their own tab bars (Friends and peers own no tab bar).
- **Must remain consistent:** Floating control-glass bar structure, items, center create role.
- **May vary:** Selection state; badge/indicator wiring where already approved (e.g. alerts is top chrome).
- **Reuse required for future features:** **Yes** — only this bottom nav.
- **Existing screens need migration:** **No** if already map-only (enforce as rule).
- **Recommended mechanism:** Exact shared bottom nav component.

### DS-058 — Map top chrome (N2)

- **Existing UI:** Profile, alerts bell, group filter dropdown on map glass.
- **My decision:** **Map-only top navigation chrome** using map glass family (DS-011). Not used on cream pages (those use cream page headers + DS-001 circular actions).
- **Must remain consistent:** Map glass treatments, layout relative to map.
- **May vary:** Unread indicator; filter selection content.
- **Reuse required for future features:** **Yes** for live-map top actions.
- **Existing screens need migration:** **Selective** — extract named map top chrome.
- **Recommended mechanism:** Map-shell top controls package.

### DS-059 — Route presentation: fullScreenCover (N3, N7)

- **Existing UI:** `MainMapRoute` + `fullScreenCover` from ContentView; nested covers for group detail, manage, Start Push from Friends, etc.
- **My decision:** **Route-driven fullScreenCover** is the standard presentation for main destinations and focused flows leaving the map. **Nested fullScreenCover** is approved for hierarchical destinations (Profile-style slide). Do not invent custom push/navigation-stack chrome or bespoke transitions without an explicit design-system decision.
- **Must remain consistent:** Cover presentation as default for full destinations/flows.
- **May vary:** Route payload; nesting depth as product requires.
- **Reuse required for future features:** **Yes** — architecture rule.
- **Existing screens need migration:** **No** (document and enforce).
- **Recommended mechanism:** Documented navigation architecture + existing route enums.

### DS-060 — Cream page header (N4)

- **Existing UI:** Friends, Alerts, Add Friends, Blocked, Plans, History headers — title/subtitle/trailing actions often reimplemented.
- **My decision:** **Reusable cream page header** for ivory destinations: leading title stack (title + optional subtitle), trailing action slots using DS-001 circular icon buttons (close, add, etc.). Agents must not freehand new ivory header layouts.
- **Must remain consistent:** Hierarchy, spacing language, circular trailing actions.
- **May vary:** Title/subtitle copy; which trailing actions.
- **Reuse required for future features:** **Yes** for ivory full-screen destinations.
- **Existing screens need migration:** **Yes** — consolidate duplicated headers.
- **Recommended mechanism:** Shared header component with action slots.

### DS-061 — Modal flow chrome (N5, N6)

- **Existing UI:** Start Push / Add Group back-close-trash; `PushModalCloseButtonBar`; `ProfileBackButton`; group detail back bars.
- **My decision:** Shared **modal flow chrome** on modal gradient: leading back / trailing close (and optional destructive) built on DS-001 circular controls; optional title/step region. Distinct from cream page header. Profile close-trailing and back-leading collapse into this chrome family.
- **Must remain consistent:** Control sizing/treatment (DS-001); modal placement patterns.
- **May vary:** Which actions appear; step indicator presence (Start Push).
- **Reuse required for future features:** **Yes** for multi-step and modal full-screens.
- **Existing screens need migration:** **Yes** — Start Push, Add Group, Profile, group flows.
- **Recommended mechanism:** Shared modal chrome bars/components.

### DS-062 — Create menu hub + in-content text links (N8, N9)

- **Existing UI:** Create action menu from center +; Plans “History ›”, “Manage →”, review links.
- **My decision:**
  - **Create menu** remains the map **create navigation hub** (menu panel DS-026 / DS-007) — not a tab.
  - In-content deeper navigation uses a shared **text link style** (walnut semibold affordances like History › / Manage →) — not new button families.
- **Must remain consistent:** Menu panel pattern; text link typography/color language.
- **May vary:** Menu items; link labels.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** — extract text link style; menu already partly shared.
- **Recommended mechanism:** Create menu component + `PushTextLink` (or equivalent) style.

### DS-063 — Map attribution margins + nav menu rule (N10)

- **Existing UI:** `StyledMapView` / `MapAttributionLayout` edge insets; compass replaced by alerts.
- **My decision:** Map attribution/legal margins are part of the **map shell system**. Adding overlay chrome requires updating/respecting these margins so Apple attribution stays correct. Agents must not cover attribution carelessly.
- **Nav element menu:** Agents pick from: bottom nav · map top chrome · cream page header · modal flow chrome · route fullScreenCover (incl. nesting) · create menu · text links · map attribution margins. **New navigation chrome** requires an explicit design-system decision.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** when overlays change.
- **Recommended mechanism:** Map shell layout tokens + documented nav catalog.

---

## Category 8 — Agent rules (summary for future implementation)

1. One bottom nav on map shell only — no secondary tab bars.
2. Map top chrome is map-only; ivory screens use cream page header.
3. Destinations/flows use fullScreenCover (+ approved nesting).
4. Modal flows share back/close chrome on DS-001.
5. Create menu = create hub; in-content navigation = text links.
6. Respect map attribution margins when adding map chrome.
7. New nav chrome needs a DS decision.

---

## Category 9 — Sheets, expanded rows, and modal actions

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-064 — Map bottom-sheet chrome (H1, H2)

- **Existing UI:** `FriendDetailBottomSheet` + `DayDetailBottomSheet`; `MapPopupSheetBackground`; drag handle; spring settle; drag-to-dismiss.
- **My decision:** Shared **map bottom-sheet chrome** owns container, presentation motion, handle, map sheet glass (DS-011), dismiss scrim/tap. Content is injected (e.g. friend detail body, day detail body). Do **not** use system `.sheet` for these full-bleed map/calendar popups (side insets break the look). Friend detail content stays a separate content component using approved person/availability/avatar/CTA patterns.
- **Must remain consistent:** Motion, handle, map sheet surface, dismiss behavior.
- **May vary:** Height, content composition.
- **Reuse required for future features:** **Yes** for map/calendar inspect popups.
- **Existing screens need migration:** **Yes** — extract shared chrome from friend/day sheets.
- **Recommended mechanism:** Shared sheet chrome container + content slots.

### DS-065 — Expandable rail surface tokens (H3)

- **Existing UI:** Expandable friend rail buttons — flat cream fill + thin walnut rim, flush on card (`expandableFriendRailSurface`).
- **My decision:** Rail button chrome is part of the **expandable person-row pattern** (DS-008/DS-028). Reuse the same surface treatment whenever an action rail is used. Do not invent glass or new rail button recipes per feature.
- **Must remain consistent:** Flush cream + walnut rim rail controls, spacing/animation from expandable pattern.
- **May vary:** Action labels/symbols/set.
- **Reuse required for future features:** **Yes** when using expandable rails.
- **Existing screens need migration:** **Selective** — extract rail surface into pattern.
- **Recommended mechanism:** Shared rail button style within expandable pattern.

### DS-066 — System menus and confirmations (H4, H5, H6, H9)

- **Existing UI:** Row `Menu` overflow; plan `contextMenu`; `confirmationDialog` for remove/block/cancel/photo/etc. (DS-009).
- **My decision:** Approved non-sheet action surfaces:
  - System **`Menu`** for row overflow
  - System **`contextMenu`** for secondary card actions
  - System **`confirmationDialog`** for multi-action menus (photo choose/remove)
  - **DS-090** `.pushConfirmation` for destructive confirmation (Issue #83; supersedes DS-009 for confirms)
- No freeform custom popover/action-panel chrome outside DS-090.
- **Must remain consistent:** Menu/contextMenu platform patterns; destructive confirms use DS-090.
- **May vary:** Menu item lists and copy.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** Destructive confirms → DS-090; photo menus stay system.
- **Recommended mechanism:** Platform menus + DS-090 confirmation family.

### DS-067 — Bottom sheet vs fullScreenCover (H7)

- **Existing UI:** Map/calendar bottom sheets vs Start Push/Profile/Add Group covers.
- **My decision:**
  - **Map bottom sheet** = lightweight inspect-and-act on map/calendar.
  - **fullScreenCover** = destinations and multi-step/task flows (DS-059).
- Do **not** put multi-step create/edit flows in bottom sheets without a design-system decision.
- **Must remain consistent:** Presentation choice by task weight.
- **May vary:** Which destination uses cover nesting.
- **Reuse required for future features:** **Yes** — architecture rule.
- **Existing screens need migration:** **No**.
- **Recommended mechanism:** Documented presentation rules.

### DS-068 — Toast pattern (H8)

- **Existing UI:** Friends toast-style message (control-glass chrome).
- **My decision:** Document the existing Friends toast as the **visual reference**. **Centralize a simple control-glass toast component when a second screen needs it**; until then do not invent parallel toast chrome. Not required for every surface.
- **Must remain consistent:** Control-glass toast language when centralized.
- **May vary:** Message copy; duration if product-defined later.
- **Reuse required for future features:** **Yes** once a second use exists; until then avoid new toast recipes.
- **Existing screens need migration:** **When second use appears** or if consolidating proactively in implementation pass.
- **Recommended mechanism:** Optional shared toast; reference-first.

### DS-069 — Sheet/action menu + new-rule

- **My decision:** Agents must choose from:
  1. Map bottom-sheet chrome + content (DS-064)
  2. Expandable row wrapper + rail (DS-028/DS-065)
  3. System Menu / contextMenu / confirmationDialog (DS-066/DS-009)
  4. fullScreenCover flows (DS-059/DS-067)
  5. Toast (DS-068) when appropriate
- **New sheet physics, custom action panels, or non-system floating action chrome** require an explicit design-system decision.
- **Reuse required for future features:** **Yes**.
- **Recommended mechanism:** Documented catalog in final DS spec.

---

## Category 9 — Agent rules (summary for future implementation)

1. Map/calendar popups → shared bottom-sheet chrome (not system `.sheet`).
2. Expandable rails reuse flush cream rail button surface.
3. Overflow/secondary/destructive → system Menu, contextMenu, confirmationDialog.
4. Lightweight inspect → bottom sheet; multi-step/destination → fullScreenCover.
5. Toast: Friends as reference; centralize on second use; no parallel toast chrome.
6. New sheet/action chrome needs a DS decision.

---

## Category 10 — Empty, loading, and error states

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-070 — Surface content phase model (E1)

- **Existing UI:** `SurfaceContentPhase` — loading / empty / failed / content / deferred.
- **My decision:** **Required shared phase model** for primary content surfaces. Agents must not invent parallel phase enums for the same concept.
- **Must remain consistent:** Phase vocabulary and meaning.
- **May vary:** Which phases a given surface uses (e.g. deferred only where applicable).
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** where custom phase naming exists.
- **Recommended mechanism:** Shared `SurfaceContentPhase` (or successor) in design system.

### DS-071 — Full-page empty, loading, failed (E2, E3, E10)

- **Existing UI:** `EmptySurfaceView`, `EmptySurfaceStateView`, `EmptySurfaceCopy` / `EmptySurfaceLayout`; forks in Blocked, Add Friends, FriendsEmptyState.
- **My decision:** Canonical **full-page empty** (`EmptySurfaceView`) and **loading/failed** (`EmptySurfaceStateView`) for ivory and modal full content areas. Copy/layout via shared empty surface tokens. **Migrate** private state-view forks onto this family (feature-specific copy only). Primary/retry CTAs use **branded** DS-002 styles only (DS-003) — never `.borderedProminent` as a design family.
- **Must remain consistent:** Layout density, typography hierarchy, branded CTAs, ProgressView tint language.
- **May vary:** Title/message/icon/action per surface via parameters/copy table.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — Blocked, Add Friends, any `.borderedProminent` empty/error CTAs, Friends empty if forked.
- **Recommended mechanism:** Shared empty/loading/failed components + copy table.

### DS-072 — Map empty/failed overlay (E4)

- **Existing UI:** `MapEmptyOverlay` on control glass (DS-026 C9).
- **My decision:** Map empty/failed stays **control-glass overlay card** — not full-page cream empty. CTAs branded. Distinct from ivory EmptySurface full-page.
- **Must remain consistent:** Overlay card chrome and non-blocking map placement.
- **May vary:** Empty vs failed copy/actions.
- **Reuse required for future features:** **Yes** for map surface emptiness.
- **Existing screens need migration:** **Selective** — branded CTAs if still system chrome.
- **Recommended mechanism:** Shared map overlay component.

### DS-073 — Mutation errors vs load errors vs soft reload (E5, E8)

- **Existing UI:** `ActionErrorBanner`; soft reload in list VMs; silent foreground `refreshSession` failures.
- **My decision:**
  - **Initial/hard load failure** → full-page failed (or map overlay on map).
  - **Recoverable mutation failure** → `ActionErrorBanner` (DS-022); keep last content visible.
  - **Soft reload / pull-to-refresh** → preserve last loaded content while refreshing.
  - **Silent session refresh** (e.g. foreground) failures stay **silent** unless product later decides otherwise.
- **Must remain consistent:** Error channel by failure type as above.
- **May vary:** Banner message copy; retry targets.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** — ensure mutations never use full-screen failed as the only channel.
- **Recommended mechanism:** Banner + documented error-routing rules.

### DS-074 — Deferred surfaces (E6)

- **Existing UI:** Feed `.deferred` + `EmptySurfaceView` without CTA.
- **My decision:** Deferred features use **`.deferred` phase** + empty-style presentation **without fake content** and typically **without primary CTA** (or deferred-specific copy only). Do not invent placeholder feed rows.
- **Must remain consistent:** Honest deferred empty, not mock content.
- **May vary:** Copy/icon for the deferred feature.
- **Reuse required for future features:** **Yes** until feature goes live.
- **Existing screens need migration:** **No**.
- **Recommended mechanism:** Phase + EmptySurface without action.

### DS-075 — Inline no-results + local busy (E7, E9)

- **Existing UI:** Friends search no-match stays content; row-level ProgressView / disabled actions.
- **My decision:**
  - **Search/filter no-results** stays **inline within `.content`** — not full-page empty, not failed. Lightweight message using empty-surface text hierarchy.
  - **Local busy** for single-row/control actions (accept resolving, unblock, rail spinner) — **never** replace the whole list with a spinner for one action. Request resolving stays in request-card lifecycle (DS-030).
- **Must remain consistent:** Content phase for no-results; local busy scoped to acting control.
- **May vary:** No-results copy; which control shows busy.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Inline empty pattern + control-level busy conventions.

### DS-076 — Empty/error menu + new-rule

- **My decision:** Agents must choose from:
  1. Surface phase model (DS-070)
  2. Full-page empty / loading / failed (DS-071)
  3. Map empty/failed overlay (DS-072)
  4. Action error banner (DS-073/DS-022)
  5. Deferred empty (DS-074)
  6. Inline no-results (DS-075)
  7. Local control busy (DS-075)
- **No new full-screen error/empty chrome** without an explicit design-system decision.
- **Reuse required for future features:** **Yes**.
- **Recommended mechanism:** Documented catalog in final DS spec.

---

## Category 10 — Agent rules (summary for future implementation)

1. All primary surfaces report `SurfaceContentPhase` (or successor).
2. Full empty/loading/failed → EmptySurface family; migrate forks; branded CTAs only.
3. Map emptiness → overlay card, not cream full-page.
4. Mutations → banner; hard load → failed; soft reload keeps content; silent refresh stays silent.
5. Deferred = honest empty, no fake rows.
6. No-results inline in content; busy is local to the acting control.
7. New empty/error chrome needs a DS decision.

---

## Category 11 — Typography, spacing, radii, borders, shadows, color, motion

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-077 — Semantic color tokens only (T1)

- **Existing UI:** `PushColorPalette`, `PushControlColors`, availability (DS-043), cream roles (DS-014), destructive, Plans metadata, onboarding domain colors.
- **My decision:** Feature code uses **public semantic color tokens only** (brand accents, text hierarchy, destructive, availability, cream roles, approved status/pill fills). **No raw RGB/hex in feature views.** Do not force distinct semantic roles (e.g. Plans metadata vs `textSecondary`) to one numeric value — name both. Onboarding colors remain domain-local temporarily (DS-016).
- **Must remain consistent:** Semantic mapping; no black text/shadows as brand.
- **May vary:** Which semantic token a component consumes.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — replace literals with tokens over implementation phases.
- **Recommended mechanism:** Central color token module(s).

### DS-078 — Typography (T2)

- **Existing UI:** System SF semantic styles; `PushTypography.rounded` / `.text`; section uppercase + kerning.
- **My decision:** Prefer **semantic text styles** (largeTitle…caption2 + weights) over one-off point sizes. **Rounded** design only for initials, monospaced/time digits, and other approved glyph cases. Shared **section-label** style (uppercase, kern, tertiary). Fixed sizes only via **named type tokens** when semantic styles cannot express the need. No custom font files this pass.
- **Must remain consistent:** SF-only; section-label recipe; rounded usage rules.
- **May vary:** Weight within a style where hierarchy needs it.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** — promote repeated fixed sizes to tokens.
- **Recommended mechanism:** Type scale + section-label component/style + PushTypography helpers.

### DS-079 — Spacing & adaptive layout (T3)

- **Existing UI:** `PushAdaptiveLayout` + feature `*Layout` enums.
- **My decision:** **Adaptive layout owns cross-screen spacing** (page/modal padding, card padding, section/row spacing, avatar/control sizes, etc.). Feature layout enums keep **true component-local** constants only. Duplicated spacing values should promote into adaptive or shared spacing tokens. Agents must not invent page margins outside `pageHorizontalPadding` / `modalHorizontalPadding` (or successors).
- **Must remain consistent:** Adaptive tiers and semantic metrics.
- **May vary:** Component-local spacing that is genuinely unique.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** promotion of duplicates.
- **Recommended mechanism:** Expand/document `PushAdaptiveLayout` as spacing source of truth.

### DS-080 — Radii (T4)

- **Existing UI:** Adaptive card radius; nav container radius; capsules; continuous corners.
- **My decision:** Named radius roles — **card**, **control/container**, **row/field**, **pill (capsule)**, **sheet** — mapped to adaptive or fixed tokens. Always **continuous** corner style. No magic radii in views.
- **Must remain consistent:** Continuous corners; role-based radii.
- **May vary:** Which role a component uses.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective**.
- **Recommended mechanism:** Radius token table.

### DS-081 — Borders & shadows via surfaces (T5, T6)

- **Existing UI:** Walnut hairlines, white glass edges, multi-stroke stacks inside Plans/Review glass; warm shadows never black.
- **My decision:** Borders and shadows are implemented **inside named surfaces/components** (Category 2). Feature code does **not** invent new stroke stacks or freeform shadows. Internal elevation/stroke tokens may exist for building approved surfaces — **not** a public freeform elevation API (DS-016). **No pure black shadows.**
- **Must remain consistent:** Warm shadow language; surface-owned chrome.
- **May vary:** N/A at feature layer.
- **Reuse required for future features:** **Yes** — pick a named surface.
- **Existing screens need migration:** **Selective** when consolidating surfaces.
- **Recommended mechanism:** Surface implementations + internal tokens.

### DS-082 — Motion tokens (T7)

- **Existing UI:** Selection/expand/sheet springs; press 0.18 ease; map pulse 2.4s; menu/dropdown springs.
- **My decision:** Named motion tokens: **selection**, **expand**, **sheet** (interactive spring), **press** (scale + duration), **map pulse**. Feature code picks a named motion; no new spring/duration literals without promoting a token or a DS decision.
- **Must remain consistent:** Named motion set behavior.
- **May vary:** Which named motion a interaction uses.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — replace scattered spring literals over time.
- **Recommended mechanism:** `PushMotion` (or equivalent) token enum.

### DS-083 — Opacity, min scale, token discipline (T8, T9, Q7)

- **Existing UI:** Inactive 0.7, disabled CTA 0.45, scrims, scattered `minimumTextScale`.
- **My decision:** Named opacities for **disabled control**, **inactive label**, **scrim**. Shared **minimum text scale** for dense truncating labels. Chip/surface-specific opacities stay inside component/surface tokens. **Token discipline:** any new color, type size, spacing, radius, shadow, or motion value must be **promoted into the token system** or approved via design-system decision — not left as local magic numbers in feature views.
- **Must remain consistent:** Shared disabled/inactive/scrim/min-scale; no magic numbers for shared concerns.
- **May vary:** Component-private opacities that are part of an approved surface recipe.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Selective** ongoing.
- **Recommended mechanism:** Opacity + min-scale tokens; lint/docs for agents.

---

## Category 11 — Agent rules (summary for future implementation)

1. Semantic colors only — no hex/RGB in feature views.
2. Semantic type first; rounded for approved cases; shared section labels.
3. Adaptive layout for cross-screen spacing; no ad-hoc page margins.
4. Named radii; continuous corners.
5. Borders/shadows only via named surfaces — no freeform elevation API.
6. Named motion tokens only.
7. Shared disabled/inactive/scrim/min-scale; new values → tokens or DS decision.

---

## Category 12 — Agent discovery & recreation patterns

**Source of truth:** User agreed to auditor recommendations (this session).  
**Implementation:** Deferred until full design-system specification is approved.

### DS-084 — Design-system code home (D1)

- **My decision:** Implement a dedicated module/folder (e.g. `Push/DesignSystem/` or `Push/UI/`) for tokens, named surfaces, and shared components. Feature screens compose system pieces; they do not own visual recipes.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** — incremental move of shared chrome into the module.
- **Recommended mechanism:** Clear package boundary + re-exports if needed for discoverability.

### DS-085 — Catalog + AGENTS entry point (D2)

- **My decision:** Maintain a single catalog (`docs/design-system.md` and/or module README) as the **mandatory agent entry point**: approved components/surfaces/tokens, when-to-use, do-not-recreate lists, DS-xxx links. Pointer from `AGENTS.md` / `Claude.md` so session resume hits it.
- **Reuse required for future features:** **Yes** — agents start here.
- **Existing screens need migration:** N/A (docs).
- **Recommended mechanism:** Catalog doc + project guide links.

### DS-086 — Discovery process + decision log law (D3, D9)

- **My decision:** Before new UI: (1) read catalog, (2) match surface → component family → tokens, (3) prefer extend via variant/slot, (4) if nothing fits → stop and propose a design-system decision (no local near-duplicate). `tasks/design-system-decision-log.md` remains product decision source; catalog summarizes must-reuse rules; both stay in sync when families change.
- **Reuse required for future features:** **Yes** — process is mandatory.
- **Recommended mechanism:** Documented checklist in catalog + AGENTS.

### DS-087 — Naming conventions (D4)

- **My decision:** Stable `Push…` prefix for system primitives (buttons, surfaces, person row, etc.). Migrate shared chrome away from feature-prefixed names (`FriendsCircleButton` → system circular icon button). Feature-specific **flows/screens** may keep feature names (`StartPushFlowView`) but must use system chrome underneath.
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** as components are extracted (typealiases/renames acceptable for transition).
- **Recommended mechanism:** Naming section in catalog + incremental renames.

### DS-088 — Feature-local vs system + guardrails (D5, D7)

- **Allowed feature-local:** Screen composition, ViewModels, routing, feature-unique copy, true one-offs after DS decision (nav +, self puck, calendar internals, etc.), onboarding/auth domain until alignment.
- **Not allowed feature-local:** Glass/cream recipes, primary CTAs, person-row visuals, availability colors, empty/error chrome, raw color literals, parallel circular buttons, etc.
- **Hard bans** documented in project guides (no new material stacks in features, no `.borderedProminent` product chrome, no second person-row/empty-state, no raw colors). Optional CI/lint later — **not required** for first extraction pass.
- **Reuse required for future features:** **Yes**.
- **Recommended mechanism:** AGENTS hard-ban list + catalog.

### DS-089 — Migration, previews, priority (D6, D8, D10)

- **My decision:** Incremental migration preserving approved appearance — no big-bang redesign. Each system component gets DEBUG previews (`PushPreviewMatrix` where useful). Extraction priority:
  1. Circular icon button + primary CTAs
  2. Cream list foundation + person row (incl. blocked)
  3. Empty/loading/failed + branded recovery CTAs
  4. Named surfaces (control glass, cream page/card, plans/review glass)
  5. Availability tokens + chips
- **Reuse required for future features:** **Yes**.
- **Existing screens need migration:** **Yes** per priority waves.
- **Recommended mechanism:** Phased migration plan in design-system spec.

### DS-090 — Branded destructive confirmation dialogs (Issue #83)

- **Existing UI:** System `confirmationDialog` for sign out, delete account, remove/block friend, unblock, leave/delete/transfer group, remove member, cancel invite, cancel/delete push (DS-009 / DS-066).
- **My decision:** Ship a shared **centered cream confirmation card** on a dim scrim (`PushConfirmationDialog` + `.pushConfirmation`). Destructive confirms use filled `PushControlColors.destructive` capsule (danger role — **not** a third primary CTA). Cancel is secondary text. Local `isPresented` / pending-item state (no global presenter). Window-level presentation so list nesting works. Supersedes DS-009 for **destructive confirmation** only.
- **Must remain consistent:** Cream card + dialog scrim; confirm above cancel; scrim tap cancels; explicit confirm required before mutation; existing action copy; loading/disabled hooks when needed.
- **May vary:** Title/message/confirm/cancel labels per flow.
- **Out of scope this decision:** Multi-action menus (photo choose/remove) stay system `confirmationDialog`; info `.alert`s stay system; `Menu` / `contextMenu` stay system (DS-066 narrowed).
- **Reuse required for future features:** **Yes** — use `.pushConfirmation` for destructive confirms; do not one-off popup chrome.
- **Existing screens need migration:** **Yes** — inventory in `docs/superpowers/specs/2026-07-24-confirmation-dialogs-design.md`.
- **Recommended mechanism:** Shared DesignSystem dialogs family + view modifiers.

---

## Category 12 — Agent rules (summary for future implementation)

1. Shared UI lives in DesignSystem module; features compose only.
2. Catalog + AGENTS pointer = mandatory discovery entry.
3. Discover → reuse/extend → else DS decision; log + catalog stay in sync.
4. `Push…` names for system chrome; feature names for flows only.
5. Hard bans for recreation hotspots; lint optional later.
6. Incremental migration; DEBUG previews; priority extraction order.

---

## Post-interview extensions

- **DS-090** (Issue #83): branded destructive confirmation dialogs. Spec: `docs/superpowers/specs/2026-07-24-confirmation-dialogs-design.md`.
- **DS-091** (Issue #9 Feed create-post): Share a moment hub chooser rows + contribution chips.

### DS-091 — Moment / past-Push chooser rows (Feed create hub)

- **Existing UI:** `CreatePostChooserRow` family on Share a moment (media-thumb moments, avatar-stack past Pushes, pinned create-from-scratch action) + compact contribution capsules.
- **My decision:** Promote to DesignSystem as **semantic cream chooser rows**, separate from Plans `PushHistoryRow` (DS-021) and still distinct from deferred Feed activity-list chrome (DS-033):
  - `PushMomentChooserRow` — existing moment (leading media slot, title, date · location, contributor stack + media count + contribution chip, chevron)
  - `PushPastPushChooserRow` — past Push without a moment (fixed-width attendee stack, title, meta, chevron; no media thumb)
  - `PushCreateActionChooserRow` — pinned create-from-scratch (square sunbeam + mark matching thumb size)
  - Shared: `PushChooserThumbFrame`, `PushChooserAvatarStack`, `PushChooserPerson`, `PushMomentChooserMetrics`
  - `PushContributionChip` — compact **Open for adds** (sunbeam) / **You contributed** (muted walnut); not availability chips (DS-044) and not brand status pills (DS-045)
- **Must remain consistent:** `pushSolidCreamCard` + Friends list density; chevron affordance; fixed past-Push stack width for column align.
- **May vary:** Leading media content (feature supplies thumb); product copy for chips/titles.
- **Out of scope:** Live feed activity timeline rows (still DS-033); publishing/backend.
- **Reuse required for future features:** **Yes** for create-post / moment chooser lists.
- **Existing screens need migration:** **Done** for create-post hub adapters.
- **Recommended mechanism:** Exact shared components + feature adapters over `CreatePostHistoryItem` / media types.

## Interview complete

All categories 1–12 confirmed (DS-001–DS-089); DS-090 confirmations; DS-091 moment chooser rows.  
**Spec (design system):** `docs/superpowers/specs/2026-07-21-push-design-system-specification.md`  
**Spec (confirmations):** `docs/superpowers/specs/2026-07-24-confirmation-dialogs-design.md`  
**Handoff (history):** `tasks/design-system-handoff.md`  
**Catalog:** `docs/design-system.md`

