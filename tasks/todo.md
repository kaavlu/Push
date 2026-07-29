# Issue #117 — Moments S1: tables, helpers, SQL verify

## Status

- [x] `0021_moments_tables.sql` — moments / members / media, indexes, UNIQUE(push_id), RLS, SELECT grant only
- [x] `0022_moments_private_helpers.sql` — private AuthZ helpers + SELECT policies
- [x] `tests/0021_moments_verify.sql` — soft-delete, push slot, stranger, friend, block path/media
- [x] `supabase/README.md` entries
- [x] Applied remote via MCP (`0021_moments_tables`, `0022_moments_private_helpers`)
- [x] Ran verify on remote (alice/bob/carol) — OK

## Out of scope (later slices)

Mutation RPCs, Storage, MomentRepository, Feed UI, Realtime, notifications.

## Next

S2 — mutation RPCs + permission matrix SQL cases.
