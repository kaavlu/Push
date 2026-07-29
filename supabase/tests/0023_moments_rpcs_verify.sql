-- Manual verification for Moments S2 mutation RPCs (0023_moments_rpcs).
-- Issue #118. Run as privileged SQL (service_role / dashboard) after applying 0023.
--
-- Prerequisites: alice@ / bob@ / carol@ pushapp.dev auth users + profiles.
-- Safe to re-run: cleans fixture moments by title prefix 'S2 '.
--
-- Auth for RPCs: set JWT claims + SET LOCAL ROLE authenticated so auth.uid() works
-- inside SECURITY DEFINER functions.

create or replace function pg_temp.s2_as_user(u uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.s2_reset_role()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
end;
$$;

do $$
declare
  alice uuid;
  bob uuid;
  carol uuid;
  v_moment uuid;
  v_media_a uuid;
  v_media_b uuid;
  v_media_c uuid;
  v_push uuid;
  activity_before timestamptz;
  activity_after timestamptz;
  n int;
  ordered uuid[];
  i int;
  mid uuid;
  err text;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  select id into carol from auth.users where email = 'carol@pushapp.dev';
  if alice is null or bob is null or carol is null then
    raise exception 'test auth users missing — create alice/bob/carol via Auth + seed first';
  end if;

  -- Cleanup prior S2 fixtures.
  delete from public.moments where title like 'S2 %';
  delete from public.pushes where title = 'S2 push for moment slot';

  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  delete from public.friendships
  where user_low = least(alice, carol) and user_high = greatest(alice, carol);

  delete from public.user_blocks
  where (blocker_id in (alice, bob, carol) and blocked_id in (alice, bob, carol));

  -- ------------------------------------------------------------------
  -- 1) Creator creates scratch Moment with media + friend tag
  -- ------------------------------------------------------------------
  perform pg_temp.s2_as_user(alice);
  v_moment := public.create_moment(
    'S2 solo create',
    'Park',
    null,
    array[bob],
    jsonb_build_array(
      jsonb_build_object(
        'kind', 'photo',
        'storage_path', 'pending/a/1.jpg',
        'public_url', 'https://example.test/s2-1.jpg'
      )
    )
  );
  perform pg_temp.s2_reset_role();

  if v_moment is null then
    raise exception 'create_moment returned null';
  end if;

  select count(*) into n from public.moment_members where moment_id = v_moment;
  if n <> 2 then
    raise exception 'expected creator+bob tags, got %', n;
  end if;

  select count(*) into n
  from public.moment_media
  where moment_id = v_moment and deleted_at is null;
  if n <> 1 then
    raise exception 'expected 1 media after create';
  end if;

  select id into v_media_a
  from public.moment_media
  where moment_id = v_moment and deleted_at is null
  limit 1;

  select last_activity_at into activity_before
  from public.moments where id = v_moment;

  -- ------------------------------------------------------------------
  -- 2) Tagged non-contributor (bob) appends — activity bumps
  -- ------------------------------------------------------------------
  perform pg_temp.s2_as_user(bob);
  v_media_b := public.append_moment_media(
    v_moment, 'photo', 'pending/b/2.jpg', 'https://example.test/s2-2.jpg'
  );
  perform pg_temp.s2_reset_role();

  select last_activity_at into activity_after
  from public.moments where id = v_moment;
  -- clock_timestamp() in RPCs distinguishes activity within one test transaction.
  if activity_after <= activity_before then
    raise exception 'append should bump last_activity_at';
  end if;

  -- ------------------------------------------------------------------
  -- 3) Creator updates metadata — activity unchanged
  -- ------------------------------------------------------------------
  activity_before := activity_after;
  perform pg_temp.s2_as_user(alice);
  perform public.update_moment_metadata(v_moment, 'S2 solo create renamed', 'Park 2');
  perform pg_temp.s2_reset_role();

  select last_activity_at, title into activity_after, err
  from public.moments where id = v_moment;
  if activity_after <> activity_before then
    raise exception 'metadata must not bump last_activity_at';
  end if;
  if err <> 'S2 solo create renamed' then
    raise exception 'title not updated';
  end if;

  -- ------------------------------------------------------------------
  -- 4) Contributor reorders — cover becomes former last
  -- ------------------------------------------------------------------
  select array_agg(id order by sort_order) into ordered
  from public.moment_media
  where moment_id = v_moment and deleted_at is null;

  -- Reverse order so previous last is cover.
  ordered := array[ordered[2], ordered[1]];

  perform pg_temp.s2_as_user(bob);
  perform public.reorder_moment_media(v_moment, ordered);
  perform pg_temp.s2_reset_role();

  select id into mid
  from public.moment_media
  where moment_id = v_moment and deleted_at is null and sort_order = 0;
  if mid <> ordered[1] then
    raise exception 'cover not updated after reorder';
  end if;

  select last_activity_at into activity_after from public.moments where id = v_moment;
  if activity_after <> activity_before then
    raise exception 'reorder must not bump last_activity_at';
  end if;

  -- ------------------------------------------------------------------
  -- 5) Soft-delete own media; last media soft-deletes moment
  -- ------------------------------------------------------------------
  -- Create fresh moment with 2 media owned by alice for delete path.
  perform pg_temp.s2_as_user(alice);
  v_moment := public.create_moment(
    'S2 delete media',
    'X',
    null,
    '{}',
    jsonb_build_array(
      jsonb_build_object('kind','photo','storage_path','p/a.jpg','public_url','https://example.test/a.jpg'),
      jsonb_build_object('kind','photo','storage_path','p/b.jpg','public_url','https://example.test/b.jpg')
    )
  );
  perform pg_temp.s2_reset_role();

  select id into v_media_a from public.moment_media
  where moment_id = v_moment and sort_order = 0 and deleted_at is null;
  select id into v_media_b from public.moment_media
  where moment_id = v_moment and sort_order = 1 and deleted_at is null;

  perform pg_temp.s2_as_user(alice);
  perform public.soft_delete_moment_media(v_media_a);
  perform pg_temp.s2_reset_role();

  select count(*) into n from public.moment_media
  where moment_id = v_moment and deleted_at is null;
  if n <> 1 then
    raise exception 'expected 1 media after first soft-delete';
  end if;

  select sort_order into i from public.moment_media
  where id = v_media_b and deleted_at is null;
  if i <> 0 then
    raise exception 'expected renumber cover to 0, got %', i;
  end if;

  perform pg_temp.s2_as_user(alice);
  perform public.soft_delete_moment_media(v_media_b);
  perform pg_temp.s2_reset_role();

  if not exists (
    select 1 from public.moments where id = v_moment and deleted_at is not null
  ) then
    raise exception 'last media delete should soft-delete moment';
  end if;

  -- ------------------------------------------------------------------
  -- 6) Soft-delete moment keeps push slot
  -- ------------------------------------------------------------------
  insert into public.pushes (
    id, title, creator_id, starts_at, expires_at, audience
  ) values (
    gen_random_uuid(), 'S2 push for moment slot', alice,
    now() - interval '2 days', now() - interval '1 day', 'invitees_only'
  ) returning id into v_push;

  insert into public.push_responses (push_id, person_id, response)
  values (v_push, alice, 'in');

  perform pg_temp.s2_as_user(alice);
  v_moment := public.create_moment(
    'S2 from push',
    'Y',
    v_push,
    '{}',
    jsonb_build_array(
      jsonb_build_object('kind','photo','storage_path','p/p.jpg','public_url','https://example.test/p.jpg')
    )
  );
  perform public.soft_delete_moment(v_moment);
  perform pg_temp.s2_reset_role();

  begin
    perform pg_temp.s2_as_user(alice);
    perform public.create_moment(
      'S2 from push again',
      'Y',
      v_push,
      '{}',
      jsonb_build_array(
        jsonb_build_object('kind','photo','storage_path','p/q.jpg','public_url','https://example.test/q.jpg')
      )
    );
    perform pg_temp.s2_reset_role();
    raise exception 'expected second create for same push to fail';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%moment exists for push%' and sqlerrm not like '%invalid push%' then
        -- unique_violation message may differ if race; accept either clear precheck
        if sqlerrm not like '%unique%' and sqlstate <> '23505' then
          raise exception 'unexpected error on second push moment: %', sqlerrm;
        end if;
      end if;
  end;

  -- ------------------------------------------------------------------
  -- Denied cases
  -- ------------------------------------------------------------------
  perform pg_temp.s2_as_user(alice);
  v_moment := public.create_moment(
    'S2 deny matrix',
    'Z',
    null,
    array[bob],
    jsonb_build_array(
      jsonb_build_object('kind','photo','storage_path','p/d1.jpg','public_url','https://example.test/d1.jpg')
    )
  );
  perform pg_temp.s2_reset_role();

  select id into v_media_a from public.moment_media
  where moment_id = v_moment and deleted_at is null limit 1;

  -- 7) Stranger cannot append
  begin
    perform pg_temp.s2_as_user(carol);
    perform public.append_moment_media(
      v_moment, 'photo', 'p/x.jpg', 'https://example.test/x.jpg'
    );
    perform pg_temp.s2_reset_role();
    raise exception 'expected stranger append denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%not allowed%' and sqlerrm not like '%not found%' then
        raise exception 'stranger append unexpected: %', sqlerrm;
      end if;
  end;

  -- 8) Non-creator cannot update metadata
  begin
    perform pg_temp.s2_as_user(bob);
    perform public.update_moment_metadata(v_moment, 'hack', 'hack');
    perform pg_temp.s2_reset_role();
    raise exception 'expected non-creator metadata denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%not allowed%' then
        raise exception 'metadata deny unexpected: %', sqlerrm;
      end if;
  end;

  -- 9) Tagged non-contributor cannot reorder or remove others' tags
  -- bob has not contributed on this moment yet.
  select array_agg(id order by sort_order) into ordered
  from public.moment_media
  where moment_id = v_moment and deleted_at is null;

  begin
    perform pg_temp.s2_as_user(bob);
    perform public.reorder_moment_media(v_moment, ordered);
    perform pg_temp.s2_reset_role();
    raise exception 'expected tagged non-contributor reorder denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%not allowed%' then
        raise exception 'reorder deny unexpected: %', sqlerrm;
      end if;
  end;

  begin
    perform pg_temp.s2_as_user(bob);
    -- bob tries to remove alice (creator) — should fail cannot remove creator
    -- first try remove someone else: only alice+bob tagged; try remove alice
    perform public.remove_moment_member(v_moment, alice);
    perform pg_temp.s2_reset_role();
    raise exception 'expected remove creator denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%cannot remove creator%' and sqlerrm not like '%not allowed%' then
        raise exception 'remove creator deny unexpected: %', sqlerrm;
      end if;
  end;

  -- Tagged non-contributor cannot add tags either.
  -- Ensure carol is friend of bob only — bob cannot edit tags yet.
  insert into public.friendships (user_low, user_high, status)
  values (least(bob, carol), greatest(bob, carol), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  begin
    perform pg_temp.s2_as_user(bob);
    perform public.add_moment_members(v_moment, array[carol]);
    perform pg_temp.s2_reset_role();
    raise exception 'expected tagged non-contributor add tags denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%not allowed%' then
        raise exception 'add tags deny unexpected: %', sqlerrm;
      end if;
  end;

  -- 10) Non-creator cannot soft-delete moment
  begin
    perform pg_temp.s2_as_user(bob);
    perform public.soft_delete_moment(v_moment);
    perform pg_temp.s2_reset_role();
    raise exception 'expected non-creator soft_delete_moment denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%not allowed%' then
        raise exception 'soft_delete_moment deny unexpected: %', sqlerrm;
      end if;
  end;

  -- 11) Non-uploader non-creator cannot delete others' media
  -- bob appends so he has own media; try delete alice's
  perform pg_temp.s2_as_user(bob);
  v_media_b := public.append_moment_media(
    v_moment, 'photo', 'p/bob.jpg', 'https://example.test/bob.jpg'
  );
  perform pg_temp.s2_reset_role();

  begin
    perform pg_temp.s2_as_user(bob);
    perform public.soft_delete_moment_media(v_media_a);
    perform pg_temp.s2_reset_role();
    raise exception 'expected bob cannot delete alice media';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%not allowed%' then
        raise exception 'delete others media deny unexpected: %', sqlerrm;
      end if;
  end;

  -- 12) Ninth media rejected
  -- Current: 2 media (alice + bob). Append 6 more as alice → 8; 9th fails.
  perform pg_temp.s2_as_user(alice);
  for i in 1..6 loop
    perform public.append_moment_media(
      v_moment,
      'photo',
      'p/fill-' || i || '.jpg',
      'https://example.test/fill-' || i || '.jpg'
    );
  end loop;
  perform pg_temp.s2_reset_role();

  select count(*) into n from public.moment_media
  where moment_id = v_moment and deleted_at is null;
  if n <> 8 then
    raise exception 'expected 8 media before cap test, got %', n;
  end if;

  begin
    perform pg_temp.s2_as_user(alice);
    perform public.append_moment_media(
      v_moment, 'photo', 'p/nine.jpg', 'https://example.test/nine.jpg'
    );
    perform pg_temp.s2_reset_role();
    raise exception 'expected 9th media denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%media limit exceeded%' then
        raise exception 'cap deny unexpected: %', sqlerrm;
      end if;
  end;

  -- 14) Create with empty media rejected
  begin
    perform pg_temp.s2_as_user(alice);
    perform public.create_moment('S2 empty', 'Z', null, '{}', '[]'::jsonb);
    perform pg_temp.s2_reset_role();
    raise exception 'expected empty media create denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%media required%' then
        raise exception 'empty media deny unexpected: %', sqlerrm;
      end if;
  end;

  -- 15) Remove creator tag rejected (as creator trying self-remove)
  begin
    perform pg_temp.s2_as_user(alice);
    perform public.remove_moment_member(v_moment, alice);
    perform pg_temp.s2_reset_role();
    raise exception 'expected creator self-remove denied';
  exception
    when others then
      perform pg_temp.s2_reset_role();
      if sqlerrm not like '%cannot remove creator%' then
        raise exception 'creator self-remove deny unexpected: %', sqlerrm;
      end if;
  end;

  -- Self-remove allowed for bob (contributor now)
  perform pg_temp.s2_as_user(bob);
  perform public.remove_moment_member(v_moment, bob);
  perform pg_temp.s2_reset_role();

  if private.is_moment_tagged(bob, v_moment) then
    raise exception 'bob should be untagged after self-remove';
  end if;
  if not private.is_moment_contributor(bob, v_moment) then
    raise exception 'bob media should remain after self-remove';
  end if;

  -- Cleanup
  delete from public.moments where title like 'S2 %';
  delete from public.pushes where title = 'S2 push for moment slot';
  delete from public.friendships
  where user_low = least(bob, carol) and user_high = greatest(bob, carol);

  raise notice '0023 moments S2 RPC verification OK';
end;
$$;
