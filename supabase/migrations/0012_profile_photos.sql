-- 0012_profile_photos.sql
-- Public avatars bucket for profile photos. Object keys:
--   {auth.users.id}/{uuid}.jpg
-- The app stores the public object URL on profiles.image_asset_path (existing column).
--
-- No storage.objects SELECT policy: public buckets already serve object.get via
-- public URLs. A broad SELECT policy would allow listing every avatar (advisor
-- public_bucket_allows_listing). Upsert still needs INSERT + SELECT + UPDATE on
-- the owner's folder for authenticated writes — SELECT is satisfied by the
-- update policy's USING clause only for rows the owner can see; INSERT/UPDATE/
-- DELETE below are sufficient for owner upload/replace/remove.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MiB hard cap; client compresses well below this
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Owner-only write under their own folder. Upsert needs INSERT + SELECT + UPDATE.
-- SELECT for own objects only (required for upsert; not listable for other users).
create policy "avatars_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatars_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatars_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "avatars_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
