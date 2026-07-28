# Issue #9 — Feed shell (structural)

## Goal

Ship the first structural Feed surface: entry from bottom nav, header actions, Pushes/Now segmented control, friend/group filter chips, and polished placeholders. No Push cards, carousel, ranking, or live feed data.

## Confirmed product decisions

| Topic | Decision |
|---|---|
| Subtitle | None for now (title only) |
| Header actions | `PushCircleIconButton` glass circles for filter/settings + alerts |
| Segment control while scrolling | Pinned under header |
| Filter chip row while scrolling | Scrolls away with content |
| Center `+` on Feed | No-op for this issue (visible, does nothing) |

## Scope

- Replace deferred empty shell (`FeedDeferredView`) with a real Feed page structure
- Title: **Feed**
- Trailing: filter/settings (no-op for now) + alerts (opens existing Alerts; unread badge)
- Segmented control: **Pushes** (default, first) · **Now**
- Horizontally scrollable filter chips (fixture: All, India, Michigan, Exec)
- Filter selection persists across tab switches in-session
- Pushes tab: lightweight placeholder (“coming next”)
- Now tab: polished empty state (title + one sentence)
- Cream Friends-page treatment; shared bottom nav; scroll-safe bottom clearance
- Contextual `+` on Feed: no-op

## Out of scope

Push cards, media carousel, detail, creation, uploads, backend feed events, ranking, Who’s Down / live activity / inference feed.

## Architecture

- **MVVM:** `FeedViewModel` owns selected tab + selected filter
- **View:** `FeedView` render-only; cream page via existing DS components
- **Models:** `FeedTab`, fixture filter items (not seed/repo)
- **Fixtures only** for filter labels — no `FeedRepository` wiring this issue
- **Navigation:** still embedded under `ContentView` tab overlay (not fullScreenCover)
- Reuse: `PushCreamPageHeader`, `PushIvorySegmentedControl`, `PushIvoryFilterChipRow`, `PushCircleIconButton`, `EmptySurfaceView` / `EmptySurfaceCopy`, `FriendsBackground` / `FriendsLayout` spacing where shared

## Acceptance

- Feed reachable from bottom nav
- Pushes first and default-selected
- Now shows polished empty state
- Header actions render; alerts badge when unread
- Filters horizontal-scroll; selection visually clear and tab-persistent
- Fits existing Push cream UI; no Push card/carousel behavior
- Center `+` on Feed is a no-op
