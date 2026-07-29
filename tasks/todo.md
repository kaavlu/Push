# Issue #125 — Moments S6: wire Feed reads to MomentRepository

## Status

- [x] `MomentSummary` carries the viewer-visible album (`media`); `coverMedia` computed
      (both `LocalMomentRepository` and the `0026` DTO already had the filtered list)
- [x] `MomentFeedCardBuilder` — `MomentSummary` → `FeedMediaCarouselData`
- [x] `FeedViewModel` repository-backed: `LoadState`/`contentPhase`, keyset pagination,
      pull-to-refresh, retry, group chips from the viewer's groups (`MomentFeedFilter`)
- [x] `FeedView` — shared surface states, `.refreshable`, last-card pagination trigger,
      `ActionErrorBanner` for incremental failures
- [x] Fixtures demoted to the `FeedViewModel(carousels:)` preview seam
- [x] Tests: `FeedViewModelTests` (19), `MomentFeedCardBuilderTests` (9),
      mock/live card parity, live fixture isolation — `scripts/test.sh full` green (776)

## Out of scope (S7–S9)

Create Post publish, Add Yours upload/append, metadata/tag edit, reorder, self-removal,
deletion, Feed › Now / `FeedEvent`, Realtime, schema/RPC changes, UI redesign.

## Notes

- Feed cards are swipeable, so a feed row needs the whole viewer-visible album, not just
  the cover — hence the `MomentSummary.media` change rather than an N+1 detail fetch.
- Tagged ids without a cached `Person` are dropped from the participant stack (same rule
  as `GroupContentBuilder`); viewer-visible counts still come from the repository.
- Not visually verified in the simulator this session (Simulator window was not
  accessible for UI driving); build + full suite are the evidence.

## Next

S7 — Create Post publish + past-Push eligibility + one-Moment-per-Push.
