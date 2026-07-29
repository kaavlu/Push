-- Manual verification for Moment media path validation (0025).
-- Issue #119. Run as privileged SQL (service_role / dashboard) after applying 0025.
--
-- Prerequisites: alice@ / bob@ / carol@ pushapp.dev auth users + profiles.
-- Safe to re-run: cleans fixture objects (name prefix 's5-') and moments ('S5 %').
-- Note: storage.protect_delete() blocks SQL deletes on storage.objects unless
-- `storage.allow_delete_query` is set; the cleanup below sets it transaction-locally.

-- Seeds a storage object exactly as the Storage API would (owner + mimetype).
create or replace function pg_temp.s5_object(
  p_bucket text, p_name text, p_owner uuid, p_mime text
)
returns text
language plpgsql
as $$
begin
  insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
  values (
    p_bucket, p_name, p_owner, p_owner::text,
    jsonb_build_object('mimetype', p_mime, 'size', 1)
  )
  on conflict (bucket_id, name) do update
    set owner = excluded.owner,
        owner_id = excluded.owner_id,
        metadata = excluded.metadata;
  return p_name;
end;
$$;

create or replace function pg_temp.s5_as_user(u uuid)
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

create or replace function pg_temp.s5_reset_role()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
end;
$$;

-- Asserts a create_moment call fails with `expected_error` (substring match).
create or replace function pg_temp.s5_expect_create_denied(
  u uuid, label text, media jsonb, expected_error text
)
returns void
language plpgsql
as $$
begin
  perform pg_temp.s5_as_user(u);
  perform public.create_moment(label, null, null, '{}', media);
  perform pg_temp.s5_reset_role();
  raise exception 'expected denial (%) for %', expected_error, label;
exception
  when others then
    perform pg_temp.s5_reset_role();
    if sqlerrm not like '%' || expected_error || '%' then
      raise exception 'unexpected failure for %: %', label, sqlerrm;
    end if;
end;
$$;

