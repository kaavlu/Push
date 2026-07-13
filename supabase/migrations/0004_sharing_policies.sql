-- 0004_sharing_policies.sql
-- The single source of truth for presence visibility (spec R3). Resolution order
-- (friend -> group -> global_default) is applied client-side by VisiblePresenceBuilder.
create table public.sharing_policies (
  id uuid primary key default gen_random_uuid(),
  owner_person_id uuid not null references public.profiles (id) on delete cascade,
  audience_type text not null check (audience_type in ('friend', 'group', 'global_default')),
  audience_id uuid,
  location_visibility text not null default 'exact'
    check (location_visibility in ('exact', 'vague', 'hidden')),
  activity_visibility text not null default 'full'
    check (activity_visibility in ('full', 'vague', 'hidden')),
  availability_visibility text not null default 'full'
    check (availability_visibility in ('full', 'hidden')),
  expires_at timestamptz
);
create index sharing_policies_owner_idx on public.sharing_policies (owner_person_id);

alter table public.sharing_policies enable row level security;

-- You can read a policy if you own it, or if you are its audience:
--   a friend policy targeting you, a group policy for a group you're in,
--   or a global default owned by a friend.
create policy sharing_policies_select_relevant on public.sharing_policies
  for select using (
    owner_person_id = (select auth.uid())
    or (audience_type = 'friend' and audience_id = (select auth.uid()))
    or (audience_type = 'group' and private.is_group_member((select auth.uid()), audience_id))
    or (audience_type = 'global_default' and private.is_friend((select auth.uid()), owner_person_id))
  );
