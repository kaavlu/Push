-- 0018_current_presence.sql
-- Canonical friend-visible presence (Issue #71 / architecture PR4).
-- One row per user. is_published is orthogonal to availability (Ghost ≠ availability).
-- Friend SELECT: graph (friend or co-member) + not blocked + published + not expired
-- (+ legacy availability <> 'ghost'). No seed/mock presence rows.
--
-- Rollback (manual):
--   drop function if exists public.set_availability_choice(text);
--   drop function if exists public.unpublish_current_presence();
--   drop table if exists public.current_presence;

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table public.current_presence (
  user_id uuid primary key references public.profiles (id) on delete cascade,

  -- Denormalized mirror of profiles.availability_choice (not Ghost authority).
  -- 'ghost' allowed only for transitional reads / legacy dual-write compatibility.
  availability text not null default 'free_now'
    check (availability in (
      'free_now', 'free_soon', 'maybe_down', 'busy',
      'joinable', 'driving', 'unavailable', 'ghost'
    )),

  -- Orthogonal publish flag. Default false: unpublished until the client publishes.
  is_published boolean not null default false,

  activity_name text not null default '',
  activity_symbol text not null default '',
  place_id text,
  status_note text,

  -- Exact coordinates (null when unpublished / never fixed).
  latitude double precision,
  longitude double precision,
  -- Optional vague coordinates; client may synthesize when null.
  vague_latitude double precision,
  vague_longitude double precision,

  confidence text not null default 'medium'
    check (confidence in ('high', 'medium', 'low')),

  observed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Required when published (Phase 1 hard-expiry backstop). Nullable when unpublished.
  expires_at timestamptz,

  -- Domain PresenceStatus.Source as snake_case (manualOverride → manual_override).
  source text not null default 'location'
    check (source in ('seed', 'location', 'manual_override', 'inference')),

  constraint current_presence_latitude_range
    check (latitude is null or (latitude >= -90 and latitude <= 90)),
  constraint current_presence_longitude_range
    check (longitude is null or (longitude >= -180 and longitude <= 180)),
  constraint current_presence_vague_latitude_range
    check (vague_latitude is null or (vague_latitude >= -90 and vague_latitude <= 90)),
  constraint current_presence_vague_longitude_range
    check (vague_longitude is null or (vague_longitude >= -180 and vague_longitude <= 180)),
  -- Pair integrity: lat/lng both set or both null (exact and vague independently).
  constraint current_presence_exact_coords_pair
    check ((latitude is null) = (longitude is null)),
  constraint current_presence_vague_coords_pair
    check ((vague_latitude is null) = (vague_longitude is null)),
  -- Published rows must carry an expiry; unpublish may set expires_at = now().
  constraint current_presence_published_requires_expiry
    check (is_published = false or expires_at is not null)
);

comment on table public.current_presence is
  'Canonical friend-visible current presence; one row per user. Availability is a mirror of profiles.availability_choice; is_published is orthogonal Ghost/publish state.';

comment on column public.current_presence.is_published is
  'Orthogonal presence publish flag. Ghost is this flag (false), not availability.';

comment on column public.current_presence.availability is
  'Denormalized mirror of profiles.availability_choice for friend reads. Not authority for Ghost.';

comment on column public.current_presence.place_id is
  'Reserved for places catalog (Phase 1b+); unused in Phase 1a synthetic Place mapping.';

-- Indexes: PK covers user lookup. Partial index supports friend-visible filters + Realtime later.
create index current_presence_published_expires_idx
  on public.current_presence (expires_at)
  where is_published = true;

create index current_presence_updated_at_idx
  on public.current_presence (updated_at desc);

alter table public.current_presence enable row level security;

-- Table is not publicly readable. Prefer explicit grants (Supabase may auto-grant on public).
revoke all on table public.current_presence from public, anon;
grant select, insert, update on table public.current_presence to authenticated;
-- No DELETE grant: unpublish via RPC; row removed by profiles FK cascade on account delete.

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

-- Self: full read of own row (published or not, expired or not) for app state.
create policy current_presence_select_self on public.current_presence
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Friends / co-members: only published, non-expired, non-blocked, non-legacy-ghost.
-- Approach B (architecture §2.6): return full allowed rows; client VisiblePresenceBuilder
-- applies sharing-policy projection. Coordinates stay private from unauthorized users via RLS.
create policy current_presence_select_friend_visible on public.current_presence
  for select
  to authenticated
  using (
    (select auth.uid()) is not null
    and (select auth.uid()) <> user_id
    and is_published = true
    and expires_at is not null
    and expires_at > now()
    and availability <> 'ghost'
    and not private.is_blocked((select auth.uid()), user_id)
    and (
      private.is_friend((select auth.uid()), user_id)
      or private.shares_group((select auth.uid()), user_id)
    )
  );

-- Self write only. Never insert/update another user's row.
create policy current_presence_insert_self on public.current_presence
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy current_presence_update_self on public.current_presence
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Unpublish RPC (Ghost / permission / sign-out best-effort)
-- ---------------------------------------------------------------------------

create or replace function public.unpublish_current_presence()
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

  -- Best-effort: no-op when the user has never published a row.
  update public.current_presence
  set
    is_published = false,
    latitude = null,
    longitude = null,
    vague_latitude = null,
    vague_longitude = null,
    expires_at = now(),
    updated_at = now()
  where user_id = me;
end;
$$;

revoke all on function public.unpublish_current_presence() from public, anon;
grant execute on function public.unpublish_current_presence() to authenticated;

comment on function public.unpublish_current_presence() is
  'Best-effort self unpublish: is_published=false, null coords, expires_at=now(). Preserves availability mirror.';

-- ---------------------------------------------------------------------------
-- Availability dual-write (canonical profile + presence mirror)
-- ---------------------------------------------------------------------------

create or replace function public.set_availability_choice(p_availability text)
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

  if p_availability is null or p_availability not in (
    'free_now', 'free_soon', 'maybe_down', 'busy',
    'joinable', 'driving', 'unavailable', 'ghost'
  ) then
    raise exception 'invalid availability';
  end if;

  -- Canonical write.
  update public.profiles
  set
    availability_choice = p_availability,
    updated_at = now()
  where id = me;

  if not found then
    raise exception 'profile not found';
  end if;

  -- Mirror only when a presence row already exists. Do not invent a presence row
  -- (location/publish pipeline owns first insert). Preserve coords + is_published.
  update public.current_presence
  set
    availability = p_availability,
    updated_at = now()
  where user_id = me;
end;
$$;

revoke all on function public.set_availability_choice(text) from public, anon;
grant execute on function public.set_availability_choice(text) to authenticated;

comment on function public.set_availability_choice(text) is
  'Transactional dual-write: profiles.availability_choice (canonical) + current_presence.availability mirror when a row exists. Does not change is_published or coordinates. New Ghost writes should use unpublish_current_presence + non-ghost availability; ghost value accepted only for transitional Profile compatibility.';
