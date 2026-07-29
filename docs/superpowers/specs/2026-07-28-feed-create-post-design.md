# Feed Create Post — Design (UI pass)

**Date:** 2026-07-28  
**Issue:** #9 Feed (create from center +)  
**Scope:** Fixture / local draft only — no backend, Storage, or feed mutation.

## Goal

Feed tab center `+` opens a polished create-post flow so users can:

1. Browse past Pushes and pick one to turn into a post  
2. Create a new post from scratch  

## Product decisions

| Area | Decision |
|---|---|
| Structure | **A — Single hub + compose** full-screen modal |
| History | Compact richer History rows (media thumb, title, date · location, people, media badge, chevron) — flat newest-first |
| Selection | Tap row → open compose prefilled (no multi-select, no preview sheet) |
| From scratch | Friend multi-select (Start Push style, friends only, solo allowed) → compose shell |
| Submit | Simulated success → dismiss whole flow |
| Data | Local fixtures (same spirit as `FeedMediaCarouselFixtures`) |

## Screens

### Hub — “Share a moment”
- `PushModalBackground`
- Header: `PushCreamPageHeader` (Pushes page type stack) + trailing close `X` aligned in the same HStack
- Pinned **Create from scratch** solid-cream row (sunbeam +, chevron)
- **`PushIvorySegmentedControl`** (Feed Pushes/Now style):
  1. **Existing Moments** (default) — moments already created; media thumb, people, location/date, contribution chip (`Open for adds` / `You contributed` / `Posted`); tap → compose edit
  2. **Past Pushes** — completed Pushes without a moment; **no media thumbs**; leading participant stack, title, date · location, “Push” context + people count; tap → compose create from Push
- Segment switches filter the list only (flat newest-first within each)
- Empty states per segment via `EmptySurfaceView` (icon + title + message, no CTA); create-from-scratch always available
- Row chrome: design-system choosers (DS-091) on `pushSolidCreamCard` + Friends list density

### Select friends — scratch only
- Opens from **Create from scratch** before compose
- Start Push step-1 language: search, cream multi-select rows, selected chips, `PushSolidSunbeamButton` “Next”
- Friends only (no groups)
- Selection optional — Next enabled with zero friends (solo moment)
- Back → hub; close → dismiss flow
- Fixture friend catalog (`CreatePostFixtures.selectableFriends`)

### Compose — shared shell
- Back: scratch → friend selection (keeps media/title draft); existing/past → hub
- Close → dismiss flow
- Media stage (reuse Add Yours patterns: PhotosPicker, hero, thumbs)
- Title + location text fields (UI only)
- Past Push / existing moment: prefill media (when any), title, location; participants display-only
- From scratch: empty media + fields; “With” reflects selected friends (if any)
- **With** section always shown on compose; trailing **Edit** text link opens friend picker (preselected current tags; Done applies, Back cancels) so people can add friends to existing moments / past Pushes / scratch drafts
- Primary `PushSolidSunbeamButton`: “Share post” for scratch / past Push; “Save changes” when editing an existing moment (≥1 media)
- Simulated submit → success → dismiss

## Out of scope

Publishing, repos, feed append, captions, audience, Start Push handoff, Realtime.
