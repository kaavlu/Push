-- Manual verification for the Moment read RPCs (0026_moment_feed_rpcs).
-- Issue #122. Run as privileged SQL (service_role / dashboard) after applying 0026.
--
-- Prerequisites: alice@ / bob@ / carol@ pushapp.dev auth users + profiles.
-- Safe to re-run: cleans fixture moments ('S5 %'), storage objects ('s5f-'),
-- and the fixture group. `storage.protect_delete()` needs the transaction-local
-- escape hatch set below before any storage delete.

create or replace function pg_temp.s5f_as_user(u uuid)
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

create or replace function pg_temp.s5f_reset_role()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
end;
$$;

-- Seeds a pending media object owned by `u`, exactly as the Storage API would.
create or replace function pg_temp.s5f_object(u uuid, label text)
returns text
language plpgsql
as $$
declare
  v_name text := 'pending/' || u::text || '/s5f-' || label || '.jpg';
begin
  insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
  values (
    'moment-media', v_name, u, u::text,
    jsonb_build_object('mimetype', 'image/jpeg', 'size', 1)
  )
  on conflict (bucket_id, name) do update set metadata = excluded.metadata;
  return v_name;
end;
$$;

-- Feed ids for `u`, in page order.
create or replace function pg_temp.s5f_feed_ids(
  u uuid, p_limit int default 10, p_group uuid default null
)
returns uuid[]
language plpgsql
as $$
declare
  ids uuid[];
begin
  perform pg_temp.s5f_as_user(u);
  select array_agg((item->>'id')::uuid order by ord)
  into ids
  from (
    select item, row_number() over () as ord
    from public.feed_moments(null, null, p_limit, p_group) as item
  ) t;
  perform pg_temp.s5f_reset_role();
  return coalesce(ids, '{}');
end;
$$;

