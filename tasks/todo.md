# Issue #9 — Feed media carousel foundation (Prompt 1 of 4)

## Status

- [x] Spec (`tasks/spec.md`)
- [x] `FeedMediaModels` + fixtures (mixed aspects, single, missing, loading, video poster)
- [x] `FeedMediaLayout` / progress tokens in `FeedStyle`
- [x] `PushMediaCarousel` (fixed 3:4 frame, fill-crop, paging, progress)
- [x] Wire Pushes tab media stack in `FeedView` / `FeedViewModel`
- [x] Register Xcode sources + `FeedMediaCarouselTests`
- [x] Build + tests green
- [x] Commit

## Decisions

| Topic | Choice |
|---|---|
| Aspect ratio | 3:4 portrait (stable frame) |
| Corners | `PushRadiusTokens.card(layout)` |
| Progress | Stories-style thin white segments; update on swipe |
| Data | Fixtures only — no repo |

## Out of scope (later prompts)

Auto-advance, timed progress, video playback, metadata, avatars, CTAs, backend.
