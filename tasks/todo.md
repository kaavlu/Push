# Issue #52 — Block / Unblock

- [x] Design + plan
- [x] Migration `0016_user_blocks` (renumbered after main's 0013–0015)
- [x] Mock store + FriendRepository
- [x] Live RPC path
- [x] Friends Block UI
- [x] Soft-hide / pickers
- [x] Profile Blocked list
- [ ] Apply migration on remote (if not done)
- [ ] Live smoke: block friend, search empty, unblock, re-request

## Verification
- [x] `scripts/test.sh suite BlockUserTests`
- [x] `scripts/test.sh suite DataLayerTests`
- [x] `scripts/test.sh suite LiveDataStoreTests`
- [x] `scripts/test.sh suite AlertsTests`
- [x] `scripts/test.sh build`

---

# Issue #56 — Create a Comprehensive Project README

**Issue:** https://github.com/kaavlu/Push/issues/56

## Status

- [x] Inspect codebase, setup scripts, Supabase docs, MVP product doc
- [x] Capture fresh simulator screenshots (map, friends, pushes, profile, alerts, onboarding)
- [x] Write root `README.md`
- [x] DEBUG launch args for screenshot targets (`--plans`, `--profile`, `--alerts`)
- [x] Verify `scripts/test.sh build` and document verified setup steps
- [ ] Open PR / close issue

## Acceptance criteria check

- [x] New developer can understand and run Push from the README
- [x] Setup steps verified (`run-ios-sim.sh`, `test.sh build`)
- [x] Screenshots reflect current mock UI
- [x] Implemented / partial / planned clearly separated
- [x] No secrets, service-role keys, or machine-local paths
- [x] No placeholder boilerplate in README
