# Issue #71 — Supabase `current_presence` Schema, RLS, and Expiry

**Issue:** https://github.com/kaavlu/Push/issues/71  
**Design:** `docs/superpowers/specs/2026-07-23-location-presence-architecture-design.md` (PR4 / §2.4, §2.6, §2.7, §2.7.1, §2.9.1, §5, §10)  
**Builds on:** Issue #64 architecture; social-graph helpers (`private.is_friend`, `private.shares_group`, `private.is_blocked`)

## Status

- [x] Migration `0018_current_presence.sql` — table, constraints, indexes, RLS, RPCs
- [x] Verification script `supabase/tests/0018_current_presence_verify.sql`
- [x] `supabase/README.md` layout entry
- [x] Apply migration to remote via Supabase MCP `apply_migration` (`0018_current_presence`)
- [x] Run verification SQL on remote (all asserts passed; fixtures cleaned; test profiles restored)
- [ ] PR with architecture deviations documented (if any)

## Non-goals (this issue)

- Swift DTOs / row mapping / `LiveDataStore` presence cache
- `SupabaseFriendRepository.presenceStatuses()` / synthetic Place
- Live presence writes, throttle, heartbeat execution
- Core Location / permission UI / Realtime subscriptions
- Map or puck changes / seed presence rows

## Deliverables

| Path | Purpose |
|---|---|
| `supabase/migrations/0018_current_presence.sql` | Schema + RLS + `unpublish_current_presence` + `set_availability_choice` |
| `supabase/tests/0018_current_presence_verify.sql` | Privileged SQL checks (self/friend/block/unpublish/dual-write/anon) |

## Design choices (document in PR)

| Item | Decision |
|---|---|
| `is_published` default | `false` — unpublished until client publishes (safer than default true) |
| Friend SELECT | Approach B: full row for allowed subjects; client `VisiblePresenceBuilder` projects |
| Graph access | `private.is_friend` **or** `private.shares_group`, minus `private.is_blocked` either way |
| Legacy ghost | Friend SELECT also requires `availability <> 'ghost'`; new Ghost path is `unpublish_current_presence` |
| Presence upsert | Direct table INSERT/UPDATE under self RLS (no upsert RPC); live-write PR owns client writer |
| Availability RPC | `set_availability_choice` dual-writes profile + existing presence mirror; does **not** invent a presence row or change coords/`is_published` |
| DELETE | No client DELETE grant/policy; unpublish RPC; cascade via `profiles` on account delete |
| Seed | No presence rows in `seed.sql` |

## Apply + verify

1. Authenticate Supabase MCP (project `tzzvwjhvjduyqywlszqc`).
2. `apply_migration` name `0018_current_presence` with file contents.
3. `execute_sql` with `supabase/tests/0018_current_presence_verify.sql`.
4. Confirm notice: `0018_current_presence verification OK`.
