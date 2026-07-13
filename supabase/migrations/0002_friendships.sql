-- 0002_friendships.sql
-- Mutual, undirected friendships. One canonical row per pair (user_low < user_high).
--
-- SECURITY DEFINER RLS helpers live in a dedicated `private` schema that is NOT
-- exposed by PostgREST, so they can back RLS policies without becoming callable
-- RPC endpoints. `authenticated` gets usage/execute (required for policy
-- evaluation); anon/public are locked out.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles (id) on delete cascade,
  user_high uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'accepted',
  created_at timestamptz not null default now(),
  constraint friendships_ordered check (user_low < user_high),
  constraint friendships_unique_pair unique (user_low, user_high)
);
create index friendships_user_high_idx on public.friendships (user_high);

alter table public.friendships enable row level security;

-- Hardened helper: true when a and b have an accepted friendship (either order).
create function private.is_friend(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.user_low = a and f.user_high = b)
        or (f.user_low = b and f.user_high = a))
  );
$$;

revoke execute on function private.is_friend(uuid, uuid) from public, anon;
grant execute on function private.is_friend(uuid, uuid) to authenticated;

-- A user can read friendship rows they are part of.
create policy friendships_select_own on public.friendships
  for select using (
    (select auth.uid()) = user_low or (select auth.uid()) = user_high
  );

-- Friends can now read each other's profile.
create policy profiles_select_friends on public.profiles
  for select using (private.is_friend((select auth.uid()), id));
