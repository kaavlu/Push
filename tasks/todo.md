# Issue #126 — Moments S7: connect Create Post to live Moment publishing

## Status

- [x] Hub reads repositories: `MomentRepository.hubMoments()` → Existing Moments,
      `PushRepository.historicalPlans` (current + previous month) → Past Pushes,
      friend catalog from `FriendRepository` (real `Person.ID`s as tag ids)
- [x] `CreatePostHubBuilder` — `MomentSummary` → chooser row (contributors =
      distinct visible uploaders; chip from capabilities); `PushPlan` → past-Push
      row (prefill = `response == .in` minus self and unknown ids)
- [x] One-Moment-per-Push: rows exclude Push slots the viewer can see consumed;
      a Moment the viewer can't see leaves the row listed and the RPC rejects the
      publish (`momentExistsForPush`) — client filtering is a hint, not authorization
- [x] Media drafts carry `MomentMediaUpload` bytes (`CreatePostMediaLoader`:
      photos re-encoded to JPEG, videos keep mp4/quicktime, poster deferred)
- [x] Publish = `MomentMediaPublisher.publishPending` (upload → `createMoment` →
      orphan rollback) with local pre-flight validation
- [x] States: hub loading/failed/empty (DS-070), submitting/success, recoverable
      `ActionErrorBanner` on compose with Retry; duplicate submit blocked
- [x] Refresh after publish: mock via store revision, live via
      `LiveDataStore.notifyMomentsChanged()` (Feed + hub reload)
- [x] `AppDataContainer.momentMedia` seam (mock local files / live bucket / nil
      for loader-only live containers)
- [x] ViewModel split by responsibility (`+Hub`, `+Friends`, `+Presentation`,
      `+Publish`) to stay inside the file-size rule
- [x] Tests: `CreatePostPublishTests` (16), `CreatePostHubBuilderTests` (5),
      live-container isolation for `momentMedia` — `scripts/test.sh full` green (799)

## Out of scope (S8–S9)

Add Yours / media append, existing-Moment metadata + tag editing (that compose
path deliberately still ends in a local success), reorder, self-removal,
deletion, Realtime, notifications, Feed › Now.

## Notes

- Fixtures survive only behind `CreatePostViewModel(existingMoments:…)`, the
  preview seam — no app path can reach them.
- Feed card ids are Moment ids since S6, so `feedMomentID(forCarouselID:)` was
  dropped rather than double-prefixing edit-from-feed deep links.
- Not visually verified in the simulator this session; build + full suite are
  the evidence.

## Next

S8 — existing-Moment metadata/tag edit + Add Yours append.
