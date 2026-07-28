# Add Yours — contribution UI pass (Issue #9)

## Goal

Ship a polished **Add Yours** full-screen page opened from a Push card media CTA. The flow is a **lightweight media contribution** to an existing Push — not a new Push creator.

**This pass:** fixture + local PhotosPicker state only. No uploads, Storage, repos, or feed mutation.

## Product decisions (agreed)

| Topic | Choice |
|---|---|
| Structure | **Single screen** (no step indicator) |
| Media | **Photos + videos, multi-select** |
| Preview | **Large hero + horizontal thumb strip** (focus, remove, add more) |
| Caption | **None in v1** |
| Submit | **Post → brief success → auto-dismiss** (simulated; no backend) |
| Surface | `PushModalBackground` (enter → complete → exit), Start Push chrome language |
| Primary CTA | `PushSolidSunbeamButton` — “Add to push” |
| Close | Trailing `PushCircleIconButton` (x) |

## Visual / interaction

- **Chrome:** modal gradient, close top-trailing (Start Push / modal-flow family). No numbered step dots.
- **Header:** title **Add yours**; subtitle uses push location (and optional date line) from the launching card.
- **Empty:** glass dashed pick surface + multi `PhotosPicker` (images + videos).
- **With media:** feed-like portrait hero (`FeedMediaLayout.aspectRatio` / corner language), fill-crop; video badge when kind is video; thumb strip for switch/remove; trailing **+** to add more until max.
- **Submit:** disabled with zero items; on tap → short submitting state → success checkmark moment → dismiss.
- **Out of scope:** captions, reorder, camera capture, crop/edit tools, real upload, feed append, offline queue.

## Architecture

| Piece | Role |
|---|---|
| `AddYoursContext` | Launch payload from a Feed carousel (`id`, location, date label) |
| `AddYoursDraftItem` | Local draft media (kind + optional `UIImage` preview) |
| `AddYoursViewModel` | Picker load, focus/remove, max count, submit phase machine |
| `AddYoursView` | Dumb presentation; dismiss on success |
| `AddYoursLayout` | Spacing / hero / thumb tokens |
| Feed wiring | `PushMediaCarousel.onAddYours` → `fullScreenCover` |

## Acceptance

- [ ] Open from Feed **Add yours** as full-screen modal
- [ ] Empty → pick multi photo/video; hero + strip when selected
- [ ] Remove / re-focus / add more up to max
- [ ] Primary enabled only with ≥1 item; success then dismiss
- [ ] Design-system surfaces/buttons only; no captions
- [ ] No backend / no feed mutation
- [ ] Unit tests for selection + submit phase (injectable timing)
