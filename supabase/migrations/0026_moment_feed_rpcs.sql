-- 0026_moment_feed_rpcs.sql
-- Moment read RPCs (Issue #122 / architecture S5 M5).
--
-- Why RPCs rather than PostgREST + RLS: one Feed row needs the Moment, its
-- ordered tag ids, its *viewer-visible* media, a viewer-visible count, and the
-- capability flags — plus keyset pagination and a group predicate. Embedding
-- all of that in a single stable DTO keeps the client from issuing N+1 reads
-- and keeps visibility decisions server-side (architecture §14.1).
--
-- No schema changes; no mutation-RPC changes. Reads only.
--
-- Rollback (manual):
--   drop function if exists public.moment_detail(uuid);
--   drop function if exists public.hub_moments(int);
--   drop function if exists public.feed_moments(timestamptz, uuid, int, uuid);
--   drop function if exists private.moment_dto(uuid, uuid);

-- ---------------------------------------------------------------------------
-- DTO builder
-- ---------------------------------------------------------------------------
-- Viewer-scoped projection of one Moment. Blocked people are dropped from the
-- tag list and their media is omitted, so the client never has to re-filter.
-- Tag order is creator first, then tag time — the order the app renders.
create or replace function private.moment_dto(u uuid, p_moment_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', mo.id,
    'creator_id', mo.creator_id,
    'title', mo.title,
    'location_text', mo.location_text,
    'place_id', mo.place_id,
    'push_id', mo.push_id,
    'published_at', mo.published_at,
    'last_activity_at', mo.last_activity_at,
    'tagged_person_ids', coalesce(
      (
        select jsonb_agg(
          t.person_id
          order by (t.person_id = mo.creator_id) desc, t.tagged_at, t.id
        )
        from public.moment_members t
        where t.moment_id = mo.id
          and not private.is_blocked(u, t.person_id)
      ),
      '[]'::jsonb
    ),
    'media', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', med.id,
            'moment_id', med.moment_id,
            'uploader_id', med.uploader_id,
            'kind', med.kind,
            'storage_path', med.storage_path,
            'public_url', med.public_url,
            'poster_path', med.poster_path,
            'poster_url', med.poster_url,
            'sort_order', med.sort_order,
            'created_at', med.created_at
          )
          order by med.sort_order, med.created_at, med.id
        )
        from public.moment_media med
        where med.moment_id = mo.id
          and med.deleted_at is null
          and not private.is_blocked(u, med.uploader_id)
      ),
      '[]'::jsonb
    ),
    -- Viewer-visible count, not the global one (contract §7.6).
    'visible_media_count', (
      select count(*)
      from public.moment_media med
      where med.moment_id = mo.id
        and med.deleted_at is null
        and not private.is_blocked(u, med.uploader_id)
    ),
    'capabilities', private.moment_capabilities(u, mo.id)
  )
  from public.moments mo
  where mo.id = p_moment_id
    and mo.deleted_at is null;
$$;

revoke execute on function private.moment_dto(uuid, uuid) from public, anon;
grant execute on function private.moment_dto(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- feed_moments — Feed › Pushes
-- ---------------------------------------------------------------------------
-- Keyset pagination on (last_activity_at, id) desc — the same key as
-- `moments_feed_activity_idx`, so pages stay stable while new Moments arrive
-- at the head. Pass both cursor parts or neither.
create or replace function public.feed_moments(
  p_cursor_activity timestamptz default null,
  p_cursor_id uuid default null,
  p_limit int default 10,
  p_group_id uuid default null
)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.moment_dto((select auth.uid()), mo.id)
  from public.moments mo
  where (select auth.uid()) is not null
    and mo.deleted_at is null
    and private.can_view_moment((select auth.uid()), mo.id)
    and (
      p_cursor_activity is null
      or p_cursor_id is null
      or (mo.last_activity_at, mo.id) < (p_cursor_activity, p_cursor_id)
    )
    -- Group chips: the viewer and at least one tagged member must both be
    -- active members of *this* group. `private.shares_group` is deliberately
    -- not used — it is true for any shared group, which would leak Moments
    -- into chips they do not belong to. Self-inclusive by construction (a
    -- Moment the viewer is tagged in matches every group they belong to),
    -- matching `LocalMomentRepository`.
    and (
      p_group_id is null
      or (
        exists (
          select 1
          from public.group_memberships gv
          where gv.group_id = p_group_id
            and gv.person_id = (select auth.uid())
            and gv.membership_status = 'active'
        )
        and exists (
          select 1
          from public.moment_members t
          join public.group_memberships gm
            on gm.group_id = p_group_id
           and gm.person_id = t.person_id
           and gm.membership_status = 'active'
          where t.moment_id = mo.id
        )
      )
    )
  order by mo.last_activity_at desc, mo.id desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

revoke all on function public.feed_moments(timestamptz, uuid, int, uuid) from public, anon;
grant execute on function public.feed_moments(timestamptz, uuid, int, uuid) to authenticated;

comment on function public.feed_moments(timestamptz, uuid, int, uuid) is
  'Feed page of viewable Moments, newest activity first, keyset-paginated on (last_activity_at, id). Media and tags are block-filtered for the caller.';

-- ---------------------------------------------------------------------------
-- hub_moments — created ∪ tagged ∪ contributed
-- ---------------------------------------------------------------------------
create or replace function public.hub_moments(p_limit int default 50)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.moment_dto((select auth.uid()), mo.id)
  from public.moments mo
  where (select auth.uid()) is not null
    and mo.deleted_at is null
    and private.can_view_moment((select auth.uid()), mo.id)
    and (
      mo.creator_id = (select auth.uid())
      or private.is_moment_tagged((select auth.uid()), mo.id)
      or private.is_moment_contributor((select auth.uid()), mo.id)
    )
  order by mo.last_activity_at desc, mo.id desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

revoke all on function public.hub_moments(int) from public, anon;
grant execute on function public.hub_moments(int) to authenticated;

comment on function public.hub_moments(int) is
  'Moments the caller created, is tagged in, or contributed media to — newest activity first.';

-- ---------------------------------------------------------------------------
-- moment_detail — single album for edit / Add yours
-- ---------------------------------------------------------------------------
create or replace function public.moment_detail(p_moment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  -- Same error for missing and invisible: never confirm a Moment exists to
  -- someone with no visibility path.
  if p_moment_id is null or not private.can_view_moment(me, p_moment_id) then
    raise exception 'not found';
  end if;

  return private.moment_dto(me, p_moment_id);
end;
$$;

revoke all on function public.moment_detail(uuid) from public, anon;
grant execute on function public.moment_detail(uuid) to authenticated;

comment on function public.moment_detail(uuid) is
  'One viewable Moment with ordered tags, viewer-visible media, and capability flags. Raises not found when no visibility path exists.';
