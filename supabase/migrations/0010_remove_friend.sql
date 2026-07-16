-- 0010_remove_friend.sql
-- Lets either party in an accepted friendship end it from the Friends list.
--
-- Design:
-- - Mirrors `send_friend_request` / `resolve_friend_request`: a SECURITY
--   DEFINER RPC owns the UUID ordering so it isn't duplicated in Swift.
-- - Hard-deletes the row (not a status flip) so a future `send_friend_request`
--   between the same pair starts clean, matching the mock store's behavior.
-- - Only deletes rows that are `accepted`; pending/denied rows are managed by
--   `resolve_friend_request` and are left alone.

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
  where user_low = low and user_high = high and status = 'accepted';
end;
$$;

revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated;