do $$
declare
  alice uuid;
  bob uuid;
  carol uuid;
  v_first uuid;
  v_second uuid;
  v_group uuid := '00000000-0000-4000-8000-0000000005f0';
  ids uuid[];
  v_row jsonb;
  detail jsonb;
  n int;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  select id into carol from auth.users where email = 'carol@pushapp.dev';
  if alice is null or bob is null or carol is null then
    raise exception 'test auth users missing — create alice/bob/carol via Auth + seed first';
  end if;

  perform set_config('storage.allow_delete_query', 'true', true);
  delete from public.moments where title like 'S5 %';
  delete from storage.objects where name like '%s5f-%';
  delete from public.group_memberships where group_id = v_group;
  delete from public.groups where id = v_group;
  delete from public.user_blocks
  where blocker_id in (alice, bob, carol) and blocked_id in (alice, bob, carol);

  -- alice ↔ bob and alice ↔ carol are friends; bob ↔ carol are not.
  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';
  insert into public.friendships (user_low, user_high, status)
  values (least(alice, carol), greatest(alice, carol), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';
  delete from public.friendships
  where user_low = least(bob, carol) and user_high = greatest(bob, carol);

  -- ------------------------------------------------------------------
  -- Fixtures: two Moments by alice, bob tagged on the first one.
  -- ------------------------------------------------------------------
  perform pg_temp.s5f_as_user(alice);
  v_first := public.create_moment(
    'S5 first', 'Rooftop', null, array[bob],
    jsonb_build_array(
      jsonb_build_object(
        'kind', 'photo',
        'storage_path', pg_temp.s5f_object(alice, 'a1'),
        'public_url', 'ignored'
      )
    )
  );
  v_second := public.create_moment(
    'S5 second', 'Park', null, '{}',
    jsonb_build_array(
      jsonb_build_object(
        'kind', 'photo',
        'storage_path', pg_temp.s5f_object(alice, 'a2'),
        'public_url', 'ignored'
      )
    )
  );
  perform pg_temp.s5f_reset_role();

  -- bob adds to the first Moment, making it the most recent activity.
  perform pg_temp.s5f_as_user(bob);
  perform public.append_moment_media(
    v_first, 'photo', pg_temp.s5f_object(bob, 'b1'), 'ignored'
  );
  perform pg_temp.s5f_reset_role();

  -- ------------------------------------------------------------------
  -- 1) Ordering — newest activity first
  -- ------------------------------------------------------------------
  ids := pg_temp.s5f_feed_ids(alice);
  if ids[1] <> v_first or ids[2] <> v_second then
    raise exception 'feed order wrong: %', ids;
  end if;

  -- ------------------------------------------------------------------
  -- 2) Keyset pagination — no overlap, no gaps
  -- ------------------------------------------------------------------
  perform pg_temp.s5f_as_user(alice);
  select r into v_row from public.feed_moments(null, null, 1, null) as r;
  if (v_row->>'id')::uuid <> v_first then
    raise exception 'first page should hold the newest Moment';
  end if;

  select r into v_row
  from public.feed_moments(
    (v_row->>'last_activity_at')::timestamptz, (v_row->>'id')::uuid, 1, null
  ) as r;
  perform pg_temp.s5f_reset_role();
  if (v_row->>'id')::uuid <> v_second then
    raise exception 'second page should hold the older Moment';
  end if;

  -- ------------------------------------------------------------------
  -- 3) DTO shape — ordered tags, dense media, capabilities
  -- ------------------------------------------------------------------
  perform pg_temp.s5f_as_user(alice);
  detail := public.moment_detail(v_first);
  perform pg_temp.s5f_reset_role();

  if (detail->'tagged_person_ids'->>0)::uuid <> alice then
    raise exception 'creator must lead the tag list';
  end if;
  if jsonb_array_length(detail->'media') <> 2 then
    raise exception 'expected 2 media, got %', jsonb_array_length(detail->'media');
  end if;
  if (detail->'media'->0->>'sort_order')::int <> 0 then
    raise exception 'cover must be sort_order 0';
  end if;
  if (detail->>'visible_media_count')::int <> 2 then
    raise exception 'visible count mismatch';
  end if;
  -- Public URLs were derived by 0025, never the 'ignored' string we passed.
  if detail->'media'->0->>'public_url' = 'ignored' then
    raise exception 'public_url should be server-derived';
  end if;
  if not (detail->'capabilities'->>'canEditMetadata')::boolean then
    raise exception 'creator should be able to edit metadata';
  end if;

  perform pg_temp.s5f_as_user(bob);
  detail := public.moment_detail(v_first);
  perform pg_temp.s5f_reset_role();
  if not (detail->'capabilities'->>'canAddMedia')::boolean then
    raise exception 'tagged member should be able to add media';
  end if;
  if (detail->'capabilities'->>'canEditMetadata')::boolean then
    raise exception 'non-creator must not edit metadata';
  end if;
  if not (detail->'capabilities'->>'youContributed')::boolean then
    raise exception 'bob contributed media';
  end if;

  -- ------------------------------------------------------------------
  -- 4) Block filtering — bob's media and face omitted for carol
  -- ------------------------------------------------------------------
  perform pg_temp.s5f_as_user(carol);
  detail := public.moment_detail(v_first);
  perform pg_temp.s5f_reset_role();
  if (detail->>'visible_media_count')::int <> 2 then
    raise exception 'carol should see both items before the block';
  end if;

  insert into public.user_blocks (blocker_id, blocked_id) values (carol, bob);

  perform pg_temp.s5f_as_user(carol);
  detail := public.moment_detail(v_first);
  perform pg_temp.s5f_reset_role();
  if (detail->>'visible_media_count')::int <> 1 then
    raise exception 'blocked uploader media must be omitted';
  end if;
  if detail->'tagged_person_ids' @> to_jsonb(bob::text) then
    raise exception 'blocked person must be omitted from tags';
  end if;

  delete from public.user_blocks where blocker_id = carol and blocked_id = bob;

  -- ------------------------------------------------------------------
  -- 5) Visibility — a stranger sees nothing and cannot load detail
  -- ------------------------------------------------------------------
  perform pg_temp.s5f_as_user(bob);
  ids := array(select (r->>'id')::uuid from public.feed_moments(null, null, 10, null) as r);
  perform pg_temp.s5f_reset_role();
  -- bob is tagged on the first and is alice's friend, so both stay visible.
  if array_length(ids, 1) <> 2 then
    raise exception 'bob should see both Moments, got %', ids;
  end if;

  -- Remove every path: unfriend alice, untag bob from the first Moment.
  delete from public.friendships
  where user_low = least(alice, bob) and user_high = greatest(alice, bob);
  perform pg_temp.s5f_as_user(bob);
  perform public.remove_moment_member(v_first, bob);
  perform pg_temp.s5f_reset_role();

  ids := pg_temp.s5f_feed_ids(bob);
  -- bob keeps his media on the first Moment, but he is no longer tagged and no
  -- longer a friend of alice — the second Moment has no path at all.
  if v_second = any (ids) then
    raise exception 'unfriended non-tagged viewer must not see the second Moment';
  end if;

  begin
    perform pg_temp.s5f_as_user(bob);
    perform public.moment_detail(v_second);
    perform pg_temp.s5f_reset_role();
    raise exception 'expected moment_detail denial for an invisible Moment';
  exception
    when others then
      perform pg_temp.s5f_reset_role();
      if sqlerrm not like '%not found%' then
        raise exception 'detail deny unexpected: %', sqlerrm;
      end if;
  end;

  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  -- ------------------------------------------------------------------
  -- 6) Hub — created ∪ tagged ∪ contributed
  -- ------------------------------------------------------------------
  perform pg_temp.s5f_as_user(alice);
  select count(*) into n from public.hub_moments(50);
  perform pg_temp.s5f_reset_role();
  if n <> 2 then
    raise exception 'alice created both Moments, hub returned %', n;
  end if;

  perform pg_temp.s5f_as_user(bob);
  ids := array(select (r->>'id')::uuid from public.hub_moments(50) as r);
  perform pg_temp.s5f_reset_role();
  -- Untagged, but still a contributor on the first Moment.
  if not (v_first = any (ids)) then
    raise exception 'contributor should stay in the hub';
  end if;
  if v_second = any (ids) then
    raise exception 'pure viewer Moment must not be in the hub';
  end if;

  perform pg_temp.s5f_as_user(carol);
  select count(*) into n from public.hub_moments(50);
  perform pg_temp.s5f_reset_role();
  if n <> 0 then
    raise exception 'viewer-only hub should be empty, got %', n;
  end if;

  -- ------------------------------------------------------------------
  -- 7) Group filter
  -- ------------------------------------------------------------------
  insert into public.groups (id, name) values (v_group, 'S5 group');
  insert into public.group_memberships
    (id, group_id, person_id, role, membership_status)
  values
    (gen_random_uuid(), v_group, alice, 'owner', 'active'),
    (gen_random_uuid(), v_group, carol, 'member', 'active');

  -- carol shares the group with alice, who is tagged on both Moments.
  ids := pg_temp.s5f_feed_ids(carol, 10, v_group);
  if array_length(ids, 1) <> 2 then
    raise exception 'group filter should keep both Moments for carol, got %', ids;
  end if;

  -- bob is not in the group and shares it with nobody tagged.
  ids := pg_temp.s5f_feed_ids(bob, 10, v_group);
  if array_length(coalesce(ids, '{}'), 1) is not null then
    raise exception 'non-member group filter should be empty, got %', ids;
  end if;

  -- Cleanup
  delete from public.group_memberships where group_id = v_group;
  delete from public.groups where id = v_group;
  delete from public.moments where title like 'S5 %';
  delete from storage.objects where name like '%s5f-%';

  raise notice '0026 moment feed/hub/detail RPC verification OK';
end;
$$;
