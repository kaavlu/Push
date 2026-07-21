-- 0011_group_invites.sql
-- Group creation + invite/accept/deny, mirroring 0009's friend-request pattern:
-- client writes go through SECURITY DEFINER RPCs rather than raw table INSERT
-- policies, so validation lives in one place instead of duplicated in Swift.
--
-- Design:
-- - `create_group` inserts the group, an active `owner` membership for the
--   caller, and `invited` `member` memberships for each invitee. Invitees
--   must already be friends of the caller (private.is_friend) — Add Group
--   only offers friends as candidates, and this closes the gap server-side.
-- - `resolve_group_invite` mirrors `resolve_friend_request`: caller must own
--   the invited row. Accept flips it to active; deny hard-deletes it so a
--   future re-invite starts clean (mirrors 0010_remove_friend's rationale).
-- - `incoming_group_invites` hands invitees enriched read access to a group
--   they can't yet SELECT via `private.is_group_member` (which only counts
--   `active` rows, by design in 0003_groups.sql) — the RPC does the join
--   server-side instead of opening a new SELECT policy for invited rows.

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

-- Accept or deny a pending group invite the caller is the invitee on.
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

-- Enriched view of the caller's own pending group invites: the group's
-- basics, the owner's identity, and the group's current active member count.
create or replace function public.incoming_group_invites()
returns table (
  membership_id uuid,
  group_id uuid,
  group_name text,
  image_asset_path text,
  inviter_id uuid,
  inviter_first_name text,
  inviter_image text,
  member_count bigint,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    m.id as membership_id,
    g.id as group_id,
    g.name as group_name,
    g.image_asset_path,
    owner_m.person_id as inviter_id,
    owner_p.first_name as inviter_first_name,
    owner_p.image_asset_path as inviter_image,
    (
      select count(*) from public.group_memberships active_m
      where active_m.group_id = g.id and active_m.membership_status = 'active'
    ) as member_count,
    m.joined_at as created_at
  from public.group_memberships m
  join public.groups g on g.id = m.group_id
  left join public.group_memberships owner_m
    on owner_m.group_id = g.id and owner_m.role = 'owner' and owner_m.membership_status = 'active'
  left join public.profiles owner_p on owner_p.id = owner_m.person_id
  where m.person_id = (select auth.uid())
    and m.membership_status = 'invited';
$$;

revoke all on function public.incoming_group_invites() from public, anon;
grant execute on function public.incoming_group_invites() to authenticated;
