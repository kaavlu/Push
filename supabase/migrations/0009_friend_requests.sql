-- 0009_friend_requests.sql
-- Pending friend requests on the undirected `friendships` pair row, plus
-- discoverability search beyond friend/group RLS.
--
-- Design:
-- - One row per pair (user_low < user_high) remains canonical.
-- - `status`: pending | accepted | denied (accepted rows from seed stay valid).
-- - `requested_by` names the initiator when status is pending (and after re-request).
-- - Client writes go through SECURITY DEFINER RPCs so UUID ordering and
--   invalid-state guards live in one place (not duplicated in Swift).
-- - `search_profiles` returns only public fields for authenticated callers.

-- Who started a pending (or re-opened) request. Null on historical accepted rows.
alter table public.friendships
  add column if not exists requested_by uuid references public.profiles (id) on delete set null;

alter table public.friendships
  drop constraint if exists friendships_status_check;
alter table public.friendships
  add constraint friendships_status_check
  check (status in ('pending', 'accepted', 'denied'));

alter table public.friendships
  drop constraint if exists friendships_pending_has_requester;
alter table public.friendships
  add constraint friendships_pending_has_requester
  check (status <> 'pending' or requested_by is not null);

create index if not exists friendships_requested_by_idx
  on public.friendships (requested_by)
  where requested_by is not null;

-- Recipient (or either party for select) already covered by friendships_select_own.
-- Writes are intentionally not opened via raw table policies; use RPCs below.

-- Discover people by handle / display name. SECURITY DEFINER so non-friends
-- are findable; only limited columns are returned.
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

-- Pending pair participants can read each other's profiles (Alerts / Add Friends
-- need the counterparty before the friendship is accepted). Accepted friends
-- remain covered by `profiles_select_friends` via `private.is_friend`.
create policy profiles_select_pending_friendship on public.profiles
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.friendships f
      where f.status = 'pending'
        and (
          (f.user_low = (select auth.uid()) and f.user_high = profiles.id)
          or (f.user_high = (select auth.uid()) and f.user_low = profiles.id)
        )
    )
  );
