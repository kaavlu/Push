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
- **Data:** Parallel mock/live `AppDataContainer` (DEBUG mock default, `--live` opt-in, Release live). Live auth paths warm a session-scoped `LiveDataStore` before `ContentView`; new accounts with null `onboarding_completed_at` see `PostAuthOnboardingView` first (`0019` — see `AGENTS.md` Production auth). Day-1 Supabase social graph reads plus live write-through for profile basics/toggles/availability/photo (Storage `avatars`, `0012`), push coordination (`SupabasePushRepository`), friend-request coordination (`SupabaseAlertRepository` + `FriendRepository` search/send/cancel/remove; `0009`/`0010`/`0013`), and group creation + group-invite coordination (`GroupRepository.createGroup` + `AlertRepository`; `0011`); mock group lifecycle via `LocalGroupRepository`/`InMemoryDatabase+GroupLifecycle` (mock photos via `GroupPhotoFileStore`); live group lifecycle + photos via `SupabaseGroupRepository`/`0015` RPCs + `GroupPhotoStoring` (`group-photos` Storage); user blocks (mock + live via `FriendRepository` block/unblock/list + `0016` RPCs; soft-hide; `private.is_blocked` guards social paths). Moments S5 live `SupabaseMomentRepository` + `0026` feed/hub RPCs (S4 domain/mock; Feed UI still fixture-only); backend S1–S5 (`0021`–`0026` schema/RPCs + `moment-media` Storage) — see `AGENTS.md` Feed tab; presence reads/writes `current_presence` via `SupabasePresenceSync`/`LocationSession`; live friend patches via `PresenceRealtimeBridge` (`0020`) — see `AGENTS.md` Location/presence; no mock data leaks. See `AGENTS.md`, `tasks/spec.md`, `docs/data-architecture.md`.
- **Maps:** MapKit

This is a **high-fidelity prototype** that can become production later.

---

## MVP Features

