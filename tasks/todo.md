# Issue #116 — Design Feed and Moment backend architecture

## Status

- [x] Infrastructure reuse audit
- [x] Domain model + DB relationship sketch
- [x] Storage / AuthZ / read-write flows
- [x] Edge cases (graph, tags, blocks, soft-delete, concurrency, order)
- [x] Migration sequence, RLS checklist, tests, implementation slices
- [x] Non-goals preserved from product contract

## Deliverable

`docs/superpowers/specs/2026-07-28-feed-moment-backend-architecture.md`

## Inputs

- Contract: `docs/superpowers/specs/2026-07-28-feed-moment-product-contract.md` (#115)
- Audit: `docs/superpowers/specs/2026-07-28-feed-moment-backend-requirements-audit.md` (#114)

## Constraints honored

- Architecture only — no code, migrations, or Storage setup
- Product decisions unchanged
- Moment ≠ Push ≠ FeedEvent

## Next

Implementation issues for slices S1–S5 (backend) then S6–S9 (client wire-up).
