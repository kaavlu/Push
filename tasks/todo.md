# Issue #118 — Moments S2: mutation RPCs

## Status

- [x] `0023_moments_rpcs.sql` — create, append, metadata, tags, reorder, soft-delete media/moment
- [x] Permission matrix + max 8 + one Moment per Push + creator immutability
- [x] `last_activity_at` only on create/append (`clock_timestamp` for same-txn distinguishability)
- [x] `tests/0023_moments_rpcs_verify.sql`
- [x] Applied remotely (plus small fix migrations for PL/pgSQL ambiguity + clock_timestamp)
- [x] Smoke verify on alice/bob (create, append bump, metadata deny, cap 8, soft-delete, empty media)

## Out of scope

Storage, Swift, UI, Realtime, notifications.

## Next

S3 Storage bucket / client media upload.
