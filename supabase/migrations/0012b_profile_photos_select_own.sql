-- 0012b_profile_photos_select_own.sql
-- Remote already applied 0012 with a listable public SELECT, then dropped it.
-- Add owner-only SELECT so upsert (INSERT+SELECT+UPDATE) works without listing
-- the whole bucket. Public object URLs still work via the public bucket flag.

drop policy if exists "avatars_public_select" on storage.objects;

drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
