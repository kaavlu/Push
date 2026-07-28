# Issue #9 — Feed media carousel foundation (Prompt 1 of 4)

## Goal

Ship a polished, reusable media carousel container for Push cards on the Feed Pushes tab: fixed portrait frame, fill-crop media, manual paging, segmented progress, and media-state fixtures. No card chrome beyond the media surface.

## Decisions (this step)

| Topic | Choice |
|---|---|
| Aspect ratio | Compact portrait **0.86** width÷height (band 0.84–0.88); next card peeks |
| Corner radius | Fixed **30pt** continuous rounded rectangle (28–32 band) |
| Group filters | Pinned under segment control (do not scroll away with content) |
| Margins | Existing `FeedLayout.horizontalPadding` (page padding) |
| Progress | Thin Stories-style segments at top inset; update on manual swipe |
| Media crop | `scaledToFill` clipped to rounded frame — no frame resize across items |
| Video | Kind exists for fixtures; still poster only (no playback) |
| Data | DEBUG/fixture local media only — no repo / backend |

## Scope

- Reusable `PushMediaCarousel` presentation component
- Feed media models + fixture samples
- Pushes tab renders a vertical stack of fixture carousels
- States: multi-photo, single photo, mixed aspect sources, missing, loading
- Manual horizontal swipe + page snap + progress selection

## Out of scope

Auto-advance, timed progress fill, video playback/controls, title/venue/time, badge, overflow menu, avatars/names, contributor attribution, Add yours, contribution footer, Open Push, uploads, backend, navigation.

## Architecture

- **Models:** `FeedMediaItem` / `FeedMediaCarouselData` + `FeedMediaCarouselFixtures` (isolated fixtures, not seed/repo)
- **View:** `PushMediaCarousel` — local `@State` selected index; Views remain dumb beyond swipe state
- **Layout:** `FeedMediaLayout` tokens in `FeedStyle.swift`
- **FeedView:** Pushes tab stacks carousels; Now tab unchanged empty state
- **MVVM:** `FeedViewModel` may expose fixture list for previews/tests; no `LoadState`/repo yet

## Acceptance

- [ ] Large portrait media cards with consistent page margins and rounded corners
- [ ] Fixed aspect; switching items does not resize the card
- [ ] Media fill-crops; clipped during swipe; no horizontal overflow
- [ ] Segment progress: one per item; current / completed / remaining distinct
- [ ] Manual swipe + snap updates selected segment
- [ ] One-item, missing, and loading fixtures look polished
- [ ] Previews cover three mixed-aspect photos, single, mixed, missing, loading
- [ ] No metadata, buttons, avatars, or navigation chrome

## Test stubs

- `testMediaAspectRatioIsPortraitStable`
- `testFixturesCoverRequiredCarouselStates`
- `testSelectedIndexClampsToItemBounds`
- `testProgressSegmentCountMatchesItems`
