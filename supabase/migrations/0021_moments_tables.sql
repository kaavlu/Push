-- 0021_moments_tables.sql
-- Moments foundation tables (Issue #117 / architecture S1 M1).
-- Media albums distinct from Pushes (coordination) and FeedEvent (activity).
-- Soft-delete via deleted_at; UNIQUE(push_id) includes soft-deleted rows
-- (at most one Moment per Push forever).
--
-- RLS enabled here; SELECT policies land in 0022 with private helpers.
-- No authenticated INSERT/UPDATE/DELETE policies (mutation RPCs in S2).
--
-- Rollback (manual):
--   drop table if exists public.moment_media;
--   drop table if exists public.moment_members;
--   drop table if exists public.moments;

-- ---------------------------------------------------------------------------
-- moments
-- ---------------------------------------------------------------------------

create table public.moments (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  title text not null default '',
  location_text text not null default '',
  place_id text,
  -- Optional link to a historical Push. Unique including soft-deleted rows.
  push_id uuid references public.pushes (id) on delete set null,
  published_at timestamptz not null default now(),
  -- Bumped on create and successful media append only (enforced by S2 RPCs).
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint moments_push_id_unique unique (push_id)
);

comment on table public.moments is
  'Social Moment (media album) on Feed. Distinct from pushes and activity feed_events. Soft-delete via deleted_at.';

comment on column public.moments.push_id is
  'Optional source Push. UNIQUE includes soft-deleted Moments so the slot stays consumed.';

comment on column public.moments.location_text is
  'Frozen display location; not rewritten by live sharing policies or presence.';

comment on column public.moments.last_activity_at is
  'Feed ordering: max(published_at, last media add). Metadata/tag/reorder do not bump (S2).';

create index moments_creator_id_idx
  on public.moments (creator_id);

create index moments_feed_activity_idx
  on public.moments (last_activity_at desc, id desc)
  where deleted_at is null;

alter table public.moments enable row level security;

revoke all on table public.moments from public, anon;
-- SELECT only for authenticated; writes via S2 SECURITY DEFINER RPCs.
grant select on table public.moments to authenticated;

-- ---------------------------------------------------------------------------
-- moment_members (explicit tags / "With")
-- ---------------------------------------------------------------------------

create table public.moment_members (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments (id) on delete cascade,
  person_id uuid not null references public.profiles (id) on delete cascade,
  tagged_at timestamptz not null default now(),
  constraint moment_members_unique unique (moment_id, person_id)
);

comment on table public.moment_members is
  'Explicit Moment tags (With list). Creator always retained by RPCs (S2); not auto-attendance.';

create index moment_members_person_id_idx
  on public.moment_members (person_id);

create index moment_members_moment_id_idx
  on public.moment_members (moment_id);

alter table public.moment_members enable row level security;

revoke all on table public.moment_members from public, anon;
grant select on table public.moment_members to authenticated;

-- ---------------------------------------------------------------------------
-- moment_media
-- ---------------------------------------------------------------------------

create table public.moment_media (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments (id) on delete cascade,
  uploader_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null
    check (kind in ('photo', 'video')),
  storage_path text not null,
  public_url text not null,
  poster_path text,
  poster_url text,
  -- 0 = cover among non-deleted after dense reorder (S2).
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint moment_media_sort_order_nonnegative check (sort_order >= 0)
);

comment on table public.moment_media is
  'Ordered Moment media. Soft-delete via deleted_at. Cap of 8 active items enforced by S2 RPCs.';

comment on column public.moment_media.sort_order is
  'Global order; cover is sort_order 0 among active rows after reorder.';

create index moment_media_moment_sort_idx
  on public.moment_media (moment_id, sort_order);

create index moment_media_uploader_id_idx
  on public.moment_media (uploader_id);

alter table public.moment_media enable row level security;

revoke all on table public.moment_media from public, anon;
grant select on table public.moment_media to authenticated;
