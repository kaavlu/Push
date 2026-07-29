# Feed & Moment — Backend Architecture (MVP)

**Issue:** [#116](https://github.com/kaavlu/Push/issues/116)  
**Product contract:** `docs/superpowers/specs/2026-07-28-feed-moment-product-contract.md` (#115)  
**Surface audit:** `docs/superpowers/specs/2026-07-28-feed-moment-backend-requirements-audit.md` (#114)  
**Date:** 2026-07-28  
**Status:** Architecture plan only — **no implementation**, no migrations applied, no product decision changes.

Security-sensitive permissions must be enforced **server-side** (RLS + `SECURITY DEFINER` RPCs). UI capability flags are projections of the same rules, not the source of truth.

---

## 0. Goals

1. Persist **Moments** (media albums) distinct from **Pushes** (coordination) and from legacy **`FeedEvent`** activity.  
2. Serve Feed › Pushes with cursor pagination, friends-of-tagged visibility, and block-aware media.  
3. Support scratch publish, past-Push publish (one Moment per Push), and Add yours append.  
4. Fit existing Push Supabase patterns: `private.*` helpers, RPC-only mutations, Storage orphan rollback, session invalidation — without Realtime for Moments in MVP.

---

## 1. Infrastructure reuse audit

| Asset | Verdict | Notes for Moments |
|---|---|---|
| `PushPlan` / `pushes` | **Reuse as-is** | Past-Push eligibility via `expires_at` / `cancelled_at` (client already has `PushLifecycle`; server should mirror). Optional `moments.push_id` FK. |
| `PushResponse` / `push_responses` | **Reuse as-is** | Prefill only: `response = 'in'`. Never store RSVP as Moment membership. |
| `PushRepository` / `SupabasePushRepository` | **Extend (read-only consumers)** | Chooser lists historical pushes; filter out those with any Moment row for `push_id` (including soft-deleted). No Moment writes here. |
| `private.can_view_push` / `is_push_creator` | **Reuse as-is** | Gate “may create Moment from this Push” + chooser visibility. |
| Friendships / `private.is_friend` | **Reuse as-is** | Visibility path: friend of any tagged member. |
| Blocks / `private.is_blocked` | **Reuse as-is** | Path + per-uploader media omit. |
| Groups / `private.is_group_member` / `shares_group` | **Reuse as-is** | Feed group **filter only** (not base visibility). |
| `SharingPolicy` / presence Ghost | **Do not use for Moments** | Location text frozen on Moment; Ghost irrelevant (contract §5.3). |
| `FeedEvent` domain | **Do not use for Moments** | Reserved for deferred Feed › Now. |
| `FeedRepository.events()` / `LocalFeedRepository` / `EmptyLiveFeedRepository` | **Do not overload** | Leave activity-empty. Introduce **`MomentRepository`** (or reshape later); do not map Moments into `FeedEvent.kind`. |
| Seed `feedEvents` | **Do not use** | Mock Moments get their own seed later; live never shows fixtures. |
| Storage `avatars` / `group-photos` | **Pattern reuse, new bucket** | New key layout, public CDN URL on row, owner/uploader folder policies, client orphan rollback. |
| `ProfilePhotoStoring` / `GroupPhotoStoring` / processors | **Pattern reuse** | New `MomentMediaStoring`; reuse JPEG compress where applicable; video path separate. |
| `AvatarImageLoader` | **Reuse as-is** | HTTPS (and local mock) resolution for media URLs + faces. |
| `LiveDataStore` warm (9 resources) | **Do not warm full feed** | Moments are **paginated on demand**. Optional: small “hub existing moments” cache invalidated on write. |
| `notifyPushesChanged` / friendship notify | **Pattern reuse** | Add `notifyMomentsChanged()` (clear moment caches, bump revision once per logical write). |
| `AppDataContainer` repo injection | **Extend** | Wire `MomentRepository` mock vs live; live empty until migrated. |
| `ProfilePhotoProcessor` style resize | **Reuse for photos** | Videos: upload bytes + optional poster later. |
| Account deletion `0014` | **Extend later** | Soft-delete or cascade Moments/media/Storage when user deleted (implementation slice). |
| Realtime presence bridge | **Do not use** | No Moment Realtime (contract). |
| `ActionErrorBanner` / `LoadState` | **Reuse client-side** | Feed load/refresh + mutation errors. |
| UI fixtures (`FeedMediaCarouselFixtures`, etc.) | **Mock/DEBUG only** | Live path must not default to fixtures once repo lands. |

**Gap summary:** No Moment tables, Storage bucket, RPCs, repository protocol, or derived capability builder exist today.

---

## 2. Domain model

### 2.1 Conceptual entities

```
Moment
  id, creatorID (immutable)
  title, locationText, placeID?          // frozen copy; not live presence
  pushID?                                // optional; at most one Moment per Push forever
  publishedAt, lastActivityAt
  deletedAt?                             // soft-delete

MomentMember (tag)
  momentID, personID
  taggedAt                               // stable order: creator first, then taggedAt
  // creator always has a row; cannot be removed

MomentMedia
  id, momentID, uploaderID
  kind: photo | video
  storageObjectPath, publicURL
  posterObjectPath?, posterURL?          // video poster optional MVP
  sortOrder                              // 0 = cover (global)
  createdAt, deletedAt?

MomentCapabilities (read projection, not a table)
  canView, canAddMedia, canEditTags, canEditMetadata,
  canReorderMedia, canDeleteMoment, youContributed,
  canDeleteMedia[mediaId]...
```

**Derived (never stored as role enums):**

| Concept | Derivation |
|---|---|
| Media contributor | Exists non-deleted `moment_media` with `uploader_id = user` |
| Viewer | `can_view_moment` true |
| Invited / Responded | Push tables only |
| Detected nearby | Unused |

### 2.2 Identity rules

- **Moment ≠ Push ≠ FeedEvent.**  
- Soft-deleted Moment **retains** `push_id` and **consumes** the one-Moment-per-Push slot.  
- Publish atomicity: Moment + ≥1 media + creator tag (+ other tags) commit together (single RPC or transaction inside RPC).  
- Max **8** non-deleted media per Moment (server-enforced).

### 2.3 Client domain (Swift sketch — not implementing)

New types under `Push/Data/Domain/` (names illustrative):

- `Moment`, `MomentMember`, `MomentMedia`, `MomentMediaKind`  
- `MomentCapabilities`  
- Presentation builders map → existing `FeedMediaCarouselData` / chooser models with **separate** flags (retire overloaded `canAddYours` meaning full edit).

---

## 3. Database relationships (sketch — not applied SQL)

### 3.1 Tables

#### `public.moments`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `creator_id` | `uuid` → `profiles` | Immutable; ON DELETE behavior TBD with account deletion |
| `title` | `text` | Length limits mirror client (e.g. 80) |
| `location_text` | `text` | Frozen display string; may be empty |
| `place_id` | `text` null | Optional future; not required MVP |
| `push_id` | `uuid` null → `pushes(id)` ON DELETE SET NULL? | Prefer **RESTRICT** or keep FK and leave push_id even if push hard-deleted — product keeps Moment. Use `ON DELETE SET NULL` only if push hard-delete exists; today pushes soft-cancel. |
| `published_at` | `timestamptz` | Set once at create |
| `last_activity_at` | `timestamptz` | Create + media append only |
| `created_at` / `updated_at` | `timestamptz` | |
| `deleted_at` | `timestamptz` null | Soft-delete |

**Constraints / indexes:**

- `UNIQUE (push_id)` where `push_id IS NOT NULL` — Postgres unique allows multiple NULLs; soft-deleted rows still hold `push_id` → **one Moment per Push forever**.  
- Index feed: `(last_activity_at DESC, id DESC)` partial `WHERE deleted_at IS NULL`.  
- Index creator: `(creator_id)` for hub “my moments”.  
- Check: `title` non-null (allow empty string or require length ≥ 1 — prefer non-empty trimmed title at RPC).

#### `public.moment_members`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `moment_id` | `uuid` → `moments` ON DELETE CASCADE | |
| `person_id` | `uuid` → `profiles` | |
| `tagged_at` | `timestamptz` | Default `now()` |

- `UNIQUE (moment_id, person_id)`  
- Index `(person_id)` for “moments I’m on” / reverse lookups  
- Application invariant: creator always present (enforced in RPCs, not only FK)

#### `public.moment_media`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `moment_id` | `uuid` → `moments` ON DELETE CASCADE | |
| `uploader_id` | `uuid` → `profiles` | |
| `kind` | `text` check `photo` \| `video` | |
| `storage_path` | `text` | Object key in bucket |
| `public_url` | `text` | CDN URL for client |
| `poster_path` / `poster_url` | null | Optional video poster |
| `sort_order` | `int` not null | 0-based dense among non-deleted after reorder |
| `created_at` | `timestamptz` | |
| `deleted_at` | `timestamptz` null | Soft-delete |

- Index `(moment_id, sort_order)` for gallery  
- Cap: RPC counts `deleted_at IS NULL` ≤ 8  
- No unique on `sort_order` globally while soft-deleted rows exist — RPCs renumber active rows densely on reorder

### 3.2 Relationship diagram

```
profiles ──┬──< moment_members >── moments ──?── pushes
           │                         │
           └──< moment_media >───────┘
                    (uploader_id)
```

### 3.3 Why not extend `FeedEvent`

`FeedEvent` is a lightweight activity materialization without media, tags, or contribution rights. Overloading it would violate terminology and visibility rules. Keep it dormant for Feed › Now.

---

## 4. Storage strategy

### 4.1 Bucket

| Property | Proposal |
|---|---|
| Bucket id | `moment-media` |
| Public | **Yes** (same tradeoff as `avatars` / `group-photos`: unguessable UUID paths; visibility enforced by **not leaking URLs** via RLS on metadata) |
| Path layout | `{moment_id}/{media_id}.{ext}` (and optional `{moment_id}/{media_id}-poster.jpg`) |
| Mime | images: jpeg/png/webp; video: mp4/quicktime (tighten in migration) |
| Size limits | Photos ~5–10 MiB; video higher cap (e.g. 50–100 MiB) — finalize at implement time |
| Cache-Control | New object key per upload (no in-place overwrite), e.g. 3600s |

### 4.2 Write pipeline (client + RPC)

1. Client obtains right to add (is tagged) — optional lightweight RPC `assert_can_add_moment_media`.  
2. Client uploads bytes to Storage under `moment_id/…` (Storage policy requires tagged + moment not deleted).  
3. Client calls `append_moment_media` with path/URL/kind — RPC validates uploader, cap, membership; inserts row; bumps `last_activity_at`.  
4. On RPC failure after upload: **orphan rollback** (delete Storage object) — mirror profile/group photo pattern.  
5. Partial multi-select: per-item try; keep successes; surface failures via `ActionErrorState`.

### 4.3 Soft-delete media vs Storage

- MVP: **soft-delete DB row only**; object may remain (GC job later). Optional best-effort Storage delete on soft-delete.  
- Moment soft-delete: hide all media via parent; bulk Storage GC deferred.

### 4.4 Mock

- Local file store under Application Support `moment-media/` (like `GroupPhotoFileStore`) **or** fixture asset paths only until mock write path needed.

### 4.5 As-built notes (S3 — migrations `0024`, `0025`)

Implementation annotations, not product changes:

- **Keys:** `pending/{auth.uid()}/{uuid}.{ext}` is the primary publish path and stays pending after `create_moment` (no server-side move); `{moment_id}/{uuid}.{ext}` is accepted for appends. Posters are a parallel `…-poster.jpg` key.
- **Limits:** bucket cap 100 MiB (single value, sized for video); the client holds photos to 10 MiB.
- **Path authorization is server-side.** Storage RLS alone would not stop a caller *registering* someone else's object in their own Moment, so `create_moment` / `append_moment_media` validate every path against `storage.objects`: exists in `moment-media`, owned by `auth.uid()`, allowed key layout, mime matching the declared kind, not already registered by an active media row. `public_url` / `poster_url` are derived server-side; caller-supplied URLs are ignored.
- **Public-bucket limitation (accepted for MVP):** because the bucket is public, an already-known object URL remains fetchable from the CDN. Blocking, untagging, or soft-deleting a Moment prevents future URL *discovery* through Push but cannot revoke a URL someone already holds. Hard revocation would need a private bucket plus signed URLs on every read — deferred unless the product contract requires it (contract §4 does not).

---

## 5. Authorization model

### 5.1 Principle

- **SELECT:** RLS using `private` helpers (and/or SECURITY DEFINER read RPCs for complex feed queries).  
- **INSERT/UPDATE/DELETE on tables:** **no** broad client write policies — **RPC-only mutations** (same as group lifecycle / blocks).  
- Storage policies separate from table RLS.

### 5.2 Private helpers (sketch)

| Helper | Meaning |
|---|---|
| `private.moment_not_deleted(m)` | `deleted_at IS NULL` |
| `private.is_moment_creator(u, m)` | `creator_id = u` |
| `private.is_moment_tagged(u, m)` | member row exists |
| `private.is_moment_contributor(u, m)` | non-deleted media uploaded by `u` |
| `private.can_edit_moment_tags(u, m)` | creator **or** (contributor **and** still tagged) |
| `private.can_reorder_moment_media(u, m)` | same as tags |
| `private.can_view_moment(u, m)` | not deleted **and** exists tagged `T` with (`u = T` OR `is_friend(u,T)`) AND NOT `is_blocked(u,T)` **and** exists non-deleted media whose uploader is not blocked with `u` |
| `private.media_visible_to(u, media_id)` | media not deleted, moment viewable, not blocked with uploader |
| `private.can_create_moment_from_push(u, push)` | `can_view_push` **and** historical **and** no row in `moments` for `push_id` (incl. soft-deleted) |

All helpers: `SECURITY DEFINER`, `search_path = ''`, revoke from `public`/`anon`, grant execute to `authenticated` for policy use only (or keep execute revoked from client if only used inside other definer functions — match existing friendship pattern which grants authenticated for RLS).

### 5.3 RLS sketch

**`moments` SELECT:** `private.can_view_moment(auth.uid(), id)`  

**`moment_members` SELECT:** parent moment viewable (then client filters blocked faces) **or** only members of moments you can view  

**`moment_media` SELECT:** `private.media_visible_to(auth.uid(), id)`  

**No INSERT/UPDATE/DELETE policies** on the three tables for `authenticated` (RPC only).

> Note: Friends-of-tagged SELECT can be expensive; acceptable MVP with indexes on members(person_id), friendships, blocks. If slow, switch feed to a single SECURITY DEFINER RPC that returns a page (still must enforce same predicates).

### 5.4 Mutation RPCs (all SECURITY DEFINER, auth.uid() checks)

| RPC | AuthZ (contract matrix) | Behavior |
|---|---|---|
| `create_moment(...)` | Authenticated; tags ⊆ friends of creator (recommended) + self; if `push_id` set: `can_create_moment_from_push` | Inserts moment, members (creator mandatory), ≥1 media rows (paths already uploaded **or** accept first media in same call); set `published_at` / `last_activity_at`; reject empty media |
| `append_moment_media(moment_id, …)` | Tagged; moment not deleted; count < 8 | Append `sort_order = max+1`; bump `last_activity_at` only |
| `update_moment_metadata(moment_id, title, location_text)` | Creator only | No activity bump |
| `add_moment_members` / `remove_moment_member` | Creator or (contributor ∧ tagged); cannot remove creator; self-remove allowed for non-creator tagged | No activity bump; newly tagged → notification hook stub |
| `reorder_moment_media(moment_id, uuid[])` | Creator or (contributor ∧ tagged) | Rewrite dense `sort_order` 0..n-1 for non-deleted; validate set equality |
| `soft_delete_moment_media(media_id)` | Uploader **or** creator; moment not deleted | Soft-delete media; if zero active media → soft-delete moment |
| `soft_delete_moment(moment_id)` | Creator | Set `deleted_at`; keeps `push_id` |

**Create from push prefill** is **client-side** using existing push reads + `.in` responses; server only validates final tag set + push eligibility on create.

### 5.5 Permission matrix → enforcement

| Action | Server check |
|---|---|
| View | RLS / `can_view_moment` + media filter |
| Add media | RPC: `is_moment_tagged` ∧ not deleted ∧ cap |
| Delete own media | RPC: `uploader_id = me` (even if untagged) ∧ moment not deleted |
| Delete others’ media | RPC: `is_moment_creator` |
| Reorder | RPC: `can_reorder_moment_media` |
| Edit title/location | RPC: creator |
| Add/remove others’ tags | RPC: `can_edit_moment_tags`; not creator target remove |
| Self-remove tag | RPC: tagged ∧ not creator ∧ person_id = me |
| Soft-delete Moment | RPC: creator |
| Create linked to Push | RPC: `can_create_moment_from_push` |

Capability flags returned on read DTOs are **computed identically** in SQL or app layer from the same predicates (prefer one SQL function `moment_capabilities(u, m) returns jsonb` to avoid drift).

### 5.6 Storage policies (sketch)

- **INSERT:** `bucket_id = moment-media` AND folder `moment_id` matches AND `private.is_moment_tagged(auth.uid(), moment_id)` AND moment not deleted  
- **SELECT:** public bucket → no list-all policy (avoid listing); public URL get works without SELECT list (same advisor caution as avatars)  
- **DELETE:** uploader path owner **or** moment creator (if expressible); else RPC-driven service cleanup later  
- **UPDATE:** generally unused (new keys only)

---

## 6. Read / write flows

### 6.1 Feed page (Feed › Pushes)

```
Client FeedViewModel.load/refresh
  → MomentRepository.feedPage(cursor, limit, groupFilterID?)
  → Live: RPC feed_moments(p_cursor_activity, p_cursor_id, p_limit, p_group_id)
       OR PostgREST select with RLS + client filter (prefer RPC for cursor + group filter + block-aware media)
  → Returns: moment cards (title, location, times, tagged faces [-blocked],
             media list [-blocked uploaders], capabilities, last_activity_at)
  → Map to FeedMediaCarouselData (flags split)
  → LoadState / empty surface if none
```

**Cursor:** `(last_activity_at, id)` strictly descending; next page `WHERE (last_activity_at, id) < (cursor_activity, cursor_id)`.

**Group filter:** Moment included if ∃ tagged T, viewer V both `active` members of `p_group_id`.

**Not in MVP:** Realtime invalidation; rely on foreground `refreshSession` pattern + pull-to-refresh calling moments refresh (may skip full nine-resource warm).

### 6.2 Hub — Existing Moments

```
MomentRepository.momentsForHub()
  → Moments viewer can view where viewer is tagged OR contributed
    (product: “moments you post / revisit” — prefer: creator OR tagged OR contributed,
     ordered by last_activity_at)
  → Contributors stack = distinct uploaders of non-deleted media (block-filter faces)
  → Chips: youContributed / open for adds from capabilities
```

### 6.3 Hub — Past Pushes chooser

```
PushRepository.historicalPlans(...)  // existing
  + exclude push_ids present in moments (any deleted_at)
  + viewer can_view_push
  → Prefill tags client-side from push_responses where response = 'in'
     (plus self; minus blocked)
```

Server helper optional: `list_past_pushes_without_moment()`.

### 6.4 Single Moment load (edit / Add yours)

```
get_moment(moment_id) → full media + members + capabilities
  404/empty if !can_view
```

### 6.5 Write — Publish scratch

```
1. Validate local draft (≥1 media, title rules)
2. Create moment id client-side UUID? → Prefer server-generated id:
   Option A: RPC create_moment_shell returns id → upload media → append (racy empty moment)
   Option B (recommended): upload to staging path under user id then create_moment moves/registers
   Option C (recommended MVP): 
      - RPC reserve_moment_id() creates soft-unpublished? — contract forbids empty feed visibility
      - Better: upload under `pending/{user_id}/{uuid}` then create_moment attaches paths in one transaction
```

**Recommended MVP publish sequence:**

1. `create_moment` RPC accepts metadata + tag ids + **array of already-uploaded storage paths** under a **pending** prefix owned by user.  
2. RPC validates ≥1 path, moves/rewrites paths to `{moment_id}/…` **or** accepts paths already at final keys if `moment_id` was pre-allocated inside the same RPC via temp table.  
3. Simplest robust approach used by many apps here:  
   - **RPC `create_moment` creates moment + members first** inside transaction, returns `moment_id` **without committing media**.  
   - **Do not SELECT-list unpublished moments** — add `published` flag? Contract says publish = first success with media.  
   - Cleaner: **single RPC after uploads to pending:**  
     `create_moment(title, location, push_id?, tag_ids[], media jsonb[])`  
     where media entries reference `pending/{auth.uid()}/…` objects; RPC verifies ownership of pending objects, inserts moment+members+media, updates storage paths via metadata only (path stays pending **or** client uploaded knowing moment_id).

**Practical MVP (aligned with group photos):**

1. Client calls `create_moment_draft` → returns `moment_id` (row with `deleted_at = now()` temporary? **No — ugly**).  
2. Instead: client generates `moment_id` UUID, uploads to `{moment_id}/…` with Storage policy allowing insert if **no moment row yet** and path prefix is uuid — **weak**.  

**Chosen approach:**

- **Pending uploads:** `moment-media` path `pending/{user_id}/{uuid}.ext` with owner-only write.  
- **`create_moment` RPC:** creates moment, members, media rows pointing at pending paths (or copies path strings), sets published; optional follow-up client rename not required if public URL uses pending path (stable).  
- Feed RLS requires `deleted_at IS NULL` and media count ≥ 1 — never returns empty.  
- Failed create: client deletes pending objects.

### 6.6 Write — Publish from past Push

Same as create with `push_id` set; RPC enforces uniqueness + historical + `can_view_push`. Tags may include non-`.in` friends (client may add more). Server should require each tag is either self or accepted friend of creator (block check).

### 6.7 Write — Add yours

```
Upload pending or direct under moment_id (if Storage allows tagged insert)
→ append_moment_media
→ notifyMomentsChanged
→ notification stub for other tags
```

### 6.8 Write — Metadata / tags / reorder / deletes

RPC as §5.4; client rolls back optimistic UI on error; no `last_activity_at` bump except media append/create.

---

## 7. Edge-case design

| Case | Design |
|---|---|
| **Unfriend** | Membership rows **kept**. Visibility recomputed via `is_friend` on read. No trigger cleanup. |
| **Tag add** | RPC inserts member; optional notify newly tagged. |
| **Tag remove (by editor)** | Delete member row; media remains; if removed user was only visibility path for some viewers, they lose access automatically. |
| **Self-remove** | Non-creator deletes own member row; media remains; loses tagged rights. |
| **Cannot remove creator** | RPC exception `cannot_remove_creator`. |
| **Block** | `is_blocked` excludes path and omits media/faces for that pair. No row deletion. |
| **Leave group** | Tags unchanged; group filter results change on next read. |
| **Soft-delete media** | `deleted_at = now()`; renumber optional (leave gaps vs dense — **dense renumber** on delete to keep cover = 0). If count active = 0 → soft-delete moment. |
| **Soft-delete moment** | `moments.deleted_at = now()`; excluded from feed; `push_id` unique still holds. |
| **Concurrent append** | Transaction: lock moment row (`SELECT … FOR UPDATE`), read max sort_order, insert, bump activity; second waiter gets next order; cap checked inside lock. |
| **Concurrent reorder** | Last writer wins full order array; validate media id set matches current non-deleted set or fail `conflict`. |
| **Concurrent metadata** | Last write wins on title/location. |
| **Concurrent tag edit** | Row-level unique handles double-add; remove is idempotent. |
| **Cover block-filtered** | Global `sort_order` unchanged; **read DTO** picks first media visible to viewer as display cover. |
| **Cap exceeded** | RPC raises; no partial sort corruption. |
| **Push cancelled after Moment** | Moment remains; push no longer in past chooser for new Moments. |
| **Second Moment same Push** | Unique violation / RPC `moment_exists_for_push`. |
| **Live fixtures** | Live `MomentRepository` returns empty until data exists; **never** fall back to `FeedMediaCarouselFixtures`. |
| **Account deletion** | Future: soft-delete moments created by user or cascade; Storage cleanup best-effort (extend `0014` in a later slice). |
| **Notifications** | MVP: write to a future `notifications` table or no-op hooks with documented events; **no APNs required** in architecture MVP. Audience = tagged only, not friends-of-tagged. |

---

## 8. Client architecture sketch

### 8.1 Repository protocol (illustrative)

```text
protocol MomentRepository {
  func feedPage(cursor: MomentFeedCursor?, limit: Int, groupID: String?) async throws -> MomentFeedPage
  func hubMoments() async throws -> [MomentSummary]
  func moment(id: Moment.ID) async throws -> MomentDetail
  func createMoment(_ draft: MomentDraft) async throws -> Moment.ID
  func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws
  func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws
  func setTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws  // or add/remove
  func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws
  func softDeleteMedia(mediaID: MomentMedia.ID) async throws
  func softDeleteMoment(momentID: Moment.ID) async throws
}
```

- **Mock:** `LocalMomentRepository` + `InMemoryDatabase` moment tables / seed.  
- **Live:** `SupabaseMomentRepository` + Storage; `EmptyLiveMomentRepository` only for tests if needed.  
- **`FeedRepository`:** remains activity events; Feed UI switches to `MomentRepository` for Pushes tab.

### 8.2 Caching

- Do **not** put full feed into initial `LiveDataStore.warm()`.  
- Optional session cache: last feed page + hub list; clear on `notifyMomentsChanged()`.  
- ViewModels: `LoadState`, `lastSeenRevision` if using container revision for mutations.

### 8.3 Past Push integration

- `PushRepository.historicalPlans` + new query/filter for moment-linked push ids (`MomentRepository.pushIDsWithMoments()` including soft-deleted).

---

## 9. Migration sequencing

Imperative migrations (project style). Suggested order **after `0020`**:

| Step | Migration (name illustrative) | Contents |
|---|---|---|
| M1 | `0021_moments_tables` | `moments`, `moment_members`, `moment_media`; indexes; unique `push_id`; RLS enable + SELECT policies; **no** client writes |
| M2 | `0022_moments_private_helpers` | `can_view_moment`, tagged/contributor/creator helpers, capabilities helper |
| M3 | `0023_moments_rpcs` | create, append, metadata, tags, reorder, soft-delete media/moment; grants; revoke public |
| M4 | `0024_moment_media_storage` | bucket `moment-media`; pending + moment folder policies; mime/size |
| M5 | `0025_moments_feed_rpc` | `feed_moments` cursor RPC + optional hub list RPC (if not pure RLS selects) |
| M6 | `0026_moments_verify` | SQL verify script (like `0018_current_presence_verify.sql`) — may live under `supabase/tests/` only |

Dependencies: profiles, friendships, blocks, pushes, push_responses, group_memberships already present.

**Do not** put Moment Realtime publication in MVP migrations.

---

## 10. RLS / policy requirements (checklist)

- [ ] RLS on all three tables  
- [ ] SELECT uses friends-of-tagged + not deleted + visible media existence  
- [ ] Media SELECT omits blocked uploaders  
- [ ] No authenticated INSERT/UPDATE/DELETE on tables  
- [ ] All mutations via SECURITY DEFINER RPCs with in-body `auth.uid()` checks  
- [ ] Helpers in `private` schema; not designed as public product RPC surface  
- [ ] Storage: no public list; owner/tagged write; public read via URL  
- [ ] Unique `push_id` includes soft-deleted rows  
- [ ] Feed RPC runs as definer but re-checks viewer = `auth.uid()` and same visibility predicates  
- [ ] Grants: `authenticated` execute on public RPCs only; revoke from `anon`/`public`  
- [ ] Advisors: no security definer in public without auth check; no broad storage listing  

---

## 11. Testing strategy

### 11.1 SQL verify (`supabase/tests/…_moments_verify.sql`)

Cases:

1. Solo moment: creator + friend of creator can select; stranger cannot.  
2. Friends-of-tagged: friend of tagged non-creator can select.  
3. Block breaks path and hides uploader media.  
4. Soft-deleted moment invisible; `push_id` still blocks second create.  
5. Historical push create ok; active/cancelled push rejected.  
6. Append requires tag; untagged contributor-only cannot append.  
7. Reorder denied for tagged non-contributor.  
8. Last media delete soft-deletes moment.  
9. Cap 9th media rejected.  
10. Creator always remains tagged.

### 11.2 App tests

| Suite | Focus |
|---|---|
| `MomentRepositoryTests` / mapping tests | Row ↔ domain, cursor, capabilities |
| `MomentPermissionTests` | Matrix via mock store rules parity |
| `FeedViewModelTests` | LoadState, empty live, no fixtures in live container |
| `CreatePost` / `AddYours` integration later | Wire to repo in UI slices |
| `LiveContainerIsolationTests` | Live feed/moments empty of mock seed |

### 11.3 Fixture isolation

- DEBUG mock may seed Moments.  
- Live `prepareLive` must not inject fixture carousels into `FeedViewModel`.  
- Tests assert production init uses repository, not `FeedMediaCarouselFixtures` default when live.

---

## 12. Implementation slices (PR-sized, no code now)

| Slice | Deliverable | Ship gate |
|---|---|---|
| **S0** | This architecture approved | — |
| **S1** | M1–M2 tables + helpers + SQL verify skeleton | Verify script green on empty policies |
| **S2** | M3 mutation RPCs + verify matrix | SQL permission cases |
| **S3** | M4 Storage bucket + client `MomentMediaStoring` + orphan rollback unit tests | Upload/delete paths |
| **S4** | Domain types + `MomentRepository` protocol + Local mock + seed | DataLayer tests |
| **S5** | `SupabaseMomentRepository` + feed/hub RPCs (M5) + mapping | Integration tests / manual live |
| **S6** | Wire `FeedViewModel` to repo (`LoadState`, refresh, empty); strip live fixtures | FeedViewModelTests |
| **S7** | Wire Create Post publish + past Push eligibility + one-per-push | CreatePost tests |
| **S8** | Wire Add yours append + capability flags UI split | AddYours tests |
| **S9** | Tag edit / reorder / soft-delete paths in UI | Permission UI + repo tests |
| **S10** | Notification hooks stub + docs; account-deletion follow-up issue | Non-blocking |

Slices S6–S9 may merge carefully but should not mix schema invent with full UI rewrite in one PR.

---

## 13. Explicit non-goals (preserved from contract)

Architecture and implementation slices **must not** include:

| Deferred | Rationale |
|---|---|
| Feed › Now / `FeedEvent` activity stream | Separate product |
| Location-based attendance / nearby detection | Contract MVP |
| Contribution close timers / closed state machine | Open until delete |
| Merge / split / hard-delete / multiple Moments per Push | Contract |
| Realtime Moment subscriptions | Pull + foreground refresh only |
| External share links | Out of scope |
| Notifying full friends-of-tagged audience | Notify **tagged** only |
| Rewriting historical location from sharing policies | Frozen `location_text` |
| Ghost gating of Moments | No effect |
| APNs delivery | Rules only; delivery later |

---

## 14. Open implementation choices (non-product)

These do **not** change product rules; resolve at implement time:

1. Feed via pure RLS + PostgREST vs single `feed_moments` RPC (recommend **RPC** for cursor + group filter + stable DTO).  
2. Pending upload path vs upload-after-id allocation (recommend **pending/{user_id}/** then `create_moment`).  
3. Dense renumber on every media delete vs allow gaps (recommend **dense** so cover is always 0).  
4. Whether hub lists “all viewable I’ve interacted with” vs “tagged only” (recommend **tagged ∪ contributed ∪ created**).  
5. Video poster generation client-side vs server (client poster optional MVP).  

---

## 15. Acceptance criteria (architecture issue)

- [x] Reuse vs extend vs do-not-use documented (§1)  
- [x] Domain + DB relationships satisfy one Moment per Push, soft-delete slot, tags, media (§2–3)  
- [x] Storage strategy (§4)  
- [x] Every permission-matrix action has backend path (§5)  
- [x] Read/write flows (§6)  
- [x] Friendship, tags, blocks, soft delete, concurrency, ordering (§7)  
- [x] Migration sequence, RLS checklist, tests, slices (§9–12)  
- [x] Contract non-goals preserved (§13)  
- [x] No implementation / migrations applied in this issue  

---

## 16. Suggested follow-on issue title

**Implement Moment backend (schema, Storage, RPCs, MomentRepository) — slices S1–S5**  
then **Wire Feed / Create Post / Add Yours to MomentRepository — slices S6–S9**.
