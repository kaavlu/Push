-- Manual verification for Moments S1 (0021 tables + 0022 helpers / SELECT RLS).
-- Issue #117. Run as a privileged SQL role (service_role / dashboard SQL) after
-- applying 0021_moments_tables and 0022_moments_private_helpers.
--
-- Prerequisites:
--   - Auth users alice@pushapp.dev, bob@pushapp.dev, carol@pushapp.dev
--   - profiles rows for those users (signup trigger / seed)
--
-- This script is NOT a migration. Safe to re-run: deletes its fixture Moments
-- (cascade members/media). Does not delete profiles/auth/friendships/blocks
-- permanently — restores block state for alice/bob at the end.
--
-- S1 has no mutation RPCs: fixtures are inserted as the privileged role.
-- RLS is exercised via set_config JWT claims + SET LOCAL ROLE authenticated.
--
-- Expected: every assert raises on failure; success prints verification OK.

do $$
declare
  alice uuid;
  bob uuid;
  carol uuid;
  moment_solo uuid := gen_random_uuid();
  moment_deleted uuid := gen_random_uuid();
  moment_multi uuid := gen_random_uuid();
  media_solo_alice uuid := gen_random_uuid();
  media_multi_alice uuid := gen_random_uuid();
  media_multi_bob uuid := gen_random_uuid();
  push_slot uuid;
  n int;
  caps jsonb;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  select id into carol from auth.users where email = 'carol@pushapp.dev';

  if alice is null or bob is null or carol is null then
    raise exception 'test auth users missing — create alice/bob/carol via Auth + seed.sql first';
  end if;

  -- ------------------------------------------------------------------
  -- Schema presence
  -- ------------------------------------------------------------------
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'moments'
  ) then
    raise exception 'moments table missing';
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'moment_members'
  ) then
    raise exception 'moment_members table missing';
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'moment_media'
  ) then
    raise exception 'moment_media table missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'can_view_moment'
  ) then
    raise exception 'private.can_view_moment missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'media_visible_to'
  ) then
    raise exception 'private.media_visible_to missing';
  end if;

  -- Clean prior fixture moments (by known titles).
  delete from public.moments
  where title in (
    'S1 solo fixture',
    'S1 deleted fixture',
    'S1 multi fixture',
    'S1 push-slot fixture'
  );

  -- Ensure alice–bob friendship for friends-of-tagged path.
  insert into public.friendships (user_low, user_high, status)
  values (
    least(alice, bob),
    greatest(alice, bob),
    'accepted'
  )
  on conflict (user_low, user_high) do update
    set status = 'accepted';

  -- Carol is the stranger (no friendship with alice for solo tests).
  delete from public.friendships
  where (user_low = least(alice, carol) and user_high = greatest(alice, carol))
     or (user_low = least(bob, carol) and user_high = greatest(bob, carol));

  -- Clear alice/bob blocks for a clean start.
  delete from public.user_blocks
  where (blocker_id = alice and blocked_id = bob)
     or (blocker_id = bob and blocked_id = alice);

  -- ------------------------------------------------------------------
  -- Fixture: solo Moment (creator alice tagged + media)
  -- ------------------------------------------------------------------
  insert into public.moments (
    id, creator_id, title, location_text, published_at, last_activity_at
  ) values (
    moment_solo, alice, 'S1 solo fixture', 'Test Park', now(), now()
  );

  insert into public.moment_members (moment_id, person_id, tagged_at)
  values (moment_solo, alice, now());

  insert into public.moment_media (
    id, moment_id, uploader_id, kind, storage_path, public_url, sort_order
  ) values (
    media_solo_alice, moment_solo, alice, 'photo',
    'fixture/solo.jpg', 'https://example.test/solo.jpg', 0
  );

  -- ------------------------------------------------------------------
  -- 1) Soft-deleted moment not selectable under RLS
  -- ------------------------------------------------------------------
  insert into public.moments (
    id, creator_id, title, location_text, published_at, last_activity_at, deleted_at
  ) values (
    moment_deleted, alice, 'S1 deleted fixture', 'Gone', now(), now(), now()
  );
  insert into public.moment_members (moment_id, person_id)
  values (moment_deleted, alice);
  insert into public.moment_media (
    moment_id, uploader_id, kind, storage_path, public_url, sort_order
  ) values (
    moment_deleted, alice, 'photo', 'fixture/del.jpg', 'https://example.test/del.jpg', 0
  );

  if private.can_view_moment(alice, moment_deleted) then
    raise exception 'expected can_view_moment false for soft-deleted moment';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.moments where id = moment_deleted;
  if n <> 0 then
    raise exception 'soft-deleted moment leaked under RLS (alice)';
  end if;

  reset role;

  -- ------------------------------------------------------------------
  -- 2) UNIQUE(push_id) holds after soft-delete
  -- ------------------------------------------------------------------
  insert into public.pushes (
    id, title, creator_id, starts_at, expires_at, audience
  ) values (
    gen_random_uuid(),
    'S1 push for moment slot',
    alice,
    now() - interval '2 days',
    now() - interval '1 day',
    'invitees_only'
  )
  returning id into push_slot;

  insert into public.moments (
    creator_id, title, location_text, push_id, published_at, last_activity_at, deleted_at
  ) values (
    alice, 'S1 push-slot fixture', 'Slot', push_slot, now(), now(), now()
  );

  begin
    insert into public.moments (
      creator_id, title, location_text, push_id, published_at, last_activity_at
    ) values (
      alice, 'S1 push-slot duplicate', 'Slot', push_slot, now(), now()
    );
    raise exception 'expected UNIQUE(push_id) to reject second moment including soft-deleted';
  exception
    when unique_violation then null;
  end;

  -- Cleanup push fixture moment + push (moment first for clarity).
  delete from public.moments where push_id = push_slot;
  delete from public.pushes where id = push_slot;

  -- ------------------------------------------------------------------
  -- 3) Stranger cannot select solo moment
  -- ------------------------------------------------------------------
  if private.can_view_moment(carol, moment_solo) then
    raise exception 'expected stranger carol cannot view solo moment';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', carol::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', carol::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.moments where id = moment_solo;
  if n <> 0 then
    raise exception 'stranger saw solo moment under RLS';
  end if;

  reset role;

  -- ------------------------------------------------------------------
  -- 4) Friend of creator can select solo moment
  -- ------------------------------------------------------------------
  if not private.can_view_moment(bob, moment_solo) then
    raise exception 'expected friend bob can_view solo moment';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.moments where id = moment_solo;
  if n <> 1 then
    raise exception 'friend bob did not see solo moment under RLS';
  end if;

  select count(*) into n from public.moment_media where moment_id = moment_solo;
  if n <> 1 then
    raise exception 'friend bob did not see solo media under RLS';
  end if;

  reset role;

  -- ------------------------------------------------------------------
  -- 5) Block breaks visibility path (alice blocks bob)
  -- ------------------------------------------------------------------
  insert into public.user_blocks (blocker_id, blocked_id)
  values (alice, bob)
  on conflict do nothing;

  -- Friendship may still exist; block must win for path via alice.
  if private.can_view_moment(bob, moment_solo) then
    raise exception 'expected block to break friends-of-tagged path via alice';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.moments where id = moment_solo;
  if n <> 0 then
    raise exception 'blocked friend still saw solo moment under RLS';
  end if;

  reset role;

  delete from public.user_blocks
  where blocker_id = alice and blocked_id = bob;

  -- ------------------------------------------------------------------
  -- 6) Blocked uploader media omitted; path via other tag remains
  -- ------------------------------------------------------------------
  insert into public.moments (
    id, creator_id, title, location_text, published_at, last_activity_at
  ) values (
    moment_multi, alice, 'S1 multi fixture', 'Shared', now(), now()
  );

  insert into public.moment_members (moment_id, person_id, tagged_at) values
    (moment_multi, alice, now()),
    (moment_multi, bob, now() + interval '1 second');

  insert into public.moment_media (
    id, moment_id, uploader_id, kind, storage_path, public_url, sort_order
  ) values
    (media_multi_alice, moment_multi, alice, 'photo',
     'fixture/multi-a.jpg', 'https://example.test/multi-a.jpg', 0),
    (media_multi_bob, moment_multi, bob, 'photo',
     'fixture/multi-b.jpg', 'https://example.test/multi-b.jpg', 1);

  -- Re-friend if needed (block test may have left friendship).
  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  -- Carol friends only with bob → path via bob; alice media should hide when carol blocks alice.
  insert into public.friendships (user_low, user_high, status)
  values (least(bob, carol), greatest(bob, carol), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  insert into public.user_blocks (blocker_id, blocked_id)
  values (carol, alice)
  on conflict do nothing;

  if not private.can_view_moment(carol, moment_multi) then
    raise exception 'expected carol can_view multi via bob after blocking alice';
  end if;

  if private.media_visible_to(carol, media_multi_alice) then
    raise exception 'expected alice media hidden from carol when blocked';
  end if;

  if not private.media_visible_to(carol, media_multi_bob) then
    raise exception 'expected bob media visible to carol';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', carol::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', carol::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.moments where id = moment_multi;
  if n <> 1 then
    raise exception 'carol should see multi moment under RLS';
  end if;

  select count(*) into n from public.moment_media where moment_id = moment_multi;
  if n <> 1 then
    raise exception 'carol should see exactly one media (bob), got %', n;
  end if;

  select count(*) into n
  from public.moment_members
  where moment_id = moment_multi;
  -- bob + maybe not alice (blocked face omitted)
  if n <> 1 then
    raise exception 'carol should see only bob member face, got %', n;
  end if;

  reset role;

  -- Capabilities sanity (alice on multi).
  caps := private.moment_capabilities(alice, moment_multi);
  if caps->>'canView' <> 'true'
     or caps->>'canAddMedia' <> 'true'
     or caps->>'canDeleteMoment' <> 'true'
     or caps->>'youContributed' <> 'true'
  then
    raise exception 'unexpected moment_capabilities for alice: %', caps;
  end if;

  -- ------------------------------------------------------------------
  -- Cleanup fixtures
  -- ------------------------------------------------------------------
  delete from public.user_blocks
  where (blocker_id = carol and blocked_id = alice)
     or (blocker_id = alice and blocked_id = bob);

  delete from public.friendships
  where user_low = least(bob, carol) and user_high = greatest(bob, carol);

  delete from public.moments
  where title in (
    'S1 solo fixture',
    'S1 deleted fixture',
    'S1 multi fixture',
    'S1 push-slot fixture'
  );

  raise notice '0021/0022 moments S1 verification OK';
end;
$$;
