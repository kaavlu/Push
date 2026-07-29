-- Manual verification for Moments S3 Storage policies (0024_moment_media_storage).
-- Issue #119. Run as privileged SQL (service_role / dashboard) after applying 0024.
--
-- Prerequisites: alice@ / bob@ / carol@ pushapp.dev auth users + profiles.
-- Exercises storage.objects RLS directly (not the Storage HTTP API), which is the
-- layer the API delegates authorization to. Safe to re-run: cleans fixture objects
-- by bucket + name prefix and fixture moments by title prefix 'S3 '.

create or replace function pg_temp.s3_as_user(u uuid)
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

create or replace function pg_temp.s3_reset_role()
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
  v_bucket record;
  n int;
begin
  select id into alice from auth.users where email = 'alice@pushapp.dev';
  select id into bob from auth.users where email = 'bob@pushapp.dev';
  select id into carol from auth.users where email = 'carol@pushapp.dev';
  if alice is null or bob is null or carol is null then
    raise exception 'test auth users missing — create alice/bob/carol via Auth + seed first';
  end if;

  -- storage.protect_delete() blocks SQL deletes on storage.objects unless this
  -- escape hatch is set. RLS is evaluated independently of it, so DELETE policy
  -- coverage below is still meaningful. Transaction-local.
  perform set_config('storage.allow_delete_query', 'true', true);

  -- ------------------------------------------------------------------
  -- 1) Bucket shape
  -- ------------------------------------------------------------------
  select * into v_bucket from storage.buckets where id = 'moment-media';
  if v_bucket is null then
    raise exception 'moment-media bucket missing';
  end if;
  if not v_bucket.public then
    raise exception 'moment-media must be public (CDN object GET)';
  end if;
  if v_bucket.file_size_limit is null or v_bucket.file_size_limit <> 104857600 then
    raise exception 'unexpected file_size_limit: %', v_bucket.file_size_limit;
  end if;
  if not (v_bucket.allowed_mime_types @> array['image/jpeg', 'video/mp4']::text[]) then
    raise exception 'allowed_mime_types missing photo/video entries';
  end if;

  -- No listable SELECT for the whole bucket (advisor public_bucket_allows_listing):
  -- every moment-media SELECT policy must constrain the object beyond bucket_id.
  select count(*) into n
  from pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
    and cmd = 'SELECT'
    and qual like '%moment-media%'
    and qual not like '%auth.uid()%';
  if n <> 0 then
    raise exception 'found % unscoped moment-media SELECT policy(ies)', n;
  end if;

  -- Cleanup prior fixtures.
  delete from storage.objects
  where bucket_id = 'moment-media' and name like '%s3-verify%';
  delete from public.moments where title like 'S3 %';

  insert into public.friendships (user_low, user_high, status)
  values (least(alice, bob), greatest(alice, bob), 'accepted')
  on conflict (user_low, user_high) do update set status = 'accepted';

  -- ------------------------------------------------------------------
  -- 2) Pending folder: owner may insert, select, delete
  -- ------------------------------------------------------------------
  perform pg_temp.s3_as_user(alice);
  insert into storage.objects (bucket_id, name, owner, owner_id)
  values (
    'moment-media',
    'pending/' || alice::text || '/s3-verify-a.jpg',
    alice,
    alice::text
  );

  select count(*) into n
  from storage.objects
  where bucket_id = 'moment-media'
    and name = 'pending/' || alice::text || '/s3-verify-a.jpg';
  if n <> 1 then
    raise exception 'owner should see own pending object';
  end if;
  perform pg_temp.s3_reset_role();

  -- ------------------------------------------------------------------
  -- 3) Pending folder: another user cannot see or write it
  -- ------------------------------------------------------------------
  perform pg_temp.s3_as_user(bob);
  select count(*) into n
  from storage.objects
  where bucket_id = 'moment-media'
    and name like 'pending/' || alice::text || '/%';
  if n <> 0 then
    raise exception 'bob must not see alice pending objects';
  end if;

  begin
    insert into storage.objects (bucket_id, name, owner, owner_id)
    values (
      'moment-media',
      'pending/' || alice::text || '/s3-verify-intruder.jpg',
      bob,
      bob::text
    );
    perform pg_temp.s3_reset_role();
    raise exception 'expected insert into another user pending folder to be denied';
  exception
    when insufficient_privilege then
      null; -- expected
    when others then
      perform pg_temp.s3_reset_role();
      if sqlerrm not like '%row-level security%' then
        raise exception 'unexpected pending intruder failure: %', sqlerrm;
      end if;
  end;
  perform pg_temp.s3_reset_role();

  -- Bob deleting alice's pending object is a no-op (invisible under RLS).
  perform pg_temp.s3_as_user(bob);
  delete from storage.objects
  where bucket_id = 'moment-media'
    and name = 'pending/' || alice::text || '/s3-verify-a.jpg';
  perform pg_temp.s3_reset_role();

  select count(*) into n
  from storage.objects
  where name = 'pending/' || alice::text || '/s3-verify-a.jpg';
  if n <> 1 then
    raise exception 'bob must not delete alice pending object';
  end if;

  -- Owner rollback deletes it.
  perform pg_temp.s3_as_user(alice);
  delete from storage.objects
  where bucket_id = 'moment-media'
    and name = 'pending/' || alice::text || '/s3-verify-a.jpg';
  perform pg_temp.s3_reset_role();

  select count(*) into n
  from storage.objects
  where name = 'pending/' || alice::text || '/s3-verify-a.jpg';
  if n <> 0 then
    raise exception 'owner rollback delete failed';
  end if;

  -- ------------------------------------------------------------------
  -- 4) {moment_id} folder: tagged member may insert, untagged may not
  -- ------------------------------------------------------------------
  -- 0025 validates media paths against real objects, so seed one first.
  perform pg_temp.s3_as_user(alice);
  insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
  values (
    'moment-media',
    'pending/' || alice::text || '/s3-verify-seed.jpg',
    alice,
    alice::text,
    jsonb_build_object('mimetype', 'image/jpeg', 'size', 1)
  );

  v_moment := public.create_moment(
    'S3 storage fixture',
    null,
    null,
    array[bob],
    jsonb_build_array(
      jsonb_build_object(
        'kind', 'photo',
        'storage_path', 'pending/' || alice::text || '/s3-verify-seed.jpg',
        'public_url', 'https://example.test/s3-verify-seed.jpg'
      )
    )
  );
  perform pg_temp.s3_reset_role();

  perform pg_temp.s3_as_user(bob);
  insert into storage.objects (bucket_id, name, owner, owner_id)
  values (
    'moment-media',
    v_moment::text || '/s3-verify-bob.jpg',
    bob,
    bob::text
  );
  perform pg_temp.s3_reset_role();

  perform pg_temp.s3_as_user(carol);
  begin
    insert into storage.objects (bucket_id, name, owner, owner_id)
    values (
      'moment-media',
      v_moment::text || '/s3-verify-carol.jpg',
      carol,
      carol::text
    );
    perform pg_temp.s3_reset_role();
    raise exception 'expected untagged insert under moment folder to be denied';
  exception
    when insufficient_privilege then
      null; -- expected
    when others then
      perform pg_temp.s3_reset_role();
      if sqlerrm not like '%row-level security%' then
        raise exception 'unexpected untagged insert failure: %', sqlerrm;
      end if;
  end;
  perform pg_temp.s3_reset_role();

  -- Untagged user cannot list the moment folder either.
  perform pg_temp.s3_as_user(carol);
  select count(*) into n
  from storage.objects
  where bucket_id = 'moment-media' and name like v_moment::text || '/%';
  if n <> 0 then
    raise exception 'untagged user must not list moment folder';
  end if;
  perform pg_temp.s3_reset_role();

  -- ------------------------------------------------------------------
  -- 5) {moment_id} folder: creator may delete another member's object
  -- ------------------------------------------------------------------
  perform pg_temp.s3_as_user(alice);
  delete from storage.objects
  where bucket_id = 'moment-media'
    and name = v_moment::text || '/s3-verify-bob.jpg';
  perform pg_temp.s3_reset_role();

  select count(*) into n
  from storage.objects
  where name = v_moment::text || '/s3-verify-bob.jpg';
  if n <> 0 then
    raise exception 'moment creator should be able to delete member media object';
  end if;

  -- ------------------------------------------------------------------
  -- 6) Soft-deleted Moment stops accepting new media
  -- ------------------------------------------------------------------
  perform pg_temp.s3_as_user(alice);
  perform public.soft_delete_moment(v_moment);
  perform pg_temp.s3_reset_role();

  perform pg_temp.s3_as_user(bob);
  begin
    insert into storage.objects (bucket_id, name, owner, owner_id)
    values (
      'moment-media',
      v_moment::text || '/s3-verify-late.jpg',
      bob,
      bob::text
    );
    perform pg_temp.s3_reset_role();
    raise exception 'expected insert into deleted moment folder to be denied';
  exception
    when insufficient_privilege then
      null; -- expected
    when others then
      perform pg_temp.s3_reset_role();
      if sqlerrm not like '%row-level security%' then
        raise exception 'unexpected deleted-moment insert failure: %', sqlerrm;
      end if;
  end;
  perform pg_temp.s3_reset_role();

  -- Cleanup
  delete from storage.objects
  where bucket_id = 'moment-media' and name like '%s3-verify%';
  delete from public.moments where title like 'S3 %';

  raise notice '0024 moment-media storage policy verification OK';
end;
$$;
