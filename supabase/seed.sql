-- seed.sql — reproducible public-graph seed keyed off REAL auth IDs.
--
-- Prereq (spec R4): the two test identities are created via real Supabase Auth,
-- NOT SQL-inserted into auth.users. See supabase/README.md. This script only
-- seeds public.* rows, resolving the users by email — no hardcoded UUIDs — and
-- is idempotent (safe to re-run).
--
--   Alice: alice@pushapp.dev / push-test-alice
--   Bob:   bob@pushapp.dev   / push-test-bob
--   (Carol carol@pushapp.dev exists as an unrelated third user for deny tests;
--    she is intentionally NOT added to the friendship or group.)
do $$
declare a uuid; b uuid; g uuid;
begin
  select id into a from auth.users where email = 'alice@pushapp.dev';
  select id into b from auth.users where email = 'bob@pushapp.dev';
  if a is null or b is null then
    raise exception 'Seed requires alice@pushapp.dev and bob@pushapp.dev to exist (create them via Auth first)';
  end if;

  -- Ensure profile display fields (the signup trigger already inserted the rows).
  update public.profiles set first_name = 'Alice', handle = 'alice' where id = a;
  update public.profiles set first_name = 'Bob', handle = 'bob' where id = b;

  -- Mutual friendship (canonical ordering user_low < user_high).
  insert into public.friendships (user_low, user_high)
  values (least(a, b), greatest(a, b))
  on conflict (user_low, user_high) do nothing;

  -- Shared group + memberships (deterministic group by name).
  select id into g from public.groups where name = 'Test Crew';
  if g is null then
    insert into public.groups (name) values ('Test Crew') returning id into g;
  end if;
  insert into public.group_memberships (person_id, group_id, role)
  values (a, g, 'owner') on conflict (person_id, group_id) do nothing;
  insert into public.group_memberships (person_id, group_id, role)
  values (b, g, 'member') on conflict (person_id, group_id) do nothing;

  -- Default global sharing policies so presence would resolve if it existed.
  insert into public.sharing_policies (owner_person_id, audience_type, location_visibility, activity_visibility, availability_visibility)
  select a, 'global_default', 'exact', 'full', 'full'
  where not exists (select 1 from public.sharing_policies where owner_person_id = a and audience_type = 'global_default');
  insert into public.sharing_policies (owner_person_id, audience_type, location_visibility, activity_visibility, availability_visibility)
  select b, 'global_default', 'exact', 'full', 'full'
  where not exists (select 1 from public.sharing_policies where owner_person_id = b and audience_type = 'global_default');
end $$;
