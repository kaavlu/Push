# Feed Create Post + Add Yours — UI pass (Issue #9)

## Goal

Ship polished Feed moment UI: media cards with cream content band, **Add Yours** contribution from participant cards, and **Share a Moment** create/edit flow from Feed center `+` / card `…`.

**This pass:** fixture + local PhotosPicker / draft state only. No uploads, Storage, repos, or feed mutation.

## Product decisions

| Topic | Choice |
|---|---|
| Create structure | Single hub + compose (`CreatePostFlowView`) |
| Add Yours | Single-screen media contribution to an existing moment |
| Media | Photos + videos, multi-select |
| Submit | Simulated success → dismiss (no backend) |
| Participant actions | `+` / `…` only when `canAddYours` |
| Card `…` | Opens edit-moment compose for that card |

## Architecture

| Piece | Role |
|---|---|
| `PushMediaCarousel` + `FeedMediaCardContentSection` | Media + cream title/meta band |
| `AddYoursView` / `AddYoursViewModel` | Contribution draft + submit |
| `CreatePostFlowView` / `CreatePostViewModel` | Hub → friends → compose; edit from feed |
| Feed wiring | Center `+` create post; card `+` Add Yours; card `…` edit moment |

## Acceptance

- [x] Feed Pushes media stack with title/meta content band
- [x] Participant-only `+` / `…`; non-participants see neither
- [x] Add Yours modal from `+`
- [x] Edit moment compose from `…`
- [x] Create post hub from tab `+`
- [x] Unit tests for create post / feed media / Add Yours / feed shell
- [ ] No backend / no feed mutation (intentional)

## Out of scope

Publishing, Storage, live history, audience, Now tab content, filter chip → real groups.
