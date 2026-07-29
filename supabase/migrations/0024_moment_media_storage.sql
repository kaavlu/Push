-- 0024_moment_media_storage.sql
-- Public `moment-media` Storage bucket for Moment photos/videos (Issue #119, S3).
-- Mirrors `avatars` (0012/0012b) and `group-photos` (0015): public bucket for CDN
-- object GET via unguessable UUID keys, no listable SELECT policy (advisor
-- `public_bucket_allows_listing`), all writes scoped by folder RLS.
--
-- Object key layouts:
--   pending/{auth.uid()}/{uuid}.{ext}          -- primary MVP publish path
--   pending/{auth.uid()}/{uuid}-poster.jpg     -- optional video poster
--   {moment_id}/{uuid}.{ext}                   -- optional direct "Add yours" append
--   {moment_id}/{uuid}-poster.jpg
--
-- Why `pending/` is the primary path (architecture §6.5): `create_moment` needs
-- media paths in the same transaction that allocates the moment id, so media must
-- be uploaded before any moment row exists. Pending keys are owner-scoped and the
-- public URL stays stable after create — no server-side move/copy is required, so
-- `moment_media.storage_path` may legitimately reference a pending key forever.
--
-- Size limit: buckets take a single cap, so it is sized for video (100 MiB).
-- The client enforces the tighter photo cap (see MomentMediaStorageConfig).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'moment-media',
  'moment-media',
  true,
  104857600, -- 100 MiB: video ceiling; client caps photos at 10 MiB
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'video/quicktime'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- First path segment as a uuid, or null when it is not a uuid (e.g. 'pending').
-- Policies cannot rely on AND short-circuiting to avoid a cast error, so the
-- guard lives inside the function.
create or replace function private.storage_moment_id(object_name text)
returns uuid
language sql
stable
set search_path = ''
as $$
  select case
    when (storage.foldername(object_name))[1]
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then ((storage.foldername(object_name))[1])::uuid
  end;
$$;

revoke execute on function private.storage_moment_id(text) from public, anon;
grant execute on function private.storage_moment_id(text) to authenticated;

-- May `u` upload media directly under `{moment_id}/…`? Tagged member of a live
-- Moment only. Mirrors the S2 `append_moment_media` authorization.
create or replace function private.moment_accepts_media(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select m is not null
    and private.is_moment_tagged(u, m)
    and exists (
      select 1 from public.moments mo
      where mo.id = m and mo.deleted_at is null
    );
$$;

revoke execute on function private.moment_accepts_media(uuid, uuid) from public, anon;
grant execute on function private.moment_accepts_media(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Policies — pending prefix (owner-only)
-- ---------------------------------------------------------------------------
-- SELECT is own-objects only: enough for upload existence checks, never a list
-- of the bucket. Public object GET does not consult these policies.

drop policy if exists "moment_media_pending_select_own" on storage.objects;
create policy "moment_media_pending_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'moment-media'
    and (storage.foldername(name))[1] = 'pending'
    and (storage.foldername(name))[2] = (select auth.uid()::text)
  );

drop policy if exists "moment_media_pending_insert_own" on storage.objects;
create policy "moment_media_pending_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'moment-media'
    and (storage.foldername(name))[1] = 'pending'
    and (storage.foldername(name))[2] = (select auth.uid()::text)
  );

drop policy if exists "moment_media_pending_update_own" on storage.objects;
create policy "moment_media_pending_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'moment-media'
    and (storage.foldername(name))[1] = 'pending'
    and (storage.foldername(name))[2] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'moment-media'
    and (storage.foldername(name))[1] = 'pending'
    and (storage.foldername(name))[2] = (select auth.uid()::text)
  );

-- Orphan rollback after a failed create_moment / append_moment_media deletes here.
drop policy if exists "moment_media_pending_delete_own" on storage.objects;
create policy "moment_media_pending_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'moment-media'
    and (storage.foldername(name))[1] = 'pending'
    and (storage.foldername(name))[2] = (select auth.uid()::text)
  );

-- ---------------------------------------------------------------------------
-- Policies — {moment_id} prefix (tagged members; optional append path)
-- ---------------------------------------------------------------------------

drop policy if exists "moment_media_moment_insert_tagged" on storage.objects;
create policy "moment_media_moment_insert_tagged"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'moment-media'
    and private.moment_accepts_media(
      (select auth.uid()),
      private.storage_moment_id(name)
    )
  );

-- Own uploads, plus the creator of that Moment. Scoped to one moment folder —
-- never a bucket-wide list. Postgres applies SELECT policies to the rows a
-- DELETE reads, so the creator needs this to exercise the delete policy below.
drop policy if exists "moment_media_moment_select_own" on storage.objects;
create policy "moment_media_moment_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'moment-media'
    and private.storage_moment_id(name) is not null
    and (
      owner_id = (select auth.uid()::text)
      or private.is_moment_creator(
        (select auth.uid()),
        private.storage_moment_id(name)
      )
    )
  );

-- Uploader rollback, or moment creator cleaning up media they may remove (S2
-- soft_delete_moment_media allows uploader or creator).
drop policy if exists "moment_media_moment_delete_uploader_or_creator" on storage.objects;
create policy "moment_media_moment_delete_uploader_or_creator"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'moment-media'
    and private.storage_moment_id(name) is not null
    and (
      owner_id = (select auth.uid()::text)
      or private.is_moment_creator(
        (select auth.uid()),
        private.storage_moment_id(name)
      )
    )
  );

-- No UPDATE policy under {moment_id}/: every upload writes a new object key.

-- ---------------------------------------------------------------------------
-- Note on S2 path validation (deliberately not added here)
-- ---------------------------------------------------------------------------
-- `create_moment` / `append_moment_media` accept `storage_path` as an opaque
-- string. Storage RLS above already prevents a caller from writing anywhere
-- except their own pending folder or a Moment they are tagged in, so a forged
-- path can only point at an object the caller could not have created — it
-- degrades that caller's own Moment rendering and leaks nothing. A prefix check
-- inside the RPCs would also break the existing S2 verify fixtures, which use
-- synthetic paths. Revisit if the client ever trusts `storage_path` for
-- authorization rather than display.