do $$
declare
  alice uuid;
  bob uuid;
  v_moment uuid;
  v_other_moment uuid;
  v_media uuid;
  v_path text;
  v_url text;
  v_kind text;
  n int;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  if alice is null or bob is null then
    raise exception 'test auth users missing — create alice/bob via Auth + seed first';
  end if;

  perform set_config('storage.allow_delete_query', 'true', true);
  delete from public.moments where title like 'S5 %';
  delete from storage.objects where name like '%s5-%';

  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  -- Fixture objects.
  perform pg_temp.s5_object(
    'moment-media', 'pending/' || alice::text || '/s5-alice.jpg', alice, 'image/jpeg'
  );
  perform pg_temp.s5_object(
    'moment-media', 'pending/' || bob::text || '/s5-bob.jpg', bob, 'image/jpeg'
  );
  perform pg_temp.s5_object(
    'moment-media', 'pending/' || alice::text || '/s5-alice-video.mp4', alice, 'video/mp4'
  );
  -- Same key shape, wrong bucket.
  perform pg_temp.s5_object(
    'group-photos', 'pending/' || alice::text || '/s5-other-bucket.jpg', alice, 'image/jpeg'
  );

  -- ------------------------------------------------------------------
  -- 5) Uploader's own pending object succeeds; URL derived server-side
  -- ------------------------------------------------------------------
  perform pg_temp.s5_as_user(alice);
  v_moment := public.create_moment(
    'S5 valid publish', null, null, array[bob],
    jsonb_build_array(
      jsonb_build_object(
        'kind', 'photo',
        'storage_path', 'pending/' || alice::text || '/s5-alice.jpg',
        -- Attacker-supplied URL for a validated path: must be ignored.
        'public_url', 'https://evil.example/attacker.jpg'
      )
    )
  );
  perform pg_temp.s5_reset_role();

  select storage_path, public_url into v_path, v_url
  from public.moment_media where moment_id = v_moment and deleted_at is null;

  if v_path <> 'pending/' || alice::text || '/s5-alice.jpg' then
    raise exception 'stored path mismatch: %', v_path;
  end if;
  if v_url <> private.moment_media_public_url(v_path) then
    raise exception 'public_url not derived server-side: %', v_url;
  end if;
  if v_url like '%evil.example%' then
    raise exception 'caller-supplied public_url was trusted';
  end if;

  -- ------------------------------------------------------------------
  -- 1) Another user's pending object is rejected
  -- ------------------------------------------------------------------
  perform pg_temp.s5_expect_create_denied(
    alice,
    'S5 steal pending',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_path', 'pending/' || bob::text || '/s5-bob.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );

  -- ------------------------------------------------------------------
  -- 3) A path from another bucket is rejected
  -- ------------------------------------------------------------------
  perform pg_temp.s5_expect_create_denied(
    alice,
    'S5 other bucket',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_path', 'pending/' || alice::text || '/s5-other-bucket.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );

  -- ------------------------------------------------------------------
  -- 4) Missing / malformed paths are rejected
  -- ------------------------------------------------------------------
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 missing object',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_path', 'pending/' || alice::text || '/s5-does-not-exist.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 empty path',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo', 'storage_path', '', 'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 null path',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo', 'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );
  -- Flat key with no folder, and an over-nested key under the owner folder.
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 flat path',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo', 'storage_path', 's5-alice.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );
  perform pg_temp.s5_object(
    'moment-media',
    'pending/' || alice::text || '/nested/s5-deep.jpg', alice, 'image/jpeg'
  );
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 nested path',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_path', 'pending/' || alice::text || '/nested/s5-deep.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'invalid media path'
  );

  -- Declared kind must match the stored mime type.
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 kind mismatch',
    jsonb_build_array(jsonb_build_object(
      'kind', 'video',
      'storage_path', 'pending/' || alice::text || '/s5-alice.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'media type mismatch'
  );

  -- An object already registered by an active row cannot be reused.
  perform pg_temp.s5_expect_create_denied(
    alice, 'S5 reuse registered',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_path', 'pending/' || alice::text || '/s5-alice.jpg',
      'public_url', 'https://example.test/x.jpg'
    )),
    'media already registered'
  );

  -- ------------------------------------------------------------------
  -- 6) Valid Add yours append — pending key and {moment_id} key
  -- ------------------------------------------------------------------
  perform pg_temp.s5_as_user(bob);
  v_media := public.append_moment_media(
    v_moment, 'photo',
    'pending/' || bob::text || '/s5-bob.jpg',
    'https://evil.example/attacker-2.jpg'
  );
  perform pg_temp.s5_reset_role();

  select public_url into v_url from public.moment_media where id = v_media;
  if v_url like '%evil.example%' then
    raise exception 'append trusted caller-supplied public_url';
  end if;

  perform pg_temp.s5_object(
    'moment-media', v_moment::text || '/s5-bob-direct.mp4', bob, 'video/mp4'
  );
  perform pg_temp.s5_object(
    'moment-media', v_moment::text || '/s5-bob-direct-poster.jpg', bob, 'image/jpeg'
  );
  perform pg_temp.s5_as_user(bob);
  v_media := public.append_moment_media(
    v_moment, 'video',
    v_moment::text || '/s5-bob-direct.mp4',
    'ignored',
    v_moment::text || '/s5-bob-direct-poster.jpg',
    'ignored'
  );
  perform pg_temp.s5_reset_role();

  select kind, poster_url into v_kind, v_url from public.moment_media where id = v_media;
  if v_kind <> 'video' then
    raise exception 'expected video media, got %', v_kind;
  end if;
  if v_url <> private.moment_media_public_url(v_moment::text || '/s5-bob-direct-poster.jpg') then
    raise exception 'poster_url not derived server-side: %', v_url;
  end if;

  -- ------------------------------------------------------------------
  -- 2) An object belonging to another Moment is rejected
  -- ------------------------------------------------------------------
  perform pg_temp.s5_object(
    'moment-media', 'pending/' || alice::text || '/s5-alice-2.jpg', alice, 'image/jpeg'
  );
  perform pg_temp.s5_as_user(alice);
  v_other_moment := public.create_moment(
    'S5 other moment', null, null, '{}',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_path', 'pending/' || alice::text || '/s5-alice-2.jpg',
      'public_url', 'https://example.test/x.jpg'
    ))
  );
  perform pg_temp.s5_reset_role();

  -- Alice owns this object under the *other* Moment's folder; it must not be
  -- registrable against v_moment.
  perform pg_temp.s5_object(
    'moment-media', v_other_moment::text || '/s5-alice-direct.jpg', alice, 'image/jpeg'
  );
  begin
    perform pg_temp.s5_as_user(alice);
    perform public.append_moment_media(
      v_moment, 'photo', v_other_moment::text || '/s5-alice-direct.jpg', 'ignored'
    );
    perform pg_temp.s5_reset_role();
    raise exception 'expected other-moment object denied';
  exception
    when others then
      perform pg_temp.s5_reset_role();
      if sqlerrm not like '%invalid media path%' then
        raise exception 'other-moment deny unexpected: %', sqlerrm;
      end if;
  end;

  -- Already-registered media from another Moment is rejected too.
  begin
    perform pg_temp.s5_as_user(alice);
    perform public.append_moment_media(
      v_moment, 'photo', 'pending/' || alice::text || '/s5-alice-2.jpg', 'ignored'
    );
    perform pg_temp.s5_reset_role();
    raise exception 'expected registered-elsewhere media denied';
  exception
    when others then
      perform pg_temp.s5_reset_role();
      if sqlerrm not like '%media already registered%' then
        raise exception 'registered-elsewhere deny unexpected: %', sqlerrm;
      end if;
  end;

  select count(*) into n
  from public.moment_media where moment_id = v_moment and deleted_at is null;
  if n <> 3 then
    raise exception 'expected 3 active media on the valid Moment, got %', n;
  end if;

  -- Cleanup
  delete from public.moments where title like 'S5 %';
  delete from storage.objects where name like '%s5-%';

  raise notice '0025 moment media path validation verification OK';
end;
$$;