1. **Live Map** — center of the app; friends shown with immediate social context
2. **Friend Status** — live status per friend (place, activity, availability, who they're with)
3. **Friend Detail** — tap a friend to see more; lightweight, not a full profile
4. **Feed** — social **Moments** (media albums from hangs; Feed › Pushes tab). Activity timeline (`FeedEvent`) and Feed › Now deferred
5. **Who's Down** — quick answer to "is anything happening right now?"
6. **Pull Up** — low-pressure signal of social intent (faster than starting a group chat); creation UX is the 4-step **Start Push** flow (`StartPushFlowView`); launch from map create menu (`MainMapRoute.startPush`) or Pushes tab (`PlansView`).
7. **Friend Groups** — real-world circles with member statuses, activity, pushes
8. **Push Cards** — shared coordination objects (not chat threads)
9. **Privacy Controls** — simple visibility settings per activity

### Availability States
`Free now` · `Free soon` · `Maybe down` · `Busy` · `Joinable` · `Driving / ETA`

---

## What NOT to Build Yet

- Live writes to social graph (friends/groups/sharing), Realtime/subscriptions beyond `current_presence` — profile self-writes (basics, toggles, availability, photo), push coordination (create/edit/cancel/delete, RSVP), friend-request coordination (search/send/cancel/accept/deny via `0009`/`0013`; remove via `0010`/`0013`), group creation + group-invite coordination (`0011`) + group lifecycle (`0015`), user block/unblock via `0016`, presence Realtime (`PresenceRealtimeBridge`, migration `0020`), and Moment reads/mutations (`SupabaseMomentRepository`, `0023`/`0026`) are allowed
- Push notifications
- iMessage extension
- Large groups
- Dating / social graph features

---

## Design Direction

**Feel:** Premium, Apple-native, social, lightweight, clear, calm, trustworthy, high-fidelity.

**Avoid:** Generic map app feel, surveillance dashboard feel, chat app feel, social media clone feel, enterprise dashboard feel.

**Design system (Issue #63, operational):** Waves 0–9 complete — catalog-driven for UI chrome; new families need a DS decision. Open **`docs/design-system.md`** before adding UI chrome. Code home: `Push/DesignSystem/`. Decisions: `tasks/design-system-decision-log.md`. Spec/waves: `docs/superpowers/specs/2026-07-21-push-design-system-specification.md`. Handoff: `tasks/design-system-handoff.md`. Named surfaces only (`pushControlGlass`, `pushMapControlGlass`, `pushPuckGlass`, `pushPlansCardGlass`, `pushReviewDeckGlass`, `PushIvoryPageBackground`, `pushSolidCreamCard`, `PushModalBackground`); primaries are solid sunbeam or glass+walnut rim only; circular utility → `PushCircleIconButton`; person lists → `PushPersonRow` (expand optional); empty/loading/failed → `EmptySurface*` / map → `MapEmptyOverlay`; mutations → `ActionErrorBanner`; destructive confirms → `.pushConfirmation` (DS-090; see `AGENTS.md`); availability colors → `PushAvailabilityTokens`; list/sheet availability → `PushAvailabilityChip`; person faces → `PushPersonAvatar` (dark/sunbeam); map pucks only via named puck family (no DIY). Plan cards (Wave 7) → `PushPlansPlanCard`/`PushReviewPlanCard` + shared subcomponents; leave `PlansCalendarView` whole. Wave 8 tokens → `PushMotion`, `PushOpacityTokens`, `PushRadiusTokens`, `PushTypographyTokens` (no scattered spring literals). Preserve approved appearance.

---

## Coding Standards

See `coding-standards.md` for the full reference. Key rules for this project:

- **MVVM strictly.** ViewModels own state and logic; Views are dumb.
- **Mock by default.** DEBUG mock unless `--live`; auth/repos only via injected services (`AuthService`, repository protocols). Mock: no GPS; live: when-in-use Core Location (see `AGENTS.md` Location/presence).
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
| `docs/design-system.md` | Agent UI catalog (Issue #63) |
| `docs/app-store-privacy.md` | App Store Connect privacy disclosure inventory |
| `tasks/design-system-handoff.md` | Design-system historical wave tracking (Issue #63 complete) |
| `tasks/lessons.md` | Project-specific learnings and gotchas |

### Session Resume Protocol

Read: `CLAUDE.md` → `tasks/lessons.md` → `tasks/todo.md` → `git log --oneline -5`. When implementing a multi-task feature, also read the matching file under `docs/superpowers/specs/` (design) or `docs/superpowers/plans/` (execution). For data-layer, seed, or Supabase work, also read `supabase/README.md`, `docs/data-architecture.md`, and `tasks/spec.md` (Issue #27); use repo `.claude/skills/supabase*` skills for schema/RLS. Feed/Moment work: also read `docs/superpowers/specs/2026-07-28-feed-moment-backend-requirements-audit.md` (#114), `docs/superpowers/specs/2026-07-28-feed-moment-product-contract.md` (#115), and backend architecture `docs/superpowers/specs/2026-07-28-feed-moment-backend-architecture.md` (#116); `AGENTS.md` Feed tab bullet. Auth/post-auth onboarding work: also read `docs/superpowers/specs/2026-07-24-production-lab-auth-ui-design.md` and `AGENTS.md` Production auth bullet. Location/presence work: also read `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (Issue #64) and `AGENTS.md` Location/presence bullet. Realtime presence sync (Issue #84): read design `docs/superpowers/specs/2026-07-24-realtime-presence-sync-design.md`; implementation `docs/superpowers/plans/2026-07-24-realtime-presence-sync.md`. UI chrome: open `docs/design-system.md` first (Issue #63 operational; new families need a DS decision). For visual/design work, read `Design/PushDesignBrief.md`; `Design/PushThemeAudit.md` is read-only history superseded for implementation by the catalog. Live source is `Push/` / `Push/DesignSystem/` — `Design/CoreDesignFiles/` are read-only snapshots.

Do not ask the user to re-explain context that is in these files.

### Documentation Sync

- A `post-commit` hook runs the documentation-updater skill after each commit.
- Auto-generated doc commits must include `[skip ci]` in the message to avoid hook recursion.
- Update context files only for durable facts; prefer no update over bloat. Skill: `.cursor/skills/documentation-updater/SKILL.md`.

---

## Status Language

Status copy should feel **natural, casual, and socially safe.** When confidence is high, be specific. When confidence is lower, soften the wording. Never make it feel like surveillance.

User-facing coordination copy uses **Push/Pushes** (not Plan/Plans). Internal types and files may still use `Plan*`/`Plans*` prefixes until refactored.
