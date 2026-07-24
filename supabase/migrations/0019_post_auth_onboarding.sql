-- 0019_post_auth_onboarding.sql
-- First-run setup after auth: sharing defaults, completion flag, people discovery.
-- Existing profiles are marked complete so only new accounts see the flow.

-- ---------------------------------------------------------------------------
-- profiles.onboarding_completed_at
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists onboarding_completed_at timestamptz;

-- Existing accounts skip the new multi-step setup.
update public.profiles
set onboarding_completed_at = coalesce(onboarding_completed_at, now())
where onboarding_completed_at is null;

-- ---------------------------------------------------------------------------
-- Upsert the caller's global_default sharing policy (R3 visibility source).
-- ---------------------------------------------------------------------------
create or replace function public.set_global_sharing_defaults(
  p_location_visibility text,
  p_activity_visibility text,
  p_availability_visibility text
)
returns public.sharing_policies
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  row public.sharing_policies;
  updated int;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if p_location_visibility not in ('exact', 'vague', 'hidden') then
    raise exception 'invalid location_visibility';
  end if;
  if p_activity_visibility not in ('full', 'vague', 'hidden') then
    raise exception 'invalid activity_visibility';
  end if;
  if p_availability_visibility not in ('full', 'hidden') then
    raise exception 'invalid availability_visibility';
  end if;

  update public.sharing_policies
  set
    location_visibility = p_location_visibility,
    activity_visibility = p_activity_visibility,
    availability_visibility = p_availability_visibility,
    audience_id = null
  where owner_person_id = uid
    and audience_type = 'global_default';

  get diagnostics updated = row_count;

  if updated = 0 then
    insert into public.sharing_policies (
      owner_person_id,
      audience_type,
      audience_id,
      location_visibility,
      activity_visibility,
      availability_visibility
    )
    values (
      uid,
      'global_default',
      null,
      p_location_visibility,
      p_activity_visibility,
      p_availability_visibility
    )
    returning * into row;
    return row;
  end if;

  select * into row
  from public.sharing_policies
  where owner_person_id = uid
    and audience_type = 'global_default'
  order by id
  limit 1;

  return row;
end;
$$;

revoke all on function public.set_global_sharing_defaults(text, text, text) from public, anon;
grant execute on function public.set_global_sharing_defaults(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Mark onboarding finished (idempotent).
-- ---------------------------------------------------------------------------
create or replace function public.complete_onboarding()
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  row public.profiles;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  update public.profiles
  set onboarding_completed_at = coalesce(onboarding_completed_at, now())
  where id = uid
  returning * into row;

  if row.id is null then
    raise exception 'profile not found';
  end if;

  return row;
end;
$$;

revoke all on function public.complete_onboarding() from public, anon;
grant execute on function public.complete_onboarding() to authenticated;

-- ---------------------------------------------------------------------------
-- People already on Push (for first-run find-friends). Public fields only.
-- Excludes self, blocks, and accepted friends.
-- ---------------------------------------------------------------------------
create or replace function public.discover_profiles(result_limit int default 20)
returns table (
  id uuid,
  first_name text,
  handle text,
  image_asset_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.first_name, p.handle, p.image_asset_path
  from public.profiles p
  where (select auth.uid()) is not null
    and p.id <> (select auth.uid())
    and not private.is_blocked((select auth.uid()), p.id)
    and not private.is_friend((select auth.uid()), p.id)
  order by p.created_at desc, p.handle
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

revoke all on function public.discover_profiles(int) from public, anon;
grant execute on function public.discover_profiles(int) to authenticated;
