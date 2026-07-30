# Issue #137 — Almost Happened Removal

## Status

- [x] Remove `almostHappened` from `CalendarDayData` and all calendar UI
- [x] Remove `didHappen` from `PastHangout` / `HistoryItemData` (domain only existed for this surface)
- [x] Strip "Almost happened" copy from day detail sheet + history rows
- [x] Remove seed almost-hangouts (days 14/25) and builder branching
- [x] Update derivation / lifecycle tests

## Out of scope

- Historical design snapshots under `Design/CoreDesignFiles/` (read-only)
- Historical specs/plans under `docs/superpowers/`

## Notes

- Hangouts are recorded facts that happened; no partial/failed hangout state.
- Calendar day detail opens only when `pushCount > 0`.
- History link still keys off real hangouts / week push totals.
