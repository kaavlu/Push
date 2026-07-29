-- Manual verification for 0027_friend_request_mutual_counts.
-- Run as privileged SQL after applying the migration.
--
-- Prerequisites: alice@ / bob@ / carol@ pushapp.dev Auth users + profiles.
-- The transaction rolls back every friendship fixture change.

begin;

do $$
declare
  alice uuid;
  bob uuid;
  carol uuid;
  v_request_id uuid;
  result_count integer;
  result_rows integer;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  select id into carol from auth.users where email = 'carol@pushapp.dev';

  if alice is null or bob is null or carol is null then
    raise exception 'test auth users missing — create alice/bob/carol via Auth + seed first';
  end if;

  delete from public.user_blocks
  where blocker_id in (alice, bob, carol)
    and blocked_id in (alice, bob, carol);
  delete from public.friendships
  where user_low in (alice, bob, carol)
    and user_high in (alice, bob, carol);

  -- Bob requests Alice; Carol is accepted friends with both.
  insert into public.friendships (user_low, user_high, status, requested_by)
  values (least(alice, bob), greatest(alice, bob), 'pending', bob)
  returning id into v_request_id;

  insert into public.friendships (user_low, user_high, status)
  values
    (least(alice, carol), greatest(alice, carol), 'accepted'),
    (least(bob, carol), greatest(bob, carol), 'accepted');

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*), max(mutual_friend_count)
  into result_rows, result_count
  from public.incoming_friend_request_mutual_counts() counts
  where counts.request_id = v_request_id;

  if result_rows <> 1 or result_count <> 1 then
    raise exception 'alice expected one request with one mutual, rows=%, count=%',
      result_rows, result_count;
  end if;

  reset role;

  -- Remove Bob ↔ Carol: the request remains and its aggregate must be zero.
  delete from public.friendships
  where user_low = least(bob, carol)
    and user_high = greatest(bob, carol);

  set local role authenticated;
  select mutual_friend_count
  into result_count
  from public.incoming_friend_request_mutual_counts() counts
  where counts.request_id = v_request_id;

  if result_count <> 0 then
    raise exception 'alice expected zero mutuals after edge removal, count=%', result_count;
  end if;

  reset role;

  -- The requester must not be able to use the RPC to inspect the recipient.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into result_rows
  from public.incoming_friend_request_mutual_counts();
  if result_rows <> 0 then
    raise exception 'requester must receive no incoming aggregate rows';
  end if;

  reset role;
end;
$$;

rollback;

select '0027_friend_request_mutual_counts verification OK' as result;
