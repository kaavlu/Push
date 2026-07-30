# Issue #128 — Moments S9: connect Moment editing and deletion

## Status

- [x] Existing-Moment edit loads `MomentDetail` (hub + Feed …); carousel/hub rows are launch hints only
- [x] UI shaped by server `MomentCapabilities` (metadata / tags / reorder / media delete / leave / delete)
- [x] Save diffs call `updateMetadata`, `addTags` / `removeTag`, `reorderMedia`, `softDeleteMedia`
- [x] Creator delete + non-creator leave use `.pushActionMenu` + `.pushConfirmation` (DS-090)
- [x] Recoverable errors keep the draft; conflict reloads detail without dropping the banner
- [x] Live mutations notify via `LiveDataStore.notifyMomentsChanged()` so Feed/hub refresh
- [x] Tests: `CreatePostEditTests` (13) + existing Create Post suites green

## Out of scope

Realtime, notifications, append-on-edit (Add Yours), schema/RPC redesign, Feed › Now, visual redesign.

## Notes

- Append stays on Add Yours; edit compose never picks new media on the repository path.
- Media soft-delete is staged locally and committed on Save (with reorder after deletes).
- Last-media delete may soft-delete the Moment; the flow dismisses cleanly.

## Next

Close #128 / open PR when ready.
