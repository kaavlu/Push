-- 0025_moment_media_path_validation.sql
-- Server-side ownership validation for Moment media paths (Issue #119, S3).
--
-- Gap this closes: Storage RLS (0024) stops a caller uploading outside their own
-- `pending/{uid}/…` folder or a Moment they are tagged in, but the S2 RPCs took
-- `storage_path` / `public_url` as opaque strings. Nothing stopped a caller from
-- registering *someone else's* object — their own pending upload, or media from a
-- Moment the caller cannot see — inside a Moment of their own, republishing it to
-- their audience. Authorization must be server-side, so `create_moment` and
-- `append_moment_media` now validate every path against `storage.objects`.
--
-- Each media/poster path must:
--   1. resolve to an existing object in the `moment-media` bucket,
--   2. be owned by auth.uid() (`storage.objects.owner_id`),
--   3. sit at an allowed key — `pending/{auth.uid()}/{file}` always, or
--      `{moment_id}/{file}` for appends to that Moment,
--   4. carry a mime type matching the submitted kind (poster ⇒ image),
--   5. not already be registered by an active `moment_media` row.
--
-- `public_url` / `poster_url` are now **derived** from the validated path. The
-- RPC arguments are kept for signature stability but their values are ignored —
-- a caller can no longer point a validated path at an arbitrary URL.
--
-- Public-bucket caveat (documented, not fixed here): `moment-media` is public,
-- so a validated object is served by CDN to anyone holding the URL. Blocking a
-- user, untagging them, or soft-deleting a Moment stops future URL *discovery*
-- through Push, but cannot revoke a URL someone already copied. Hard revocation
-- would need a private bucket plus signed URLs on every read; that is deferred
-- unless the product contract demands it (contract §4 does not).

-- ---------------------------------------------------------------------------
-- Public URL derivation
-- ---------------------------------------------------------------------------

-- Override per environment with:
--   alter database postgres set app.settings.storage_public_base_url = '…';
create or replace function private.storage_public_base_url()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('app.settings.storage_public_base_url', true), ''),
    'https://tzzvwjhvjduyqywlszqc.supabase.co'
  );
$$;

revoke execute on function private.storage_public_base_url() from public, anon;
grant execute on function private.storage_public_base_url() to authenticated;

create or replace function private.moment_media_public_url(p_path text)
returns text
language sql
stable
set search_path = ''
as $$
  select private.storage_public_base_url()
    || '/storage/v1/object/public/'
    || 'moment-media/'
    || p_path;
$$;

revoke execute on function private.moment_media_public_url(text) from public, anon;
grant execute on function private.moment_media_public_url(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Path validation
-- ---------------------------------------------------------------------------

-- Validates one media or poster object and returns its trimmed key.
-- `p_expected_kind`: 'photo' | 'video' | 'poster'.
-- `p_moment_id`: null for create (pending keys only — the moment id does not
-- exist yet, so no object can legitimately sit under it); the target moment for
-- appends, which additionally allows `{moment_id}/…`.
-- Raises on every failure; never returns null.
create or replace function private.validate_moment_media_path(
  u uuid,
  p_moment_id uuid,
  p_path text,
  p_expected_kind text
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_path text := trim(coalesce(p_path, ''));
  v_folders text[];
  v_depth int;
  v_mime text;
  v_allowed text[];
begin
  if length(v_path) = 0 then
    raise exception 'invalid media path';
  end if;

  v_folders := storage.foldername(v_path);
  v_depth := coalesce(array_length(v_folders, 1), 0);

  -- Allowed layouts only: `pending/{uid}/{file}` or `{moment_id}/{file}`.
  if not (
    (v_depth = 2 and v_folders[1] = 'pending' and v_folders[2] = u::text)
    or (
      v_depth = 1
      and p_moment_id is not null
      and v_folders[1] = p_moment_id::text
    )
  ) then
    raise exception 'invalid media path';
  end if;

  -- Must be a real object in this bucket, owned by the caller.
  select o.metadata->>'mimetype' into v_mime
  from storage.objects o
  where o.bucket_id = 'moment-media'
    and o.name = v_path
    and o.owner_id = u::text;

  if not found then
    raise exception 'invalid media path';
  end if;

  v_allowed := case p_expected_kind
    when 'video' then array['video/mp4', 'video/quicktime']
    else array['image/jpeg', 'image/png', 'image/webp']
  end;

  if v_mime is null or not (v_mime = any (v_allowed)) then
    raise exception 'media type mismatch';
  end if;

  -- One object belongs to at most one active media row.
  if exists (
    select 1
    from public.moment_media med
    where med.deleted_at is null
      and (med.storage_path = v_path or med.poster_path = v_path)
  ) then
    raise exception 'media already registered';
  end if;

  return v_path;
end;
$$;

revoke execute on function private.validate_moment_media_path(uuid, uuid, text, text)
  from public, anon;
grant execute on function private.validate_moment_media_path(uuid, uuid, text, text)
  to authenticated;

-- Backstop for the check above under concurrency (two sessions validating the
-- same key before either inserts). Partial: soft-deleted rows free the key.
create unique index if not exists moment_media_active_storage_path_key
  on public.moment_media (storage_path)
  where deleted_at is null;

create unique index if not exists moment_media_active_poster_path_key
  on public.moment_media (poster_path)
  where deleted_at is null and poster_path is not null;

-- ---------------------------------------------------------------------------
-- create_moment — validates each media/poster path, derives URLs
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
  v_poster_path text;
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
    if v_kind is null or v_kind not in ('photo', 'video') then
      raise exception 'invalid media kind';
    end if;

    -- Publish uploads land in the caller's pending prefix; the moment id did
    -- not exist when they were uploaded, so `{moment_id}/…` is not accepted here.
    v_path := private.validate_moment_media_path(
      me, null, media_item->>'storage_path', v_kind
    );

    v_poster_path := nullif(trim(coalesce(media_item->>'poster_path', '')), '');
    if v_poster_path is not null then
      v_poster_path := private.validate_moment_media_path(
        me, null, v_poster_path, 'poster'
      );
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
      v_path,
      private.moment_media_public_url(v_path),
      v_poster_path,
      case when v_poster_path is null
        then null
        else private.moment_media_public_url(v_poster_path)
      end,
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
  'Publish a Moment with ≥1 media. Media paths must be caller-owned moment-media '
  'objects under pending/{uid}/…; public URLs are derived server-side and any '
  'caller-supplied public_url is ignored. Optional push_id (one Moment per Push).';

-- ---------------------------------------------------------------------------
-- append_moment_media — same validation, `{moment_id}/…` also allowed
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
  v_path text;
  v_poster_path text;
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

  -- After the membership check: path errors must not leak Moment contents.
  v_path := private.validate_moment_media_path(
    me, p_moment_id, p_storage_path, p_kind
  );

  v_poster_path := nullif(trim(coalesce(p_poster_path, '')), '');
  if v_poster_path is not null then
    v_poster_path := private.validate_moment_media_path(
      me, p_moment_id, v_poster_path, 'poster'
    );
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
    v_path,
    private.moment_media_public_url(v_path),
    v_poster_path,
    case when v_poster_path is null
      then null
      else private.moment_media_public_url(v_poster_path)
    end,
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

comment on function public.append_moment_media(uuid, text, text, text, text, text) is
  'Add yours append. Path must be a caller-owned moment-media object under '
  'pending/{uid}/… or {moment_id}/…; public URLs are derived server-side and the '
  'p_public_url / p_poster_url arguments are ignored (kept for signature stability).';
