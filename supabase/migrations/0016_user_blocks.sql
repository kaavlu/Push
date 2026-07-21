-- 0016_user_blocks.sql
-- Directed blocks: blocker → blocked. Friendship pair row is deleted on block.
-- Bidirectional checks via private.is_blocked. Writes only via RPCs.
-- Soft-hide: no hard-delete of historical pushes/groups; shared memberships stay.

create table public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_blocks_not_self check (blocker_id <> blocked_id),
  constraint user_blocks_unique_pair unique (blocker_id, blocked_id)
);

create index user_blocks_blocker_created_idx
  on public.user_blocks (blocker_id, created_at desc);
create index user_blocks_blocked_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

create policy user_blocks_select_own on public.user_blocks
  for select using (blocker_id = (select auth.uid()));
-- no insert/update/delete policies — RPCs only

create or replace function private.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks ub
    where (ub.blocker_id = a and ub.blocked_id = b)
       or (ub.blocker_id = b and ub.blocked_id = a)
  );
$$;
revoke execute on function private.is_blocked(uuid, uuid) from public, anon;
grant execute on function private.is_blocked(uuid, uuid) to authenticated;

create or replace function public.block_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  low uuid;
  high uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if target_user_id is null or target_user_id = me then
    raise exception 'invalid target';
  end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'unknown user';
  end if;

  insert into public.user_blocks (blocker_id, blocked_id)
  values (me, target_user_id)
  on conflict (blocker_id, blocked_id) do nothing;

  if target_user_id < me then
    low := target_user_id; high := me;
  else
    low := me; high := target_user_id;
  end if;

  delete from public.friendships
  where user_low = low and user_high = high;
end;
$$;
revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

create or replace function public.unblock_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then raise exception 'not authenticated'; end if;
  if target_user_id is null or target_user_id = me then
    raise exception 'invalid target';
  end if;

  delete from public.user_blocks
  where blocker_id = me and blocked_id = target_user_id;
end;
$$;
revoke all on function public.unblock_user(uuid) from public, anon;
grant execute on function public.unblock_user(uuid) to authenticated;

create or replace function public.list_blocked_users()
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
  from public.user_blocks ub
  join public.profiles p on p.id = ub.blocked_id
  where ub.blocker_id = (select auth.uid())
  order by ub.created_at desc;
$$;
revoke all on function public.list_blocked_users() from public, anon;
grant execute on function public.list_blocked_users() to authenticated;

-- ---------------------------------------------------------------------------
-- Guards: recreate RPCs from 0009 / 0011 with private.is_blocked checks.
-- ---------------------------------------------------------------------------

-- Discover people by handle / display name. Exclude blocked pairs either way.
create or replace function public.search_profiles(
  search_query text,
  result_limit int default 20
)
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
    and length(trim(search_query)) > 0
    and not private.is_blocked((select auth.uid()), p.id)
    and (
      p.handle ilike '%' || trim(search_query) || '%'
      or p.first_name ilike '%' || trim(search_query) || '%'
    )
  order by
    case
      when p.handle ilike trim(search_query) || '%' then 0
      when p.first_name ilike trim(search_query) || '%' then 1
      else 2
    end,
    p.handle
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

revoke all on function public.search_profiles(text, int) from public, anon;
grant execute on function public.search_profiles(text, int) to authenticated;

-- Create or re-open a pending request from the caller to target_user_id.
create or replace function public.send_friend_request(target_user_id uuid)
returns public.friendships
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  low uuid;
  high uuid;
  existing public.friendships;
  result public.friendships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if target_user_id is null or target_user_id = me then
    raise exception 'invalid target';
  end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'unknown user';
  end if;
  if private.is_blocked(me, target_user_id) then
    raise exception 'blocked';
  end if;

  if target_user_id < me then
    low := target_user_id;
    high := me;
  else
    low := me;
    high := target_user_id;
  end if;

  select * into existing
  from public.friendships f
  where f.user_low = low and f.user_high = high;

  if found then
    if existing.status = 'accepted' then
      raise exception 'already friends';
    elsif existing.status = 'pending' then
      return existing;
    elsif existing.status = 'denied' then
      update public.friendships
      set status = 'pending',
          requested_by = me,
          created_at = now()
      where id = existing.id
      returning * into result;
      return result;
    end if;
  end if;

  insert into public.friendships (user_low, user_high, status, requested_by)
  values (low, high, 'pending', me)
  returning * into result;
  return result;
end;
$$;

revoke all on function public.send_friend_request(uuid) from public, anon;
grant execute on function public.send_friend_request(uuid) to authenticated;

