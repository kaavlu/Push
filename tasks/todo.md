# Issue #127 — Moments S8: connect Add Yours to Moment media append

## Status

- [x] `AddYoursContext` carries the Moment identity only; the screen loads its
      album, capabilities, and capacity from `MomentRepository.moment(id:)`
      (Feed cards are a launch hint, never live state)
- [x] Affordance shaped by `MomentCapabilities.canAddMedia` (denied surface for a
      stale card) and by `MomentLimits.maxActiveMedia` minus the viewer-visible
      album (full surface at capacity)
- [x] Picker uses `CreatePostMediaLoader`, so drafts carry `MomentMediaUpload`
      bytes; selection clamps to the remaining slots
- [x] Append is per item: `MomentMediaPublisher.append(useMomentFolder: true)`
      (upload under `{moment_id}/…`, migration 0024) → `appendMedia` with a
      single draft → object rollback only for the item whose RPC failed
- [x] Partial success: committed drafts leave the composer, the remainder stays
      for Retry, and the banner states what landed
- [x] Refresh after success *and* partial success: detail reloads, mock store
      revision reloads Feed, live `appendMedia` now calls
      `LiveDataStore.notifyMomentsChanged()` (including after a partial batch)
- [x] Load states: loading / failed+retry / denied / full (DS-070/071);
      `ActionErrorBanner` for recoverable append failures
- [x] ViewModel split (`AddYoursViewModel`, `+Append`) to stay inside the
      file-size rule; preview seam is a fixture `MomentDetail` with no repository
- [x] Tests: `AddYoursAppendTests` (11), `AddYoursPartialAppendTests` (7),
      updated `AddYoursViewModelTests` — `scripts/test.sh full` green (815)

## Out of scope (S9)

Metadata/tag editing on an existing Moment, media reorder, media/self-tag/Moment
deletion, Realtime, notifications, Feed › Now.

## Notes

- Per-item `appendMedia` calls (one draft each) are what make partial success
  work: the RPC commits per item, so batching would blur which object to roll back.
- Server cap rejection mid-batch is treated as an ordinary recoverable error —
  the local capacity check is a pre-flight, not authorization.
- Not visually verified in the simulator this session; build + full suite are
  the evidence.

## Next

S9 — existing-Moment metadata/tag edit, reorder, and deletion.
