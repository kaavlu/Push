-- 0013_friend_relationship_lifecycle.sql
-- Completes friend request lifecycle: cancel outgoing, race-safe send,
-- and remove that clears any status between a pair.
--
-- Design:
-- - One undirected row per pair remains canonical (0002 / 0009).
-- - Cancel hard-deletes pending rows (requester only) so re-send is a clean insert
--   and the recipient’s Alerts inbox empties without a “cancelled” status surface.
-- - send_friend_request handles concurrent first inserts via unique_violation.
-- - remove_friend deletes any status between the pair so pending/denied cannot
--   linger after “remove friend”; groups and pushes are not touched.

-- Sender cancels an outgoing pending request.
create or replace function public.cancel_friend_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.friendships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if request_id is null then
    raise exception 'invalid request';
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
  if existing.requested_by is distinct from me then
    raise exception 'only requester can cancel';
  end if;

  delete from public.friendships where id = existing.id;
end;
$$;

revoke all on function public.cancel_friend_request(uuid) from public, anon;
grant execute on function public.cancel_friend_request(uuid) to authenticated;

-- Race-safe send / re-open. Pending is idempotent (returns existing row so
-- concurrent reciprocal requests cannot create a second pair row).
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
  where f.user_low = low and f.user_high = high
  for update;

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
    else
      raise exception 'unsupported friendship status';
    end if;
  end if;

  begin
    insert into public.friendships (user_low, user_high, status, requested_by)
    values (low, high, 'pending', me)
    returning * into result;
    return result;
  exception
    when unique_violation then
      select * into existing
      from public.friendships f
      where f.user_low = low and f.user_high = high
      for update;
      if not found then
        raise;
      end if;
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
      else
        raise exception 'unsupported friendship status';
      end if;
  end;
end;
$$;

revoke all on function public.send_friend_request(uuid) from public, anon;
grant execute on function public.send_friend_request(uuid) to authenticated;

-- Either party ends the relationship. Deletes any status so a later request
-- starts clean (mirrors mock InMemoryDatabase.removeFriend).
create or replace function public.remove_friend(other_user_id uuid)
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
  if me is null then
    raise exception 'not authenticated';
  end if;
  if other_user_id is null or other_user_id = me then
    raise exception 'invalid target';
  end if;

  if other_user_id < me then
    low := other_user_id;
    high := me;
  else
    low := me;
    high := other_user_id;
  end if;

  delete from public.friendships
  where user_low = low and user_high = high;
end;
$$;

revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated;
