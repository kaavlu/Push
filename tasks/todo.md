# Issue #83 — Audit and Standardize Confirmation Popups

## Status

- [x] Audit system `confirmationDialog` / `.alert` inventory
- [x] Design approved (centered cream card, destructive-only migration)
- [x] Spec: `docs/superpowers/specs/2026-07-24-confirmation-dialogs-design.md`
- [x] DS-090 decision + catalog updates
- [x] `PushConfirmationDialog` + `.pushConfirmation` (+ window bridge)
- [x] Migrate destructive call sites
- [x] Register new files in Xcode project
- [x] Build + `PushConfirmationTests` (4/4 passed)
- [ ] Commit / open PR when ready

## Migrated

Profile sign out / delete account; ExpandablePersonRow remove/block; Blocked unblock; Group leave/delete/transfer; Group remove member / cancel invite; Start Push delete; Plans cancel push.

## Intentionally system

Photo choose/remove menus; photo/connector info alerts; Menu / contextMenu; PhotosPicker / OS permissions.
