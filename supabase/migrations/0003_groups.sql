-- 0003_groups.sql
-- Groups + memberships. Membership is about membership only (no visibility column);
-- sharing_policies is the sole source of truth for presence visibility (spec R3).
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  image_asset_path text,
  created_at timestamptz not null default now()
);

create table public.group_memberships (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  role text not null default 'member',
  membership_status text not null default 'active',
  joined_at timestamptz not null default now(),
  constraint group_memberships_unique unique (person_id, group_id)
);
create index group_memberships_group_idx on public.group_memberships (group_id);
create index group_memberships_person_idx on public.group_memberships (person_id);

alter table public.groups enable row level security;
alter table public.group_memberships enable row level security;

-- Hardened helper: is u an active member of group g? (private schema; not RPC-exposed)
create function private.is_group_member(u uuid, g uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_memberships m
    where m.group_id = g and m.person_id = u and m.membership_status = 'active'
  );
$$;
revoke execute on function private.is_group_member(uuid, uuid) from public, anon;
grant execute on function private.is_group_member(uuid, uuid) to authenticated;

-- Hardened helper: do a and b share any active group?
create function private.shares_group(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_memberships ma
    join public.group_memberships mb on ma.group_id = mb.group_id
    where ma.person_id = a and mb.person_id = b
      and ma.membership_status = 'active' and mb.membership_status = 'active'
  );
$$;
revoke execute on function private.shares_group(uuid, uuid) from public, anon;
grant execute on function private.shares_group(uuid, uuid) to authenticated;

-- Read groups you actively belong to.
create policy groups_select_member on public.groups
  for select using (private.is_group_member((select auth.uid()), id));

-- Read memberships of groups you actively belong to (incl. your own row).
create policy group_memberships_select_comember on public.group_memberships
  for select using (private.is_group_member((select auth.uid()), group_id));

-- Co-members can read each other's profile.
create policy profiles_select_group on public.profiles
  for select using (private.shares_group((select auth.uid()), id));
