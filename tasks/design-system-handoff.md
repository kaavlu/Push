# Push Design System — Implementation Handoff

**Status:** Spec approved · **Waves 0–9 complete** · system operational  
**Issue:** #63

---

## For agents (ongoing)

### Read first

1. **`docs/design-system.md`** — catalog, hard bans, error routing, code map  
2. **`tasks/design-system-decision-log.md`** — DS-001–DS-089 (product law)  
3. **`Push/DesignSystem/README.md`** — file map + quick “use this”  
4. Optional history: this file; `Design/PushThemeAudit.md` (read-only, superseded for implement)

### Do not

- Redesign or invent near-duplicates of catalog components  
- Merge families the log keeps separate (two primaries, Review vs Plans cards, map vs control glass)  
- Use onboarding/auth CTAs inside the main app  
- Freeform glass APIs or a third primary CTA  
- DIY map pucks, second person-row, or local empty/error chrome  

### Do

- Open the catalog before adding UI chrome  
- Named surfaces + catalog components only  
- New shared values → tokens or a design-system decision  
- Preserve approved appearance  

---

## Deliverables

| Deliverable | Location |
|---|---|
| Decisions DS-001–DS-089 | `tasks/design-system-decision-log.md` |
| Spec + wave plan | `docs/superpowers/specs/2026-07-21-push-design-system-specification.md` |
| Agent catalog | `docs/design-system.md` |
| Module | `Push/DesignSystem/` |
| AGENTS / Claude links | `agents.md`, `CLAUDE.md` |

---

## Wave tracking (complete)

- [x] Wave 0 — Scaffold + catalog + AGENTS links  
- [x] Wave 1 — Buttons & primary CTAs  
- [x] Wave 2 — Cream lists & person system  
- [x] Wave 3 — Empty / loading / error  
- [x] Wave 4 — Named surfaces + cream tokens  
- [x] Wave 5 — Availability, chips, avatars, pucks  
- [x] Wave 6 — Selectors, headers, sheets  
- [x] Wave 7 — Plan cards & subcomponents  
- [x] Wave 8 — Tokens & motion cleanup  
- [x] Wave 9 — Docs polish  

Further UI work is catalog-driven. New families require an explicit design-system decision (user is source of truth).
