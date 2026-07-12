# Push — Project Guide

## What is Push

Push is a private live map for real friends. The core value prop: **know the move before the group chat does.**

It helps close friends understand what's happening around them — where people are, what they're doing, who they're with, and whether something social is forming — without needing to text everyone.

Push is **not** a tracking app, not a generic map app, and not a chat app. It should feel like a premium Apple-native social layer for real life.

---

## Stack

- **Platform:** iOS
- **Framework:** SwiftUI
- **Target:** iOS 17+
- **Architecture:** MVVM
- **Data:** Parallel mock/live `AppDataContainer` (DEBUG mock default, `--live` opt-in, Release live). Day-1 Supabase is reads-only social graph; no mock presence/push/feed in live sessions. See `AGENTS.md`, `tasks/spec.md` (Issue #27), `docs/data-architecture.md`.
- **Maps:** MapKit

This is a **high-fidelity prototype** that can become production later.

---

## MVP Features

1. **Live Map** — center of the app; friends shown with immediate social context
2. **Friend Status** — live status per friend (place, activity, availability, who they're with)
3. **Friend Detail** — tap a friend to see more; lightweight, not a full profile
4. **Feed** — real-life social activity (arrivals, availability shifts, groups forming)
5. **Who's Down** — quick answer to "is anything happening right now?"
6. **Pull Up** — low-pressure signal of social intent (faster than starting a group chat); creation UX is the 4-step **Start Push** flow (`StartPushFlowView`); launch from map create menu (`MainMapRoute.startPush`) or Pushes tab (`PlansView`).
7. **Friend Groups** — real-world circles with member statuses, activity, pushes
8. **Push Cards** — shared coordination objects (not chat threads)
9. **Privacy Controls** — simple visibility settings per activity

### Availability States
`Free now` · `Free soon` · `Maybe down` · `Busy` · `Joinable` · `Driving / ETA`

---

## What NOT to Build Yet

- Live writes to social data, realtime/subscriptions (Day-1 Supabase is reads-only)
- Real-time location sharing
- Real activity inference
- Push notifications
- iMessage extension
- Ghost Mode
- Large groups
- Weekly recap history (History › stub)
- Dating / social graph features

---

## Design Direction

**Feel:** Premium, Apple-native, social, lightweight, clear, calm, trustworthy, high-fidelity.

**Avoid:** Generic map app feel, surveillance dashboard feel, chat app feel, social media clone feel, enterprise dashboard feel.

---

## Coding Standards

See `coding-standards.md` for the full reference. Key rules for this project:

- **MVVM strictly.** ViewModels own state and logic; Views are dumb.
- **Mock by default.** DEBUG mock unless `--live`; auth/repos only via injected services (`AuthService`, repository protocols). No real location.
- **Files ≤ 400 lines.** Split by responsibility.
- **Functions ≤ 40 lines, single responsibility.**
- **No magic numbers.** Named constants only.
- **Comments explain WHY, not WHAT.**
- **Spec before code** for non-trivial features. Write `tasks/spec.md` first.
- **Commit frequently.** At least after each logical component.

### Task Files

| File | Purpose |
|---|---|
| `tasks/todo.md` | Current plan and progress tracking |
| `tasks/spec.md` | Feature spec (write before implementation) |
| `tasks/lessons.md` | Project-specific learnings and gotchas |

### Session Resume Protocol

Read: `CLAUDE.md` → `tasks/lessons.md` → `tasks/todo.md` → `git log --oneline -5`. When implementing a multi-task feature, also read the matching file under `docs/superpowers/specs/` (design) or `docs/superpowers/plans/` (execution). For data-layer, seed, or Supabase work, also read `docs/data-architecture.md` and `tasks/spec.md` (Issue #27); use repo `.claude/skills/supabase*` skills for schema/RLS. For visual/design work, read `Design/PushDesignBrief.md` and `Design/PushThemeAudit.md`; live source is `Push/` — `Design/CoreDesignFiles/` are read-only snapshots.

Do not ask the user to re-explain context that is in these files.

### Documentation Sync

- A `post-commit` hook runs the documentation-updater skill after each commit.
- Auto-generated doc commits must include `[skip ci]` in the message to avoid hook recursion.
- Update context files only for durable facts; prefer no update over bloat. Skill: `.cursor/skills/documentation-updater/SKILL.md`.

---

## Status Language

Status copy should feel **natural, casual, and socially safe.** When confidence is high, be specific. When confidence is lower, soften the wording. Never make it feel like surveillance.

User-facing coordination copy uses **Push/Pushes** (not Plan/Plans). Internal types and files may still use `Plan*`/`Plans*` prefixes until refactored.
