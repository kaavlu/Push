-- 0023_moments_rpcs.sql
-- Moments mutation RPCs (Issue #118 / architecture S2 M3).
-- SECURITY DEFINER only; table writes stay RPC-gated (no client write policies).
-- last_activity_at bumps only on create + append. Max 8 active media.
--
-- Rollback (manual): drop functions listed at end of this file.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function private.can_create_moment_from_push(u uuid, push uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.can_view_push(u, push)
    and exists (
      select 1
      from public.pushes p
      where p.id = push
        and p.cancelled_at is null
        and p.expires_at <= now()
    )
    and not exists (
      select 1
      from public.moments m
      where m.push_id = push
    );
$$;

revoke execute on function private.can_create_moment_from_push(uuid, uuid) from public, anon;
grant execute on function private.can_create_moment_from_push(uuid, uuid) to authenticated;

-- Dense 0..n-1 sort_order among non-deleted media (cover = 0).
create or replace function private.renumber_moment_media(p_moment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  with ordered as (
    select
      id,
      (row_number() over (order by sort_order, created_at, id) - 1)::integer as new_order
    from public.moment_media
    where moment_id = p_moment_id
      and deleted_at is null
  )
  update public.moment_media med
  set sort_order = ordered.new_order
  from ordered
  where med.id = ordered.id
    and med.sort_order is distinct from ordered.new_order;
end;
$$;

revoke execute on function private.renumber_moment_media(uuid) from public, anon;
-- Internal only; still grant authenticated for policy-eval consistency with other private helpers.
grant execute on function private.renumber_moment_media(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- create_moment
-- p_media: jsonb array of objects:
--   { "kind": "photo"|"video", "storage_path": "...", "public_url": "...",
--     "poster_path"?: "...", "poster_url"?: "..." }
-- ---------------------------------------------------------------------------

create or replace function public.create_moment(
  p_title text,
  p_location_text text,
  p_push_id uuid default null,
  p_tag_ids uuid[] default '{}',
  p_media jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  v_moment_id uuid := gen_random_uuid();
  -- clock_timestamp: distinguishable activity times within one client transaction.
  now_ts timestamptz := clock_timestamp();
  title_text text := left(coalesce(trim(p_title), ''), 80);
  loc_text text := left(coalesce(trim(p_location_text), ''), 80);
  tag_id uuid;
  media_count int;
  media_item jsonb;
  idx int := 0;
  v_kind text;
  v_path text;
  v_url text;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  if p_media is null or jsonb_typeof(p_media) <> 'array' then
    raise exception 'media required';
  end if;

  media_count := jsonb_array_length(p_media);
  if media_count < 1 then
    raise exception 'media required';
  end if;
  if media_count > 8 then
    raise exception 'media limit exceeded';
  end if;

  if p_push_id is not null then
    if exists (select 1 from public.moments m where m.push_id = p_push_id) then
      raise exception 'moment exists for push';
    end if;
    if not private.can_create_moment_from_push(me, p_push_id) then
      raise exception 'invalid push';
    end if;
  end if;

  insert into public.moments (
    id,
    creator_id,
    title,
    location_text,
    push_id,
    published_at,
    last_activity_at,
    created_at,
    updated_at
  ) values (
    v_moment_id,
    me,
    title_text,
    loc_text,
    p_push_id,
    now_ts,
    now_ts,
    now_ts,
    now_ts
  );

  -- Creator always tagged.
  insert into public.moment_members (moment_id, person_id, tagged_at)
  values (v_moment_id, me, now_ts);

  if p_tag_ids is not null then
    foreach tag_id in array p_tag_ids
    loop
      if tag_id is null or tag_id = me then
        continue;
      end if;
      if private.is_blocked(me, tag_id) then
        raise exception 'invalid tag';
      end if;
      if not private.is_friend(me, tag_id) then
        raise exception 'invalid tag';
      end if;
      insert into public.moment_members (moment_id, person_id, tagged_at)
      values (v_moment_id, tag_id, now_ts)
      on conflict (moment_id, person_id) do nothing;
    end loop;
  end if;

  for media_item in
    select value from jsonb_array_elements(p_media)
  loop
    v_kind := media_item->>'kind';
    v_path := media_item->>'storage_path';
    v_url := media_item->>'public_url';

    if v_kind is null or v_kind not in ('photo', 'video') then
      raise exception 'invalid media kind';
    end if;
    if v_path is null or length(trim(v_path)) = 0 then
      raise exception 'invalid media path';
    end if;
    if v_url is null or length(trim(v_url)) = 0 then
      raise exception 'invalid media url';
    end if;

    insert into public.moment_media (
      moment_id,
      uploader_id,
      kind,
      storage_path,
      public_url,
      poster_path,
      poster_url,
      sort_order,
      created_at
    ) values (
      v_moment_id,
      me,
      v_kind,
      trim(v_path),
      trim(v_url),
      nullif(trim(coalesce(media_item->>'poster_path', '')), ''),
      nullif(trim(coalesce(media_item->>'poster_url', '')), ''),
      idx,
      now_ts
    );
    idx := idx + 1;
  end loop;

  return v_moment_id;
end;
$$;

revoke all on function public.create_moment(text, text, uuid, uuid[], jsonb) from public, anon;
grant execute on function public.create_moment(text, text, uuid, uuid[], jsonb) to authenticated;

comment on function public.create_moment(text, text, uuid, uuid[], jsonb) is
  'Publish a Moment with ≥1 media. Optional push_id (one Moment per Push). Bumps last_activity_at.';

-- ---------------------------------------------------------------------------
-- append_moment_media
-- ---------------------------------------------------------------------------

create or replace function public.append_moment_media(
  p_moment_id uuid,
  p_kind text,
  p_storage_path text,
  p_public_url text,
  p_poster_path text default null,
  p_poster_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  v_media_id uuid := gen_random_uuid();
  active_count int;
  next_order int;
  now_ts timestamptz := clock_timestamp();
  locked_id uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if p_moment_id is null then
    raise exception 'not found';
  end if;
  if p_kind is null or p_kind not in ('photo', 'video') then
    raise exception 'invalid media kind';
  end if;
  if p_storage_path is null or length(trim(p_storage_path)) = 0 then
    raise exception 'invalid media path';
  end if;
  if p_public_url is null or length(trim(p_public_url)) = 0 then
    raise exception 'invalid media url';
  end if;

  -- Lock moment row for concurrent append / cap.
  select m.id into locked_id
  from public.moments m
  where m.id = p_moment_id
    and m.deleted_at is null
  for update;

  if locked_id is null then
    raise exception 'not found';
  end if;

  if not private.is_moment_tagged(me, p_moment_id) then
    raise exception 'not allowed';
  end if;

  select count(*)::int into active_count
  from public.moment_media med
  where med.moment_id = p_moment_id
    and med.deleted_at is null;

  if active_count >= 8 then
    raise exception 'media limit exceeded';
  end if;

  select coalesce(max(med.sort_order) + 1, 0) into next_order
  from public.moment_media med
  where med.moment_id = p_moment_id
    and med.deleted_at is null;

  insert into public.moment_media (
    id,
    moment_id,
    uploader_id,
    kind,
    storage_path,
    public_url,
    poster_path,
    poster_url,
    sort_order,
    created_at
  ) values (
    v_media_id,
    p_moment_id,
    me,
    p_kind,
    trim(p_storage_path),
    trim(p_public_url),
    nullif(trim(coalesce(p_poster_path, '')), ''),
    nullif(trim(coalesce(p_poster_url, '')), ''),
    next_order,
    now_ts
  );

  update public.moments
  set
    last_activity_at = now_ts,
    updated_at = now_ts
  where id = p_moment_id;

  return v_media_id;
end;
$$;

revoke all on function public.append_moment_media(uuid, text, text, text, text, text)
  from public, anon;
grant execute on function public.append_moment_media(uuid, text, text, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- update_moment_metadata
-- ---------------------------------------------------------------------------

create or replace function public.update_moment_metadata(
  p_moment_id uuid,
  p_title text,
  p_location_text text
)
returns public.moments
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  result public.moments;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.moments m
    where m.id = p_moment_id and m.deleted_at is null
  ) then
    raise exception 'not found';
  end if;

  if not private.is_moment_creator(me, p_moment_id) then
    raise exception 'not allowed';
  end if;

  update public.moments
  set
    title = left(coalesce(trim(p_title), ''), 80),
    location_text = left(coalesce(trim(p_location_text), ''), 80),
    updated_at = now()
    -- last_activity_at intentionally unchanged
  where id = p_moment_id
    and deleted_at is null
  returning * into result;

  if result.id is null then
    raise exception 'not found';
  end if;

  return result;
end;
$$;

revoke all on function public.update_moment_metadata(uuid, text, text) from public, anon;
grant execute on function public.update_moment_metadata(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- add_moment_members
-- ---------------------------------------------------------------------------

create or replace function public.add_moment_members(
  p_moment_id uuid,
  p_person_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  person uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.moments m
    where m.id = p_moment_id and m.deleted_at is null
  ) then
    raise exception 'not found';
  end if;

  if not private.can_edit_moment_tags(me, p_moment_id) then
    raise exception 'not allowed';
  end if;

  if p_person_ids is null then
    return;
  end if;

  foreach person in array p_person_ids
  loop
    if person is null or person = me then
      continue;
    end if;
    if private.is_blocked(me, person) then
      raise exception 'invalid tag';
    end if;
    -- Allow re-adding the creator (no-op via unique) or friends of the actor.
    if not private.is_moment_creator(person, p_moment_id)
       and not private.is_friend(me, person) then
      raise exception 'invalid tag';
    end if;

    insert into public.moment_members (moment_id, person_id, tagged_at)
    values (p_moment_id, person, now())
    on conflict (moment_id, person_id) do nothing;
  end loop;

  update public.moments
  set updated_at = now()
  where id = p_moment_id;
end;
$$;

revoke all on function public.add_moment_members(uuid, uuid[]) from public, anon;
grant execute on function public.add_moment_members(uuid, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- remove_moment_member (others or self-remove)
-- ---------------------------------------------------------------------------

create or replace function public.remove_moment_member(
  p_moment_id uuid,
  p_person_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  creator uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if p_person_id is null then
    raise exception 'invalid target';
  end if;

  if not exists (
    select 1 from public.moments m
    where m.id = p_moment_id and m.deleted_at is null
  ) then
    raise exception 'not found';
  end if;

  select creator_id into creator
  from public.moments
  where id = p_moment_id;

  if p_person_id = creator then
    raise exception 'cannot remove creator';
  end if;

  if p_person_id = me then
    -- Self-remove: tagged non-creator only.
    if not private.is_moment_tagged(me, p_moment_id) then
      raise exception 'not allowed';
    end if;
  else
    if not private.can_edit_moment_tags(me, p_moment_id) then
      raise exception 'not allowed';
    end if;
  end if;

  delete from public.moment_members
  where moment_id = p_moment_id
    and person_id = p_person_id;

  update public.moments
  set updated_at = now()
  where id = p_moment_id;
end;
$$;

revoke all on function public.remove_moment_member(uuid, uuid) from public, anon;
grant execute on function public.remove_moment_member(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- reorder_moment_media
-- ---------------------------------------------------------------------------

create or replace function public.reorder_moment_media(
  p_moment_id uuid,
  p_ordered_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  active_count int;
  id_count int;
  i int;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.moments m
    where m.id = p_moment_id and m.deleted_at is null
  ) then
    raise exception 'not found';
  end if;

  perform 1 from public.moments m where m.id = p_moment_id for update;

  if not private.can_reorder_moment_media(me, p_moment_id) then
    raise exception 'not allowed';
  end if;

  select count(*)::int into active_count
  from public.moment_media
  where moment_id = p_moment_id
    and deleted_at is null;

  if p_ordered_ids is null then
    raise exception 'conflict';
  end if;

  id_count := coalesce(array_length(p_ordered_ids, 1), 0);
  if id_count <> active_count then
    raise exception 'conflict';
  end if;

  -- Exact set equality: every id active on moment, no dupes.
  if (
    select count(distinct x)
    from unnest(p_ordered_ids) as x
  ) <> id_count then
    raise exception 'conflict';
  end if;

  if (
    select count(*)::int
    from public.moment_media med
    where med.moment_id = p_moment_id
      and med.deleted_at is null
      and med.id = any (p_ordered_ids)
  ) <> active_count then
    raise exception 'conflict';
  end if;

  for i in 1 .. id_count
  loop
    update public.moment_media
    set sort_order = i - 1
    where id = p_ordered_ids[i]
      and moment_id = p_moment_id
      and deleted_at is null;
  end loop;

  update public.moments
  set updated_at = now()
  where id = p_moment_id;
end;
$$;

revoke all on function public.reorder_moment_media(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_moment_media(uuid, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- soft_delete_moment_media
-- ---------------------------------------------------------------------------

create or replace function public.soft_delete_moment_media(p_media_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  med public.moment_media;
  remaining int;
  now_ts timestamptz := now();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into med
  from public.moment_media
  where id = p_media_id
    and deleted_at is null;

  if med.id is null then
    raise exception 'not found';
  end if;

  if not exists (
    select 1 from public.moments m
    where m.id = med.moment_id and m.deleted_at is null
  ) then
    raise exception 'not found';
  end if;

  perform 1 from public.moments m where m.id = med.moment_id for update;

  if med.uploader_id <> me and not private.is_moment_creator(me, med.moment_id) then
    raise exception 'not allowed';
  end if;

  update public.moment_media
  set deleted_at = now_ts
  where id = p_media_id
    and deleted_at is null;

  perform private.renumber_moment_media(med.moment_id);

  select count(*)::int into remaining
  from public.moment_media
  where moment_id = med.moment_id
    and deleted_at is null;

  if remaining = 0 then
    update public.moments
    set
      deleted_at = now_ts,
      updated_at = now_ts
    where id = med.moment_id
      and deleted_at is null;
  else
    update public.moments
    set updated_at = now_ts
    where id = med.moment_id;
  end if;
end;
$$;

revoke all on function public.soft_delete_moment_media(uuid) from public, anon;
grant execute on function public.soft_delete_moment_media(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- soft_delete_moment
-- ---------------------------------------------------------------------------

create or replace function public.soft_delete_moment(p_moment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.moments m
    where m.id = p_moment_id and m.deleted_at is null
  ) then
    raise exception 'not found';
  end if;

  if not private.is_moment_creator(me, p_moment_id) then
    raise exception 'not allowed';
  end if;

  update public.moments
  set
    deleted_at = now(),
    updated_at = now()
  where id = p_moment_id
    and deleted_at is null;
end;
$$;

revoke all on function public.soft_delete_moment(uuid) from public, anon;
grant execute on function public.soft_delete_moment(uuid) to authenticated;

comment on function public.soft_delete_moment(uuid) is
  'Creator soft-delete. Keeps push_id so the one-Moment-per-Push slot remains consumed.';
