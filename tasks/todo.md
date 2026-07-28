# Issue #9 — Feed shell

## Status

- [x] Clarifying design questions (user answers)
- [x] Spec (`tasks/spec.md`)
- [x] FeedModels / FeedViewModel / FeedStyle / FeedView
- [x] Wire ContentView (replace deferred; + no-op on Feed)
- [x] EmptySurface copy for Pushes/Now placeholders
- [x] Optional filter-chip counts (title-only Feed fixtures)
- [x] Remove `FeedDeferredView`
- [x] Register Xcode sources + `FeedViewModelTests`
- [x] Build + tests green
- [x] Commit

## Decisions

| Topic | Choice |
|---|---|
| Subtitle | None |
| Header actions | `PushCircleIconButton` glass circles |
| Segment while scrolling | Pinned under header |
| Filter chips while scrolling | Scroll with content |
| Center `+` on Feed | No-op |
