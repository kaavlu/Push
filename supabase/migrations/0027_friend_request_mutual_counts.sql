-- 0027_friend_request_mutual_counts.sql
-- Server-derived mutual-friend counts for pending incoming friend requests.
--
-- Privacy:
-- - The caller supplies no target ids.
-- - Results are limited to pending requests addressed to auth.uid().
-- - Only request id + aggregate count are returned; mutual identities stay private.
--
-- Performance:
-- - Both sides of the undirected graph are expressed as UNION ALL branches so
--   the existing (user_low, user_high) unique index and user_high index can be used.
-- - Every inbox count is produced in one query (no per-request N+1 calls).

create or replace function public.incoming_friend_request_mutual_counts()
returns table (
  request_id uuid,
  mutual_friend_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with viewer as (
    select (select auth.uid()) as id
  ),
  incoming_requests as (
    select
      f.id as request_id,
      f.requested_by as requester_id
    from public.friendships f
    cross join viewer v
    where v.id is not null
      and f.status = 'pending'
      and f.requested_by is not null
      and f.requested_by <> v.id
      and (f.requested_by = f.user_low or f.requested_by = f.user_high)
      and (f.user_low = v.id or f.user_high = v.id)
      and not private.is_blocked(v.id, f.requested_by)
  ),
  viewer_friends as (
    select f.user_high as friend_id
    from public.friendships f
    join viewer v on f.user_low = v.id
    where f.status = 'accepted'

    union all

    select f.user_low as friend_id
    from public.friendships f
    join viewer v on f.user_high = v.id
    where f.status = 'accepted'
  ),
  requester_friends as (
    select ir.request_id, f.user_high as friend_id
    from incoming_requests ir
    join public.friendships f on f.user_low = ir.requester_id
    where f.status = 'accepted'

    union all

    select ir.request_id, f.user_low as friend_id
    from incoming_requests ir
    join public.friendships f on f.user_high = ir.requester_id
    where f.status = 'accepted'
  )
  select
    ir.request_id,
    count(vf.friend_id)::integer as mutual_friend_count
  from incoming_requests ir
  left join requester_friends rf on rf.request_id = ir.request_id
  left join viewer_friends vf on vf.friend_id = rf.friend_id
  group by ir.request_id
  order by ir.request_id;
$$;

revoke all on function public.incoming_friend_request_mutual_counts()
  from public, anon;
grant execute on function public.incoming_friend_request_mutual_counts()
  to authenticated;
