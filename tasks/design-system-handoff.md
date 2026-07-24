# Push Design System — Implementation Handoff

**Status:** Spec approved · **Wave 0–3 implemented** · continue from Wave 4  
**Started:** Issue #63 implementation session

---

## For the next agent / session

### Read first (in order)

1. **This file** — scope, constraints, first steps  
2. **`docs/superpowers/specs/2026-07-21-push-design-system-specification.md`** — full catalog, agent rules, migration waves  
3. **`tasks/design-system-decision-log.md`** — DS-001–DS-089 product decisions (source of truth for “what stays”)  
4. Optional context: `Design/PushThemeAudit.md` (pre-interview extraction; decisions override it where they conflict)

### Do not

- Redesign or “clean up” visuals beyond approved extraction  
- Merge families the log keeps separate (e.g. two primary CTAs, Review vs Plans cards, map glass vs control glass)  
- Restyle onboarding/auth into main-app CTAs this pass  
- Invent freeform glass APIs or a third primary CTA  
- Start at Wave 5+ before Waves 0–1 unless the user reorders  

### Do

- Preserve approved appearance (move/rename/compose, don’t restyle)  
- Follow migration waves in the spec (§8.3)  
- Create `docs/design-system.md` catalog in Wave 0 and link from `AGENTS.md` / `Claude.md`  
- Use DEBUG previews on system components  
- Scoped tests per wave; `scripts/test.sh build` minimum; `full` before PR  
- Update decision log / catalog if a decision must change (user is source of truth)

---

## What’s already done

| Deliverable | Location |
|---|---|
| Full UI discovery interview (12 categories) | This repo session → decision log |
| Confirmed decisions DS-001–DS-089 | `tasks/design-system-decision-log.md` |
| Approved specification + migration plan | `docs/superpowers/specs/2026-07-21-push-design-system-specification.md` |
| Module path choice | `Push/DesignSystem/` |
| Implementation | **Wave 0–3 done** — through empty/loading/error family |

---

## Start here: Wave 0

From the spec:

1. Create `Push/DesignSystem/` skeleton + `README.md`  
2. Add `docs/design-system.md` (inventory from the spec; when-to-use + do-not-recreate)  
3. Link from `AGENTS.md` / `Claude.md` (design-system entry for agents)  
4. Register any new Swift files via `python3 scripts/pbxproj_add.py …`  
5. App behavior/visuals should remain unchanged after Wave 0  

Then **Wave 1** (highest recreation risk): circular icon button + two primary CTAs + empty/error branded CTAs.

Full wave list and exit criteria: spec §8.3.

---

## Hard constraints (quick)

- **Surfaces:** named only (control glass, map glass, puck glass, Plans card glass, Review deck glass, ivory page, solid cream card, modal gradient).  
- **Primaries:** solid sunbeam **or** glass + walnut rim only.  
- **Lists:** solid cream foundation; separate person / group / request / history components.  
- **Person default:** flat person row; expand = optional wrapper.  
- **Blocked:** migrate onto person row (no fork).  
- **Empty/error:** EmptySurface family + ActionErrorBanner; no `.borderedProminent` product chrome.  
- **Map:** map glass + puck family; no DIY pucks; bottom sheets not system `.sheet`.  
- **Tokens:** no raw hex in feature views once tokens land.  
- **Onboarding/auth:** domain-local until a future alignment pass.

---

## Suggested session prompt (copy-paste)

```
Implement the Push design system starting at Wave 0 (then Wave 1) per:
- tasks/design-system-handoff.md
- docs/superpowers/specs/2026-07-21-push-design-system-specification.md
- tasks/design-system-decision-log.md (DS-001–DS-089)

Rules: preserve approved appearance; no redesign; follow wave order;
named surfaces only; update docs/design-system.md and AGENTS.md as specified.
```

---

## Tracking (fill in when implementation starts)

- [x] Wave 0 — Scaffold + catalog + AGENTS links  
- [x] Wave 1 — Buttons & primary CTAs  
- [x] Wave 2 — Cream lists & person system  
- [x] Wave 3 — Empty / loading / error  
- [ ] Wave 4 — Named surfaces + cream tokens  
- [ ] Wave 5 — Availability, chips, avatars, pucks  
- [ ] Wave 6 — Selectors, headers, sheets  
- [ ] Wave 7 — Plan cards & subcomponents  
- [ ] Wave 8 — Tokens & motion cleanup  
- [ ] Wave 9 — Docs polish  

When a wave completes, check it off here and note any intentional decision-log updates.
