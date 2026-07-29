# Feed & Moment Surfaces — Backend Requirements Audit

**Issue:** [#114](https://github.com/kaavlu/Push/issues/114)  
**Date:** 2026-07-28  
**Branch:** `kaavlu/issue-114-audit-feed-moment`  
**Scope:** Read-only inventory of existing Feed / Moment UI and related infrastructure.  
**Non-goals:** No schema design, no migrations, no product rule choices, no code changes.

---

## Executive snapshot

The Feed tab is a **fixture-first UI shell**. Media cards, create-post, and Add Yours are polished presentation flows with local drafts and simulated submit. Nothing in this surface is backed by `FeedRepository`, Storage, or live repos today.

Two separate “feed” concepts already exist in the codebase and must not be conflated:

| Concept | What it is today | Wired to UI? |
|---|---|---|
| **Moment / media feed** (`FeedMediaCarouselData`, Create Post, Add Yours) | Social media-style moment cards (photos/videos, title, place, people) | Yes (fixtures only) |
| **Activity `FeedEvent`** (`arrived`, `becameFree`, `groupForming`, `pushCreated`) | Materialized read model from presence / pushes | No UI; mock seed + empty live |

Live mode uses `EmptyLiveFeedRepository` (empty `events()`). Mock `LocalFeedRepository` returns seeded `FeedEvent`s that the current Feed UI never loads.

---

## 1. Surface inventory

For each surface: **displays**, **actions**, **backend data required**, **stored / inferred / calculated**.

### 1.1 Feed tab shell — `FeedView` / `FeedViewModel`

| | |
|---|---|
| **Displays** | Cream page header “Feed”; `Pushes` / `Now` segment; pinned group filter chips (`All`, `India`, `Michigan`, `Exec` from `FeedFilterFixtures`); tab content. |
| **Actions** | Switch tab; select filter chip (session-persisted `selectedFilterID`). No pull-to-refresh, retry, or load state. |
| **Backend data** | Authenticated viewer; friend **groups** (or other filter dimensions) the viewer can use; filter selection is client preference (session or stored). |
| **Stored / inferred / calculated** | Groups: **stored** (`groups` / memberships). Active filter: **client state** (could stay session-only). |

**Notes:** Filter chips do **not** filter the fixture carousel list today — selection is UI-only. No `LoadState` / `SurfaceContentPhase` on Feed.

---

### 1.2 Feed › Pushes media stack — `FeedPushesMediaStack` + `PushMediaCarousel`

| | |
|---|---|
| **Displays** | Vertical stack of moment cards. Empty stack → `EmptySurfaceView` (“Pushes coming next…”). |
| **Actions** | Per-card (see §1.3). No reorder of cards; no delete/share on the list. |
| **Backend data** | Ordered list of **moments** visible to the viewer (title, location label, date/time label, media items, people, permission flags). Optional **group** association for filter chips. |
| **Stored / inferred / calculated** | Moment + media + membership: **stored**. Date/time **label**: **calculated** from timestamps. Names/avatars: **stored** on profiles, resolved at read. `canAddYours`: **inferred** from policy + membership (see open decisions). Feed order: product rule (open). |

**Source today:** `FeedViewModel.mediaCarousels` defaults to `FeedMediaCarouselFixtures.feedPushesPreviewStack` (7 fixture cards, including loading/missing demos).

---

### 1.3 Feed moment card — `PushMediaCarousel` + `FeedMediaCardContentSection` + bottom chrome

| Field / chrome | Displays |
|---|---|
| Media stack | Ordered photos / video posters; fill-crop; loading / missing placeholders |
| Stories progress | Segment count = media count; fill = autoplay progress (client-only) |
| Bottom-on-media (slide 0) | Participant avatar stack (max 3 + `+N`), names line (`A, B +N`), **contributor name** (secondary line) |
| Cream band | Title; `location · dateTime` meta; optional **+** and **…** when `canAddYours` |

| Actions | Who (UI) | Effect today |
|---|---|---|
| Tap media | Anyone | Pause / resume autoplay (client) |
| Swipe media | Anyone | Change page (client) |
| **+** Add yours | Only if `canAddYours` | Opens `AddYoursView` |
| **…** | Only if `canAddYours` | Opens `CreatePostFlowView` edit-compose for that card |
| Share / delete / report | — | **Not present** |

| Backend requirement | Kind |
|---|---|
| Moment id, title, location text (or place id → label) | Stored |
| Moment time(s) → presentation label | Calculated |
| Ordered media list (kind photo/video, URL, poster, contributor) | Stored |
| People shown in stack / names | Stored membership or tags; presentation slice calculated |
| Current **contributorName** attribution | Stored per media (or inferred: “uploader of focused item”) — UI shows a single string, not per-slide update today |
| `canAddYours` (gates **both** contribute and edit) | Inferred from rules (open) |
| Media load failure | Client; server may still need soft-delete / unavailable flags |

---

### 1.4 Feed › Now tab

| | |
|---|---|
| **Displays** | Always empty: “Nothing live yet” / “Live friend activity will appear here later.” |
| **Actions** | None. |
| **Backend data** | Unclear product intent; closest existing domain is **`FeedEvent`** kinds (`arrived`, `becameFree`, `groupForming`, `pushCreated`) from presence + pushes. |
| **Stored / inferred / calculated** | Events would be **inferred/materialized** from presence, co-location, push creation — not moment media. |

---

### 1.5 Create Post hub — `CreatePostFlowView` / `CreatePostHubView` / `CreatePostViewModel`

Entry: Feed center **+** → `ContentView` `isCreatePostPresented` → hub “Share a moment”.

| | |
|---|---|
| **Displays** | Header + close; segment **Existing Moments** / **Past Pushes** (with **counts**); pinned “Create from scratch”; chooser list or per-segment empty surface. |
| **Actions** | Switch segment; tap create-from-scratch; tap existing moment → edit compose; tap past Push → create compose prefilled; dismiss. |
| **Backend data** | **Existing moments** the viewer may edit/revisit; **historical Pushes** eligible to become moments; friend catalog (scratch path); counts per segment. |
| **Stored / inferred / calculated** | Moments: stored. Past Pushes: stored plans + **lifecycle** (`PushLifecycle.isHistorical`) + “no moment yet” **inferred**. Counts: calculated. |

**Source today:** `CreatePostFixtures.existingMoments` / `.pastPushes` (not `PushRepository.historicalPlans` or hangouts).

---

### 1.6 Hub row — Existing Moment (`PushMomentChooserRow` / `CreatePostChooserRow`)

| Displays | Backend |
|---|---|
| Leading media thumbnail (cover / first renderable) | Stored media; calculated cover = order index 0 |
| Title; date · location | Stored + calculated labels |
| **Contributor** avatar stack (not full membership) | Stored contributions |
| Media count badge | Calculated from media rows |
| Contribution chip: **Open for adds** / **You contributed** | Inferred from flags / viewer contribution |
| Chevron | Navigation only |

**Action:** Tap → compose edit (`CreatePostSource.existingMoment`).

---

### 1.7 Hub row — Past Push (`PushPastPushChooserRow`)

| Displays | Backend |
|---|---|
| Leading **participant** avatar stack (fixed max width, no `+N` text) | Push invitees / attendees (open which) |
| Title; date · location | From `PushPlan` + place/locationText |
| No media thumb, no contribution chip | “No moment yet” is structural |

**Action:** Tap → compose create (`CreatePostSource.pastPush`), prefill title/location/people; empty media.

---

### 1.8 Create from scratch → Select friends — `CreatePostSelectFriendsView`

| | |
|---|---|
| **Displays** | “Who was there?”; search; multi-select friend rows; selected chips; empty friends surface. |
| **Actions** | Toggle friends; search; Next (solo allowed); Back → hub. Also re-entered from compose **With · Edit**. |
| **Backend data** | Current user’s **accepted friends** (profiles: name, avatar). Not groups. |
| **Stored / inferred / calculated** | Friend graph: stored. Selection: draft until publish (stored as moment tags on submit). |

**Source today:** `CreatePostFixtures.selectableFriends` (fixture ids `p-ohm`, …) — not `FriendRepository.friends()`.

---

### 1.9 Create / Edit compose — `CreatePostComposeView`

| Displays | Actions |
|---|---|
| Media stage (PhotosPicker photo/video) | Add media (max **8**), remove focused |
| Reorderable thumb strip; index 0 = **Cover** | Drag reorder (`moveMedia`) |
| Title field (max 80), location field (max 80) | Edit text |
| **With** person list (`PushPersonRow`, no availability) | Edit → friend picker |
| Primary: **Share post** / **Save changes** | Simulated submit → success → dismiss |

| Backend on submit / save | Kind |
|---|---|
| Create or update moment metadata (title, location, time?) | Stored |
| Media blobs + order + cover index | Stored (Storage + rows) |
| Tagged people set | Stored |
| Link to source Push (if from past Push) | Stored optional FK |
| Edit permissions | Inferred (open) |
| Feed append / reorder after create | Calculated feed query |

**Not in UI:** captions, audience picker, delete moment, remove other people’s media, hard failure / retry banner (no `ActionErrorState`).

---

### 1.10 Add Yours — `AddYoursView` / `AddYoursViewModel`

| | |
|---|---|
| **Displays** | Title “Add yours”; fixed subtitle “Share photos and videos”; media stage; thumb strip; primary **Add to push**. |
| **Actions** | Pick up to 8 media; remove; submit (simulated). **No reorder**, no title/location, no people edit. |
| **Backend data** | Target moment (or Push?) id; permission to contribute; append media with **uploader = viewer**. |
| **Stored / inferred / calculated** | New media rows: stored. Order among existing media: product rule (open). |

**Copy tension:** CTA/success say **“push”** (“Add to push”, “Added to push”) while the product surface is a **moment** card on Feed.

**Context today:** only `carousel.id`, location, dateTime — not used beyond subtitle plumbing.

---

### 1.11 Feed center + / map create menu

| Entry | Surface |
|---|---|
| Bottom nav center **+** while Feed tab selected | Create Post hub (not create-action menu) |
| Map create menu | Separate create menu (Start Push / Add Friend / …) — not Moment-specific |

No backend beyond session presentation.

---

### 1.12 Surfaces **not** implemented (called out by issue scope)

| Surface | Status |
|---|---|
| Dedicated Moment **detail** page (fullscreen beyond card) | No separate route; edit is compose; view is the feed card |
| Share sheet / external share | Absent |
| Delete media / delete moment | Only local remove of **draft** items before submit |
| Video **playback** | `FeedMediaKind.video` is poster still only |
| Loading / failed for whole Feed | No network load path; per-media loading/missing only on fixtures |
| Live feed empty vs mock fixtures | Live still shows fixtures if UI is mock-default; live `FeedRepository` is empty and unused by `FeedViewModel` |

---

## 2. Puck and label inventory

“Pucks” here means **avatar stacks / person chrome** on Feed & Moment surfaces (not map friend pucks). Map pucks are out of scope except as reusable avatar components (`PushPersonAvatar`).

### 2.1 Visible person groups

| UI location | Model field | Comment in code / a11y | Appears to mean |
|---|---|---|---|
| Feed card bottom stack + names | `FeedMediaCarouselData.participants` | “People in the Push”; a11y **“Participants”** | Tagged / invited / attending people on the moment (fixture treats as membership list) |
| Feed card secondary name | `contributorName` | “Current media contributor attribution” | **One** display name — not updated per slide; fixtures use a single person |
| Existing-moment chooser stack | `CreatePostHistoryItem.contributors` | “People who contributed media/content” | Subset of members who uploaded |
| Past-Push chooser stack | `participants` | Full list on row | Push people (invitees vs attendees unclear) |
| Compose **With** list | `memberPersonRows` / `participants` | “Everyone present on the original Push” | Editable tags; availability forced `.busy` / empty status (display-only) |
| Create-from-scratch picker | `availableFriends` | Friends catalog | Accepted friends only |

### 2.2 Counts and status labels

| Label | Where | Represents today |
|---|---|---|
| Names `A, B +N` | Feed card | Participant count overflow (`maxNamedInPrimaryLine = 2`) |
| Avatar `+N` | Feed card stack | Participant overflow beyond 3 faces |
| Media count `N` + photo icon | Existing-moment chooser | `mediaItems.count` (photo icon even if videos) |
| Segment counts | Hub Existing / Past | Fixture list lengths |
| Contribution chip **Open for adds** | Existing-moment row | Fixture `CreatePostContributionState.openForAdds` |
| Contribution chip **You contributed** | Existing-moment row | Fixture; wins over open in `resolved(youContributed:openForAdds:)` |
| **Cover** badge | Compose thumb strip | Media index `0` after reorder |
| `N of 8` | Compose / Add Yours | Draft selection vs max |
| Progress segments | Multi-media card | Client autoplay only |
| Date/time strings | Cards / rows | Fixture presentation strings (e.g. `Fri · 9:15 PM`) — not live relative formatting |
| Filter chip titles | Feed | Fixture group names |

### 2.3 Where the UI does **not** clearly distinguish roles

| Role | In UI? | Ambiguity |
|---|---|---|
| **Invitees** | No distinct label | Push domain has `PushResponse` (`.pending` / `.in` / `.maybe` / `.out`); Feed never shows RSVP. Past-Push chooser “participants” could be invitees, `.in` only, or hangout attendees. |
| **Attendees** | No distinct label | Same as above; `PastHangout.participantIDs` is another candidate list. |
| **Contributors** | Partial | Chooser uses `contributors`; feed card stack uses `participants` and a single `contributorName` line — different semantics on adjacent surfaces. |
| **Viewers** | No | No “seen by”, view-only audience, or non-member visibility chrome. |
| **Users allowed to add media** | Partial | Single bool `canAddYours` also unlocks **edit moment** (`…`). Non-participants see neither. Fixtures set `canAddYours: false` on some cards without explaining “view-only friend” vs “stranger”. |
| **Creator / owner** | No | No owner badge; edit allowed for any `canAddYours` viewer in UI. |
| **Current user** | Implicit | “You contributed” chip only on hub rows; feed card does not highlight self in the stack. |

---

## 3. Infrastructure assessment

### 3.1 Reusable today

| Asset | Reuse for Moments |
|---|---|
| `Person` / profiles + `AvatarImageLoader` (bundle / file / HTTPS) | Faces, names, media HTTPS load pattern |
| `FriendRepository.friends()` / search | Scratch tagging, With editor |
| `GroupRepository` + memberships | Feed group filter chips (replace fixtures) |
| `PushPlan` + `PushResponse` + `PushLifecycle` + `PushRepository.historicalPlans` | Past Pushes chooser source of truth |
| `PastHangout` + calendar builders | Alternate “what happened” history (if product ties moments to hangouts, not only pushes) |
| `PushRecipientResolver` / Start Push friend rows | UX patterns for multi-select friends |
| Storage patterns: `avatars` (`0012`), `group-photos` (`0015`) + orphan rollback | Template for a moment-media bucket (not moments themselves) |
| `ProfilePhotoProcessor` style resize/compress | Photo pipeline for uploads |
| `EmptySurface*` / `ActionErrorBanner` / `LoadState` patterns | Real load/empty/failed/mutation errors (not wired on Feed yet) |
| `SharingPolicy` | **Not** moment privacy as-is (location/activity/availability only) — reuse *idea* of audience tiers, not columns |
| `AppDataContainer` repo injection + `onStoreChange` | Session refresh when moments exist |
| Design system: `PushMomentChooserRow`, `PushContributionChip`, cream cards, carousel chrome | Presentation stays; bind to real models |

### 3.2 Existing but **not** the Moment product

| Asset | Gap |
|---|---|
| `FeedEvent` + `FeedRepository.events()` | Activity/social-signal feed, **not** media moments; kinds don’t include media/contribution |
| `EmptyLiveFeedRepository` | Correct empty for Day-1; no moment API |
| Seed `feedEvents` | Mock-only; unused by `FeedView` |
| `PushPlan.note` / `locationText` | Coordination fields; not moment title/media gallery |

### 3.3 Missing backend concepts (no schema proposed)

1. **Moment** (or equivalent social post entity): identity, title, location, time, creator, optional `push_id`, lifecycle (open/closed/deleted).  
2. **Moment membership / tags** (people “With”).  
3. **Moment media** items: order, kind, storage path, poster, uploader, created_at; cover = order or flag.  
4. **Contribution / edit permissions** (who may add media, who may edit metadata, who may remove whose media).  
5. **Viewer capabilities** projected to clients (`canAddYours`, `canEdit`, `canDelete`, …) instead of a single bool.  
6. **Feed projection** query: who sees which moments, ordering, group filter.  
7. **Media Storage bucket** + RLS + upload/delete RPCs.  
8. **Moment ↔ Push** and optionally ↔ hangout linkage rules.  
9. **Per-media contributor** for carousel attribution (if multi-uploader).  
10. **Realtime / notifications** for new moments and contributions (none today for feed).  
11. **Captions / audience / share** if product wants them (UI absent).  

### 3.4 Mock-only behavior

- All Feed Pushes cards (`FeedMediaCarouselFixtures`).  
- Hub lists (`CreatePostFixtures`).  
- Friend picker catalog (`CreatePostFixtures.selectableFriends`).  
- Filter chips (`FeedFilterFixtures`) — not live groups.  
- Add Yours / Create Post **submit** = delay → success; **no** feed mutation, upload, or error path.  
- Edit-from-feed synthesizes `CreatePostHistoryItem.fromFeedCarousel` (contributors = all participants, chip = youContributed) when id not in fixture moments.  
- Video = still frame; no upload bytes for video drafts.  
- `LocalFeedRepository.events()` unused by Feed UI.  

### 3.5 Conflicting or ambiguous behavior across surfaces

| Conflict | Detail |
|---|---|
| **Two feeds** | Media moments UI vs unused `FeedEvent` activity model vs empty **Now** tab |
| **Participants vs contributors** | Card stack = participants; chooser stack = contributors; feed secondary line = single contributorName |
| **canAddYours dual use** | Same flag for contribute (+) and edit (…) |
| **Push vs moment language** | Add Yours: “Add to **push**”; Create Post: “Share a **moment**” / “Posted” |
| **Past Push eligibility** | Fixtures are hand-built; real historical pushes, hangouts, and “already has moment” are undefined together |
| **ID namespaces** | Fixture carousel ids (`fixture-three-bundle`) vs moment ids (`moment-fixture-three-bundle`) vs past push ids (`past-push-park`) vs seed person ids (`ohm` vs `p-ohm`) |
| **Design doc vs code chips** | Design mentioned a “Posted” contribution state; code only has `openForAdds` / `youContributed` |
| **Docs drift** | `AGENTS.md` still describes location pill + overflow **on media**; implemented cream band under media for title/meta/actions |
| **Filter no-op** | Selected group chip does not filter carousels |
| **Permissions UI-only** | Hiding + / … is presentation-only; no server enforcement possible yet |

### 3.6 Permissions currently enforced only by the UI

- Showing **+** / **…** (`canAddYours`).  
- Max **8** media client-side.  
- Title/location length caps.  
- Solo moments allowed (empty With).  
- Anyone in compose can remove any draft media (local only).  
- Edit compose reachable only via UI path (fixture participant or overflow).  
- No block/ghost/sharing-policy checks on moment visibility.  

---

## 4. Open product decisions

Do **not** answer here — list only. Avoid questions already resolved by code inspection.

### Moment lifecycle

1. What is the canonical object: **Moment** distinct from Push, or a media gallery attached to a Push?  
2. Can a moment exist with **no** source Push (scratch)?  
3. Can multiple moments attach to one Push?  
4. When does a moment become **closed** to new media (if ever)? Who closes it?  
5. Who can **edit** title/location/people after publish? Creator only, any contributor, any participant?  
6. Who can **delete** a moment or individual media items (own only vs any)?  
7. Is **cover** always media order index 0, or an explicit pin?  
8. Soft-delete vs hard-delete for media and moments?  
9. Do edits create versions / history, or overwrite in place?

### Attendance

10. Who appears in the feed card **participant** stack: invitees, RSVP `.in`, tagged “With”, or media contributors?  
11. For past-Push → moment, default people set: all invitees, `.in` only, or hangout participants?  
12. Can tagged people include non-friends? Non-invitees of the source Push?  
13. Does tagging someone grant them feed visibility and/or add-media rights?  
14. How do blocks interact with tags and visibility (soft-hide like other social surfaces)?

### Media permissions

15. Who may **Add yours**: participants only, contributors-open flag, friends of creator, group members?  
16. Should contribute and **edit metadata** be separate permissions (today one `canAddYours`)?  
17. Max media per moment (UI uses 8) — hard product limit? Per-user contribution cap?  
18. Video: poster-only forever, or full playback + size limits?  
19. Where do new Add-yours items insert (append, prepend, after cover)?  
20. Can contributor A remove contributor B’s media?

### Puck / label semantics

21. What should the feed secondary line show: uploader of **current** slide, original poster, or “N contributors”?  
22. Should chooser stacks stay **contributors-only** while the card shows **participants**?  
23. Do we need distinct visual treatment for invitee / attendee / contributor / viewer?  
24. Should “You contributed” / “Open for adds” be the only chips, or is “Posted” / “Closed” required?

### Visibility and privacy

25. Who can **see** a moment on Feed: participants, mutual friends, group, everyone on Push?  
26. How do group filter chips scope the feed (membership vs moment.group_id)?  
27. Interaction with existing **sharing policies** / Ghost / blocks?  
28. Are moments visible when the linked Push was invitees-only vs group audience?  
29. External **share** (system share sheet, links) — in or out of product?

### Feed ordering and realtime

30. Default Feed › **Pushes** sort: newest moment, newest media activity, or Push start time?  
31. Does contributing media bump a moment to the top?  
32. Pagination / retention window?  
33. Should Feed use `LoadState` + pull-to-refresh like Friends/Plans?  
34. Realtime updates for new moments/media, or refresh-only?  
35. What is Feed › **Now** for relative to Pushes moments and relative to `FeedEvent`?

### Notifications

36. Notify participants when a moment is created from a Push?  
37. Notify on Add yours / edit / tag?  
38. Mute / per-moment notification controls?

### Edge cases

39. Source Push **cancelled** or deleted after a moment exists?  
40. Historical push with **zero** responses / only creator?  
41. Friend removed or user blocked after tagging?  
42. Empty media moment allowed to publish? (UI requires ≥1 media to submit.)  
43. Solo moment (no tags) visibility?  
44. Concurrent Add yours from two users — merge order?  
45. Failed upload partial batch — keep successful items or roll back?  
46. Relationship between **PastHangout** calendar rows and moment creation (same event or separate)?  
47. Live mode: hide fixture carousels and show true empty until backend ships?

---

## 5. Traceability (primary code map)

| Area | Primary files |
|---|---|
| Feed shell | `Push/FeedView.swift`, `FeedViewModel.swift`, `FeedModels.swift`, `FeedStyle.swift` |
| Media card | `Push/PushMediaCarousel.swift`, `PushMediaCarouselBottom.swift`, `FeedMediaPageStrip.swift`, `FeedMediaCardContentSection.swift`, `FeedMediaModels.swift` |
| Create post | `Push/CreatePost*.swift`, `DesignSystem/.../PushMomentChooserRow.swift`, `PushContributionChip.swift` |
| Add yours | `Push/AddYours*.swift` |
| Entry | `Push/ContentView.swift` (Feed tab + create post cover) |
| Domain / repos | `Push/Data/Domain/FeedEvent.swift`, `Repositories.swift` (`FeedRepository`), `LocalRepositories.swift`, `EmptyLiveRepositories.swift`, `SeedData+History.swift` |
| Related coordination | `PushPlan.swift`, `PushResponse.swift`, `PastHangout.swift`, `PushLifecycle.swift` |
| Prior UI design | `docs/superpowers/specs/2026-07-28-feed-create-post-design.md` |

---

## 6. Acceptance checklist (this audit)

- [x] Every Feed / Moment surface inventoried  
- [x] Visible pucks, labels, counts, actions mapped to backend needs  
- [x] Reusable infrastructure vs missing concepts called out  
- [x] Ambiguous product behavior listed as open questions (ungrouped answers not invented)  
- [x] No implementation, migrations, or schema design included  

---

## Suggested next issue (out of scope here)

A product-decision workshop against §4, then a separate design spec for Moment domain + Feed projection (still before migrations).
