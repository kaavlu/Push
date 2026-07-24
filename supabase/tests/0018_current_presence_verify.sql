-- Manual verification for 0018_current_presence (Issue #71).
-- Run as a privileged SQL role (service_role / dashboard SQL) after applying
-- the migration. Uses test identities from seed (alice / bob / carol).
--
-- This script is NOT applied as a migration. Safe to re-run: cleans up its
-- fixture presence rows for alice/bob (does not delete profiles/auth).
--
-- Expected outcome: every assert_* block raises on failure; silent success
-- at the end prints '0018_current_presence verification OK'.

do $$
declare
  alice uuid;
  bob uuid;
  carol uuid;
  n int;
  r public.current_presence;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  select id into carol from auth.users where email = 'carol@pushapp.dev';

  if alice is null or bob is null or carol is null then
    raise exception 'test auth users missing — create alice/bob/carol via Auth + seed.sql first';
  end if;

  -- Clean fixture rows.
  delete from public.current_presence where user_id in (alice, bob, carol);

  -- ------------------------------------------------------------------
  -- Schema basics
  -- ------------------------------------------------------------------
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'current_presence'
  ) then
    raise exception 'current_presence table missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'unpublish_current_presence'
  ) then
    raise exception 'unpublish_current_presence missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'set_availability_choice'
  ) then
    raise exception 'set_availability_choice missing';
  end if;

  -- ------------------------------------------------------------------
  -- Direct table writes as service role (constraint checks)
  -- ------------------------------------------------------------------
  insert into public.current_presence (
    user_id, availability, is_published,
    activity_name, activity_symbol,
    latitude, longitude, confidence,
    observed_at, updated_at, expires_at, source
  ) values (
    alice, 'free_now', true,
    'Coffee', 'cup.and.saucer.fill',
    37.77, -122.42, 'high',
    now(), now(), now() + interval '60 minutes', 'location'
  );

  -- Published requires expires_at.
  begin
    insert into public.current_presence (
      user_id, availability, is_published, expires_at, source
    ) values (
      bob, 'busy', true, null, 'location'
    );
    raise exception 'expected published_requires_expiry to reject';
  exception
    when check_violation then null;
  end;

  -- Lat/lng pair integrity.
  begin
    insert into public.current_presence (
      user_id, availability, is_published, latitude, longitude, expires_at, source
    ) values (
      bob, 'busy', false, 10.0, null, null, 'location'
    );
    raise exception 'expected exact_coords_pair to reject';
  exception
    when check_violation then null;
  end;

  insert into public.current_presence (
    user_id, availability, is_published,
    latitude, longitude, vague_latitude, vague_longitude,
    expires_at, source, confidence
  ) values (
    bob, 'joinable', true,
    37.78, -122.41, 37.78, -122.41,
    now() + interval '60 minutes', 'location', 'medium'
  );

  -- ------------------------------------------------------------------
  -- RLS simulation via set_config JWT claims
  -- ------------------------------------------------------------------

  -- Alice can read own row.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.current_presence where user_id = alice;
  if n <> 1 then
    raise exception 'alice self-select failed (count=%)', n;
  end if;

  -- Alice can read bob (friend, published, not expired).
  select count(*) into n from public.current_presence where user_id = bob;
  if n <> 1 then
    raise exception 'alice friend-select bob failed (count=%)', n;
  end if;

  -- Alice cannot write bob's row.
  begin
    update public.current_presence
    set status_note = 'hijack'
    where user_id = bob;
    get diagnostics n = row_count;
    if n <> 0 then
      raise exception 'alice must not update bob presence';
    end if;
  end;

  begin
    insert into public.current_presence (user_id, availability, is_published, source)
    values (carol, 'busy', false, 'location');
    raise exception 'alice must not insert carol presence';
  exception
    when raise_exception then
      raise;
    when others then
      -- RLS WITH CHECK denial (expected).
      null;
  end;

  select count(*) into n from public.current_presence where user_id = carol;
  if n <> 0 then
    raise exception 'unauthorized insert leaked carol row';
  end if;

  reset role;

  -- Carol (unrelated) cannot read alice or bob.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', carol::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', carol::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;

  select count(*) into n from public.current_presence
  where user_id in (alice, bob);
  if n <> 0 then
    raise exception 'carol must not read friend presence (count=%)', n;
  end if;

  reset role;

  -- Unpublished hidden from friends; still visible to self.
  update public.current_presence
  set is_published = false, latitude = null, longitude = null, expires_at = now()
  where user_id = bob;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  select count(*) into n from public.current_presence where user_id = bob;
  if n <> 0 then
    raise exception 'unpublished bob still visible to alice';
  end if;
  reset role;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  select count(*) into n from public.current_presence where user_id = bob;
  if n <> 1 then
    raise exception 'bob cannot self-read unpublished row';
  end if;
  reset role;

  -- Republish bob, then expire — hidden from friends.
  update public.current_presence
  set
    is_published = true,
    latitude = 37.78,
    longitude = -122.41,
    expires_at = now() - interval '1 minute',
    updated_at = now()
  where user_id = bob;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  select count(*) into n from public.current_presence where user_id = bob;
  if n <> 0 then
    raise exception 'expired bob still visible to alice';
  end if;
  reset role;

  -- Restore bob published + future expiry for block tests.
  update public.current_presence
  set expires_at = now() + interval '60 minutes', is_published = true
  where user_id = bob;

  -- Block: alice blocks bob → neither sees the other's presence (soft-hide).
  -- Use service role for block_user JWT as alice.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  perform public.block_user(bob);
  select count(*) into n from public.current_presence where user_id = bob;
  if n <> 0 then
    raise exception 'blocked bob still visible to alice';
  end if;
  reset role;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  select count(*) into n from public.current_presence where user_id = alice;
  if n <> 0 then
    raise exception 'alice still visible to blocked bob';
  end if;
  reset role;

  -- Unblock and restore friendship for remaining checks (seed re-friend).
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  perform public.unblock_user(bob);
  reset role;

  -- Re-seed friendship if block_user deleted it.
  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update
  set status = 'accepted';

  update public.current_presence
  set
    is_published = true,
    latitude = 37.78,
    longitude = -122.41,
    expires_at = now() + interval '60 minutes'
  where user_id = bob;

  -- Unpublish RPC as bob.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  perform public.unpublish_current_presence();
  reset role;

  select * into r from public.current_presence where user_id = bob;
  if r.is_published <> false then
    raise exception 'unpublish left is_published true';
  end if;
  if r.latitude is not null or r.longitude is not null then
    raise exception 'unpublish left coordinates';
  end if;
  if r.vague_latitude is not null or r.vague_longitude is not null then
    raise exception 'unpublish left vague coordinates';
  end if;
  if r.expires_at is null or r.expires_at > now() + interval '5 seconds' then
    raise exception 'unpublish did not expire row';
  end if;
  if r.availability is distinct from 'joinable' then
    raise exception 'unpublish must preserve availability mirror (got %)', r.availability;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', alice::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', alice::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  select count(*) into n from public.current_presence where user_id = bob;
  if n <> 0 then
    raise exception 'after unpublish bob still visible to alice';
  end if;
  reset role;

  -- Availability dual-write: profile + mirror when row exists.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', bob::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', bob::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  perform public.set_availability_choice('busy');
  reset role;

  if (select availability_choice from public.profiles where id = bob) is distinct from 'busy' then
    raise exception 'set_availability_choice did not update profile';
  end if;
  if (select availability from public.current_presence where user_id = bob) is distinct from 'busy' then
    raise exception 'set_availability_choice did not update presence mirror';
  end if;
  if (select is_published from public.current_presence where user_id = bob) <> false then
    raise exception 'set_availability_choice must not flip is_published';
  end if;

  -- Availability dual-write when no presence row (alice still has row — use carol).
  delete from public.current_presence where user_id = carol;
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', carol::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', carol::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  set local role authenticated;
  perform public.set_availability_choice('maybe_down');
  reset role;

  if (select availability_choice from public.profiles where id = carol) is distinct from 'maybe_down' then
    raise exception 'carol profile availability not updated without presence row';
  end if;
  if exists (select 1 from public.current_presence where user_id = carol) then
    raise exception 'set_availability_choice must not invent presence row';
  end if;

  -- Anon role: no access.
  set local role anon;
  begin
    select count(*) into n from public.current_presence;
    if n <> 0 then
      raise exception 'anon read current_presence (count=%)', n;
    end if;
  exception
    when insufficient_privilege then null;
  end;
  reset role;

  -- Cleanup fixtures; restore default availability so re-runs leave no residue.
  delete from public.current_presence where user_id in (alice, bob, carol);
  update public.profiles
  set availability_choice = 'free_now', updated_at = now()
  where id in (alice, bob, carol);

  raise notice '0018_current_presence verification OK';
end;
$$;