-- Accept or deny a pending request the caller is on (must not be the requester).
create or replace function public.resolve_friend_request(
  request_id uuid,
  accept boolean
)
returns public.friendships
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.friendships;
  result public.friendships;
  new_status text;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into existing
  from public.friendships f
  where f.id = request_id
  for update;

  if not found then
    raise exception 'not found';
  end if;
  if existing.status <> 'pending' then
    raise exception 'not pending';
  end if;
  if existing.user_low <> me and existing.user_high <> me then
    raise exception 'not a participant';
  end if;
  if existing.requested_by = me then
    raise exception 'requester cannot resolve';
  end if;
  if private.is_blocked(
       me,
       case when existing.user_low = me then existing.user_high else existing.user_low end
     ) then
    raise exception 'blocked';
  end if;

  new_status := case when accept then 'accepted' else 'denied' end;

  update public.friendships
  set status = new_status
  where id = existing.id
  returning * into result;
  return result;
end;
$$;

revoke all on function public.resolve_friend_request(uuid, boolean) from public, anon;
grant execute on function public.resolve_friend_request(uuid, boolean) to authenticated;

-- Create a group, make the caller its owner, and invite friends.
create or replace function public.create_group(
  group_name text,
  image_path text,
  invitee_ids uuid[]
)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  trimmed_name text := trim(group_name);
  deduped_invitees uuid[];
  invitee uuid;
  new_group public.groups;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if length(trimmed_name) = 0 then
    raise exception 'group name required';
  end if;

  -- De-dupe and drop the caller (owner membership is inserted separately below).
  select coalesce(array_agg(distinct id), array[]::uuid[])
  into deduped_invitees
  from unnest(invitee_ids) as id
  where id is not null and id <> me;

  if array_length(deduped_invitees, 1) is null
    or array_length(deduped_invitees, 1) < 2
    or array_length(deduped_invitees, 1) > 19 then
    raise exception 'invitee count must be between 2 and 19';
  end if;

  foreach invitee in array deduped_invitees loop
    if not private.is_friend(me, invitee) then
      raise exception 'invitee % is not a friend', invitee;
    end if;
    if private.is_blocked(me, invitee) then
      raise exception 'invitee % is blocked', invitee;
    end if;
  end loop;

  insert into public.groups (name, image_asset_path)
  values (trimmed_name, image_path)
  returning * into new_group;

  insert into public.group_memberships (person_id, group_id, role, membership_status)
  values (me, new_group.id, 'owner', 'active');

  insert into public.group_memberships (person_id, group_id, role, membership_status)
  select id, new_group.id, 'member', 'invited'
  from unnest(deduped_invitees) as id;

  return new_group;
end;
$$;

revoke all on function public.create_group(text, text, uuid[]) from public, anon;
grant execute on function public.create_group(text, text, uuid[]) to authenticated;

-- Accept or deny a pending group invite; reject when inviter (owner) is blocked.
create or replace function public.resolve_group_invite(
  membership_id uuid,
  accept boolean
)
returns public.group_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.group_memberships;
  result public.group_memberships;
  owner_person_id uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into existing
  from public.group_memberships m
  where m.id = membership_id
  for update;

  if not found then
    raise exception 'not found';
  end if;
  if existing.person_id <> me then
    raise exception 'not a participant';
  end if;
  if existing.membership_status <> 'invited' then
    raise exception 'not pending';
  end if;

  select owner_m.person_id into owner_person_id
  from public.group_memberships owner_m
  where owner_m.group_id = existing.group_id
    and owner_m.role = 'owner'
    and owner_m.membership_status = 'active'
  limit 1;

  if owner_person_id is not null and private.is_blocked(me, owner_person_id) then
    raise exception 'blocked';
  end if;

  if accept then
    update public.group_memberships
    set membership_status = 'active'
    where id = existing.id
    returning * into result;
  else
    -- Hard-delete on deny (mirrors remove_friend) so a future create_group
    -- invite for the same pair inserts cleanly. Return the pre-delete row,
    -- same shape as the accept branch, since there's nothing left to select after.
    delete from public.group_memberships where id = existing.id;
    result := existing;
  end if;

  return result;
end;
$$;

revoke all on function public.resolve_group_invite(uuid, boolean) from public, anon;
grant execute on function public.resolve_group_invite(uuid, boolean) to authenticated;

-- Creator may seed pending invitee rows when not blocked with that person, OR
-- when the person is an active member of the push's group (group-audience
-- co-members stay inviteable despite a soft-hide block).
drop policy if exists push_responses_insert_self_or_creator on public.push_responses;
create policy push_responses_insert_self_or_creator on public.push_responses
  for insert with check (
    person_id = (select auth.uid())
    or (
      private.is_push_creator((select auth.uid()), push_id)
      and response = 'pending'
      and (
        not private.is_blocked((select auth.uid()), person_id)
        or exists (
          select 1 from public.pushes p
          where p.id = push_id
            and p.group_id is not null
            and private.is_group_member(person_id, p.group_id)
        )
      )
    )
  );
