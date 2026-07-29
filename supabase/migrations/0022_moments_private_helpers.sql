-- 0022_moments_private_helpers.sql
-- Private AuthZ helpers + SELECT RLS for Moments (Issue #117 / architecture S1 M2).
-- Visibility: friends-of-tagged + block-aware media. No Ghost / sharing_policies.
-- Mutation RPCs intentionally deferred to S2.
--
-- Rollback (manual):
--   drop policy if exists moments_select_visible on public.moments;
--   drop policy if exists moment_members_select_visible on public.moment_members;
--   drop policy if exists moment_media_select_visible on public.moment_media;
--   drop function if exists private.moment_capabilities(uuid, uuid);
--   drop function if exists private.media_visible_to(uuid, uuid);
--   drop function if exists private.can_view_moment(uuid, uuid);
--   drop function if exists private.can_reorder_moment_media(uuid, uuid);
--   drop function if exists private.can_edit_moment_tags(uuid, uuid);
--   drop function if exists private.is_moment_contributor(uuid, uuid);
--   drop function if exists private.is_moment_tagged(uuid, uuid);
--   drop function if exists private.is_moment_creator(uuid, uuid);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function private.is_moment_creator(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.moments mo
    where mo.id = m
      and mo.creator_id = u
  );
$$;

revoke execute on function private.is_moment_creator(uuid, uuid) from public, anon;
grant execute on function private.is_moment_creator(uuid, uuid) to authenticated;

create or replace function private.is_moment_tagged(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.moment_members mm
    where mm.moment_id = m
      and mm.person_id = u
  );
$$;

revoke execute on function private.is_moment_tagged(uuid, uuid) from public, anon;
grant execute on function private.is_moment_tagged(uuid, uuid) to authenticated;

create or replace function private.is_moment_contributor(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.moment_media med
    where med.moment_id = m
      and med.uploader_id = u
      and med.deleted_at is null
  );
$$;

revoke execute on function private.is_moment_contributor(uuid, uuid) from public, anon;
grant execute on function private.is_moment_contributor(uuid, uuid) to authenticated;

-- Creator, or media contributor who is still tagged (contract §3.2 / §9.5).
create or replace function private.can_edit_moment_tags(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_moment_creator(u, m)
    or (
      private.is_moment_contributor(u, m)
      and private.is_moment_tagged(u, m)
    );
$$;

revoke execute on function private.can_edit_moment_tags(uuid, uuid) from public, anon;
grant execute on function private.can_edit_moment_tags(uuid, uuid) to authenticated;

create or replace function private.can_reorder_moment_media(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.can_edit_moment_tags(u, m);
$$;

revoke execute on function private.can_reorder_moment_media(uuid, uuid) from public, anon;
grant execute on function private.can_reorder_moment_media(uuid, uuid) to authenticated;

-- Friends-of-tagged visibility + at least one non-deleted media not blocked with viewer.
-- Ghost / sharing policies intentionally omitted.
create or replace function private.can_view_moment(u uuid, m uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.moments mo
    where mo.id = m
      and mo.deleted_at is null
      and exists (
        select 1
        from public.moment_members t
        where t.moment_id = m
          and not private.is_blocked(u, t.person_id)
          and (
            t.person_id = u
            or private.is_friend(u, t.person_id)
          )
      )
      and exists (
        select 1
        from public.moment_media med
        where med.moment_id = m
          and med.deleted_at is null
          and not private.is_blocked(u, med.uploader_id)
      )
  );
$$;

revoke execute on function private.can_view_moment(uuid, uuid) from public, anon;
grant execute on function private.can_view_moment(uuid, uuid) to authenticated;

create or replace function private.media_visible_to(u uuid, media_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.moment_media med
    where med.id = media_id
      and med.deleted_at is null
      and not private.is_blocked(u, med.uploader_id)
      and private.can_view_moment(u, med.moment_id)
  );
$$;

revoke execute on function private.media_visible_to(uuid, uuid) from public, anon;
grant execute on function private.media_visible_to(uuid, uuid) to authenticated;

-- Read-model capability flags for later client projection (S2/S5).
create or replace function private.moment_capabilities(u uuid, m uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'canView', private.can_view_moment(u, m),
    'canAddMedia', (
      private.can_view_moment(u, m)
      and private.is_moment_tagged(u, m)
    ),
    'canEditTags', (
      private.can_view_moment(u, m)
      and private.can_edit_moment_tags(u, m)
    ),
    'canEditMetadata', (
      private.can_view_moment(u, m)
      and private.is_moment_creator(u, m)
    ),
    'canReorderMedia', (
      private.can_view_moment(u, m)
      and private.can_reorder_moment_media(u, m)
    ),
    'canDeleteMoment', (
      private.can_view_moment(u, m)
      and private.is_moment_creator(u, m)
    ),
    'youContributed', private.is_moment_contributor(u, m),
    'showOpenForAddsChip', (
      private.is_moment_tagged(u, m)
      and not private.is_moment_contributor(u, m)
      and private.can_view_moment(u, m)
    )
  );
$$;

revoke execute on function private.moment_capabilities(uuid, uuid) from public, anon;
grant execute on function private.moment_capabilities(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- SELECT policies (no write policies)
-- ---------------------------------------------------------------------------

create policy moments_select_visible
  on public.moments
  for select
  to authenticated
  using (
    (select auth.uid()) is not null
    and private.can_view_moment((select auth.uid()), id)
  );

-- Members of a viewable Moment; omit faces blocked with the viewer.
create policy moment_members_select_visible
  on public.moment_members
  for select
  to authenticated
  using (
    (select auth.uid()) is not null
    and private.can_view_moment((select auth.uid()), moment_id)
    and (
      person_id = (select auth.uid())
      or not private.is_blocked((select auth.uid()), person_id)
    )
  );

create policy moment_media_select_visible
  on public.moment_media
  for select
  to authenticated
  using (
    (select auth.uid()) is not null
    and private.media_visible_to((select auth.uid()), id)
  );
