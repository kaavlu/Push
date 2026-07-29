# Feed & Moment — Product Contract (MVP)

**Issue:** [#115](https://github.com/kaavlu/Push/issues/115)  
**Based on audit:** [#114](https://github.com/kaavlu/Push/issues/114) · `2026-07-28-feed-moment-backend-requirements-audit.md`  
**Date:** 2026-07-28  
**Status:** Product rules resolved via structured interview. **No implementation in this issue.**

Security-sensitive permissions in this document must be **enforced by the backend**, not only the UI.

---

## 1. Defined terminology

| Term | Meaning (MVP) |
|---|---|
| **Moment** | A social media album on Feed: title, frozen location text, ordered media, tagged people, optional link to one Push. Distinct from a coordination **Push**. |
| **Push** | Existing coordination object (`PushPlan` + responses). May **optionally** seed one Moment after it is historical. |
| **Creator** | User who first successfully published the Moment. Immutable for MVP. Always remains a tagged member. |
| **Tagged member** | Explicit person on the Moment’s **With** list. Primary membership for contribution rights. |
| **Media contributor** | User who has successfully uploaded ≥1 non-deleted media item on the Moment. Derived, not a separate invite state. |
| **Viewer** | Any user who can currently see the Moment under visibility rules (may not be tagged). |
| **Invited** | Push invitee (via audience / responses). **Not** a Moment role unless copied into tags at create. |
| **Responded** | Push `PushResponse` (`.in` / `.maybe` / `.out` / `.pending`). Used only to **prefill** past-Push tags (`.in` only). |
| **Detected nearby** | Presence / co-location. **Unused for Moments in MVP.** |
| **Confirmed attendee** | For Moments: **same as tagged member** (explicit). No separate confirmation ceremony. |
| **Cover** | Media item at `sort_order == 0`. Feed first slide + hub thumbnail. |
| **Soft-deleted** | Hidden from all feeds and queries; not hard-purged in MVP. |
| **Feed › Pushes** | **Moments** stream only (product name may stay “Pushes” in UI for now). |
| **Feed › Now** | Deferred; empty. Not `FeedEvent` activity in this MVP. |
| **Activity FeedEvent** | Legacy domain (`arrived`, `groupForming`, …). **Out of scope** for Moment backend MVP. |

Do **not** treat invitees, attendees, contributors, and viewers as interchangeable.

---

## 2. Lifecycle rules

### 2.1 What creates a Moment

Three entry paths (all product-valid):

1. **Create from scratch** — user picks tags (solo allowed) → compose media + title + location → publish.  
2. **From a past Push** — user picks an **eligible** historical Push → compose (prefilled) → publish.  
3. **Add yours** — tagged member appends media to an **existing** published Moment (does not create a new Moment).

### 2.2 Push linkage

- A Moment **may** exist **without** a Push (scratch).  
- A Moment **may** link to **at most one** Push (`push_id` optional).  
- **At most one Moment per Push.** Once a Moment exists for a Push, that Push is **not** offered again in Past Pushes chooser.  
- Multiple Moments per Push: **no**.  
- Merge / split Moments: **no** in MVP.

### 2.3 Past-Push eligibility

A Push appears in Past Pushes when **all** of:

- Viewer is allowed to know about the Push under existing Push read rules (owner or invitee with visibility).  
- Push is **historical** (`PushLifecycle.isHistorical`: not cancelled, past `expiresAt`).  
- **No** Moment already linked to that Push (including soft-deleted? → **treat soft-deleted Moment as still consuming the slot** so a second Moment cannot be created; product can revisit hard-delete later).

### 2.4 Past-Push tag prefill

On open compose from past Push:

- Prefill **With** = creator of Moment (viewer) **plus** all people with Push response **`.in`** (excluding blocked users relative to viewer).  
- Viewer may **add more** friends before publish (explicit tags only; no location).  
- Viewer may **deselect** prefilled people before publish.

Scratch path: **no** auto tags; explicit multi-select only; **solo allowed** (tags = creator only).

### 2.5 When it becomes visible

- Moment is **created as published** on first successful submit with **≥1 media** item fully stored.  
- **No** empty-media Moments on Feed.  
- Drafts are **client-local** until publish succeeds (no server draft entity required for MVP).

### 2.6 Contribution window

- **Open indefinitely** while the Moment exists and is not soft-deleted.  
- No auto-close timer; no creator “close for adds” toggle in MVP (hub chips “Open for adds” / “You contributed” are **viewer-relative presentation**, not a closed state machine):  
  - **You contributed** if viewer is a media contributor.  
  - Else **Open for adds** if viewer is a tagged member (eligible to add).  
  - Viewers who are not tagged do not see contribute CTAs.

### 2.7 Delete / reopen

- **Soft-delete Moment**: allowed for **creator only**.  
- No reopen, merge, or split.  
- Soft-deleting the Moment hides it for everyone.  
- If media deletion leaves **zero** non-deleted media → **soft-delete the Moment** automatically.

### 2.8 Metadata edits

| Field | Who may edit after publish |
|---|---|
| Title | Creator only |
| Location text | Creator only |
| Media order (incl. cover) | Creator **or** any media contributor |
| Tags (With) | Creator **or** any media contributor |
| Add media | Any **currently tagged** member |
| Delete media | Uploader (own) **or** creator (any) |

---

## 3. Attendance rules

### 3.1 Signals used (MVP)

| Signal | Used for Moments? |
|---|---|
| Explicit tags | **Yes** — source of truth for membership |
| Push `.in` responses | **Prefill only** when creating from that Push |
| Push invite / `.maybe` / `.pending` / `.out` | **No** auto-tag |
| Detected nearby / location overlap | **No** |
| Ghost mode | **No effect** on Moments |

Late arrivals / missing location: **N/A** — anyone eligible may be tagged at any time via tag edit rules.

### 3.2 Who may change tags after publish

- **Creator**: add/remove any tagged member except cannot remove **self** (creator always tagged).  
- **Media contributor**: same as creator for tag add/remove (except cannot remove creator).  
- **Tagged non-contributor**: **self-remove only** (hide attendance). Cannot add/remove others until they become a contributor.  
- **Viewer (not tagged)**: cannot edit tags.

Self-remove:

- Allowed for non-creator tagged members.  
- Their **uploaded media remains**.  
- They lose add-media rights and drop from tagged stack; they may still **view** if visibility paths remain (e.g. still friends with other tagged people).  
- Creator **cannot** self-remove.

### 3.3 Role separation (canonical)

| Role | Stored / derived | UI |
|---|---|---|
| Invited | On Push only | Not shown as Moment puck |
| Responded | On Push only | Input to past-Push prefill (`.in`) |
| Detected nearby | Presence only | Unused |
| Confirmed attendee / tagged | **Stored** Moment membership | Feed card stack + names; compose With |
| Media contributor | **Derived** from media.uploader | Hub existing-moment stack; permission checks |
| Viewer | **Derived** from visibility rules | Can see card without + / … |

---

## 4. Contribution / media permissions

### 4.1 Add media (Add yours)

- **Who:** any **currently tagged** member (including creator).  
- **How long:** until Moment soft-deleted.  
- **Order:** new items **append** at end (`sort_order` max+1). Do not change cover.  
- **Caps:** product UI uses max **8** media per Moment for MVP — backend should enforce the same cap (or a documented server max ≥ UI).  
- **Video:** allow upload; playback fidelity can lag UI (poster acceptable initially) but bytes must be stored.

### 4.2 Delete media

- Uploader may soft-delete **own** media.  
- Creator may soft-delete **any** media.  
- Soft-deleted media omitted from Feed (no broken tile).  
- Last media deleted → soft-delete Moment.

### 4.3 Reorder media

- Creator **or** media contributor.  
- Cover = index 0 after reorder.  
- Non-contributor tagged members: no reorder.

### 4.4 Graph changes (unfriend / leave group / block)

| Event | Effect |
|---|---|
| **Block** (either direction) between viewer V and user U | U cannot provide a **visibility path** for V. Media uploaded by a user blocked with V is **omitted** for V. Faces of blocked users omitted from stacks for V. If no visibility path remains → Moment hidden for V. |
| **Unfriend** | Friendship path removed. Tagged membership **rows remain** historically. Visibility may drop for pure friends-of-tagged viewers who lose all friend paths. Co-tagged people who are not friends: see §5. |
| **Leave group** | Does not remove Moment tags. Group **filter** membership updates live. |
| **Remove friend / tags** | Does not hard-delete media. |

No automatic stripping of tags or media on unfriend (history keep). Block wins for **presentation and access**.

### 4.5 Organizer extras

- “Organizer” = **Moment creator** (not Push creator, unless same person).  
- Creator: metadata edit, delete any media, soft-delete Moment, always tagged, tag edit without needing prior contribution.

---

## 5. Visibility and privacy

### 5.1 Who can view a Moment

Viewer **V** may read Moment **M** when **all** of:

1. M is not soft-deleted.  
2. M has ≥1 media visible to V after block filtering.  
3. There exists at least one **tagged** member **T** such that:  
   - V = T, **or** V and T are **accepted friends**, **and**  
   - V and T are **not** blocked either direction.

**Implications:**

- Broad social discovery: friends of **any** tagged member can see the Moment, even if not tagged.  
- Creator is always tagged → creator’s friends always have a path via creator (unless blocked with creator **and** every other tagged friend path is blocked).  
- Not tagged and not friends with any tagged member → cannot view.

### 5.2 Friendship / group history

- Tags persist after unfriend (historical keep).  
- Visibility is **recomputed** from current friendships + tags + blocks (not frozen ACLs), except **location text is frozen** on the Moment.  
- Group membership only affects **filter chips**, not base visibility.

### 5.3 Ghost

- Ghost / `is_published` presence has **no effect** on creating, viewing, tagging, or contributing to Moments.

### 5.4 Hide attendance

- Self-remove from tags (§3.2).  
- No separate “hide me but stay tagged” flag in MVP.

### 5.5 Venue / activity historically

- Moment stores **its own** location display string (and optional place id for future).  
- Edits by creator update the frozen string.  
- Live sharing policies / vague-vs-exact presence **do not** rewrite past Moment location.  
- Moment MVP does not show live activity badges on cards.

---

## 6. Puck meanings (one meaning each)

| Surface | Collection | **One meaning** |
|---|---|---|
| Feed card bottom avatars + names | Tagged members | People on **With** (ordered stably, e.g. creator first then join order) |
| Feed card secondary line | Current slide uploader | **Uploader of the currently visible media item** (updates on page change) |
| Feed card + / … | Capabilities | **+** = tagged and can add media; **…** = may open edit surfaces allowed to that user (creator: full edit; contributor: media/tags/reorder; not a single overloaded “participant” lie — UI may still group controls but backend flags are separate) |
| Hub existing Moment stack | Media contributors | People who uploaded ≥1 media |
| Hub past Push stack | Prefill candidates / Push `.in` (+ creator) | People who **went** (RSVP in) for that Push — not Moment tags yet |
| Compose With list | Tagged members | Editable membership per §3–4 |
| Overflow `+N` | Count of remaining people in **that same collection** | Never mixes contributors into a tagged stack or vice versa |

**Separate capability flags (backend → client):**

| Flag | True when |
|---|---|
| `canView` | Visibility rules §5 |
| `canAddMedia` | Tagged member |
| `canEditTags` | Creator or media contributor |
| `canEditMetadata` | Creator |
| `canReorderMedia` | Creator or media contributor |
| `canDeleteMedia(mediaId)` | Uploader of that media or creator |
| `canDeleteMoment` | Creator |
| `youContributed` | Viewer is media contributor |
| `showOpenForAddsChip` | Viewer tagged and not yet contributor (hub) |

UI must not invent a single `canAddYours` that also means full edit; map CTAs from the flags above.

---

## 7. Feed behavior

### 7.1 Tabs

| Tab | MVP content |
|---|---|
| **Pushes** | Moments stream |
| **Now** | Empty / deferred (no activity events) |

### 7.2 Ordering

- Sort by **`last_activity_at` descending** (newest activity first).  
- `last_activity_at` = `max(published_at, last successful media add at)`.  
- Metadata-only edits **do not** bump (title/location/tags/reorder without new media).  
- Soft-deleted Moments excluded.

### 7.3 Pagination

- Server-side **cursor** pagination on `(last_activity_at, id)`.  
- Client: pull-to-refresh + load more; initial `LoadState`.

### 7.4 Thumbnails

- Cover = `sort_order == 0` among non-deleted media visible to viewer.  
- If cover media is block-filtered for viewer, use next visible media as display cover for that viewer only (do not rewrite global order).

### 7.5 Realtime

- **No** Moment Realtime in MVP.  
- Refresh: app foreground (existing session refresh pattern) + **pull-to-refresh** on Feed.  

### 7.6 Media counts

- Hub badge = count of non-deleted media (global).  
- Viewer-specific omit of blocked uploaders may make count lower for that viewer — **prefer viewer-visible count** on any count shown to that user.

### 7.7 Failed uploads

- Failed items never appear.  
- Partial batch: keep successes; report failure for remainder (`ActionError` / retry).  
- Client may show local loading placeholders only while upload in flight.

### 7.8 Group filter chips

- Built from viewer’s groups.  
- Filter: Moment included if **any tagged member** shares that **group membership** with the viewer (both accepted members of the group).  
- **All** = no group predicate.  
- Scratch Moments without Push still filter via tagged members’ groups.

---

## 8. Notifications (rules even if delivery ships later)

| Event | Notify whom | Notes |
|---|---|---|
| Moment published | All **tagged** members except actor | Not entire friends-of-tagged audience |
| Add yours (new media) | All **tagged** members except actor | |
| Title/location edit | Nobody | |
| Reorder | Nobody | |
| Tag add | Newly tagged user (optional nice-to-have); MVP: **yes, notify newly tagged** | |
| Tag remove / self-remove | Nobody | |
| Soft-delete Moment | Nobody | |
| Media delete | Nobody | |

Push notification **delivery** may be deferred; contract still defines intent. In-app alerts optional later.

---

## 9. Important edge cases

1. **Solo Moment** — creator only tagged; viewers = creator + friends of creator (friends-of-tagged via creator).  
2. **Past Push with only creator `.in`** — prefill creator only; may add friends.  
3. **Push cancelled** — not historical eligible; if Moment already linked, Moment remains under its own lifecycle.  
4. **One Moment per Push** — soft-deleted Moment still blocks a second Moment for that Push (slot consumed).  
5. **Contributor loses tag** (removed by creator) — loses `canAddMedia`; remains contributor for past media; may lose `canEditTags`/`canReorder` if those require contributor **and** still tagged? → **Contract: tag edit & reorder require (creator) OR (media contributor AND still tagged)**. Uploader may still delete own media if they can view; if they cannot view, delete via account tools later — MVP: delete own media allowed if `canView` or is uploader with auth check even if untagged (**uploader may delete own media if authenticated as uploader**, regardless of tag, as long as Moment not deleted).  
6. **Block after contribute** — others see Moment without blocked user’s media/face when paths remain.  
7. **Unfriend after tag** — tags remain; visibility paths update.  
8. **Empty after deletes** — auto soft-delete Moment.  
9. **Concurrent uploads** — append order by server commit time; both succeed until cap.  
10. **Cap exceeded** — reject extra media; do not partial-corrupt order.  
11. **Add yours copy** — product language should say Moment (“Add to moment”) when UI is updated; backend is Moment-centric.  
12. **Feed fixtures** — production/live must not show fixture carousels; empty surface until real data.  
13. **Multiple devices** — last write wins on metadata; media append is additive.  
14. **Creator deletes someone else’s media** — allowed; notify nobody.  
15. **Viewer not tagged** — can view (if friends-of-tagged) but no + / tag edit / reorder.

---

## 10. Permission matrix

Rows = actor relation to Moment. Columns = actions.  
**C** = creator · **T** = tagged non-contributor · **K** = media contributor who is still tagged · **K−** = contributor no longer tagged · **V** = viewer only (not tagged) · **—** = deny.

| Action | C | K | T | K− | V |
|---|---|---|---|---|---|
| View (if visibility path) | ✓ | ✓ | ✓ | ✓* | ✓* |
| Add media | ✓ | ✓ | ✓ | — | — |
| Delete own media | ✓ | ✓ | ✓ | ✓ | — |
| Delete others’ media | ✓ | — | — | — | — |
| Reorder media | ✓ | ✓ | — | — | — |
| Edit title / location | ✓ | — | — | — | — |
| Add/remove others’ tags | ✓ | ✓ | — | — | — |
| Self-remove tag | — | ✓ | ✓ | n/a | — |
| Soft-delete Moment | ✓ | — | — | — | — |
| Create linked Moment for Push | eligible Push participant per §2 | | | | |

\*View still requires §5 path after blocks/unfriends.

Backend enforces this matrix on every mutation.

---

## 11. Acceptance criteria for implementation

Implementation (future issues) is complete for this contract when:

1. **Terminology** in APIs/docs matches §1 (Moment ≠ Push ≠ FeedEvent).  
2. Scratch, past-Push (one Moment max, `.in` prefill), and Add-yours paths honor §2–4.  
3. Publish requires ≥1 media; empty Moments never appear in Feed.  
4. Soft-delete Moment + last-media auto soft-delete work end-to-end.  
5. Visibility matches friends-of-tagged + block rules; Ghost does not affect Moments.  
6. Each puck collection uses exactly one meaning from §6; capability flags are separate.  
7. Feed › Pushes orders by `last_activity_at`; Now remains deferred.  
8. Cover = sort_order 0; Add yours appends; creator/contributors can reorder.  
9. Group filters use tagged members’ shared groups with viewer.  
10. Permission matrix §10 enforced **server-side** (UI hiding is not sufficient).  
11. Notification **rules** documented in server hooks even if APNs not shipped.  
12. Live sessions show real data or true empty — never mock fixture Moments.  
13. Location text is stored on the Moment and not rewritten by live presence policies.  

---

## 12. Explicit non-goals (MVP)

- Feed › Now / `FeedEvent` activity stream  
- Location-based attendance  
- Contribution close timers / closed state  
- Merge, split, hard-delete, multiple Moments per Push  
- Realtime Moment subscriptions  
- External share links  
- Notifying the full friends-of-tagged audience  
- Rewriting historical location from sharing policies  

---

## 13. Interview summary (decisions log)

| Topic | Decision |
|---|---|
| Create paths | Scratch + past Push + Add yours |
| Scratch without Push | Yes |
| Visible when | First publish with ≥1 media |
| Contribution window | Open until deleted |
| Delete | Soft-delete only; no merge/split/reopen |
| Attendance | Explicit tags; no location |
| Past-Push prefill | RSVP `.in` only; editable; can add more |
| Tag edit after publish | Creator + media contributors; self-remove for tagged |
| Add media | Currently tagged members |
| Delete media | Own uploader + creator any |
| Reorder | Creator + contributors |
| Graph changes | Historical keep; block wins |
| Feed stack | Tagged members |
| Secondary line | Current media uploader |
| Hub stack | Contributors |
| Visibility | Friends of any tagged member |
| Ghost | No effect |
| Self-leave | Yes; media remains |
| Tabs | Pushes = Moments; Now deferred |
| Order | last activity (create or media add) |
| Cover | sort_order 0 |
| Realtime | Foreground + pull-to-refresh |
| Notifications | Tagged on create + Add yours |
| Metadata edit | Creator only |
| Moments per Push | **One max** |
| New media position | Append |
| Failed media | Omit; zero media → soft-delete Moment |
| Group filter | Shared group with any tagged member |
| Location history | Frozen on Moment |

---

## 14. Suggested next issues

1. Backend architecture / schema design from this contract (still no UI rewrite required first).  
2. Implementation plan: migrations, Storage, RPCs, `FeedRepository` reshape, client `LoadState`.  
3. UI flag split: replace single `canAddYours` with capability flags; Add yours / edit copy “moment”.  

This contract is sufficient to design backend architecture and an implementation plan without further product ambiguity on the topics above.
