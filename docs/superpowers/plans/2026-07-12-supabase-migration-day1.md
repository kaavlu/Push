# Day-1 Supabase Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let two real users authenticate against Supabase, keep their session across launches, and load their own profile, their mutual friendship, their shared group + memberships, and their sharing policies from Supabase — while the existing mock mode, deterministic tests, previews, and MVVM UI stay untouched.

**Architecture:** Add a parallel `.live` composition alongside the existing `.mock` `AppDataContainer`, behind the current async-throws repository protocols. Live identity comes from a Supabase auth session; live social reads come from Supabase-backed repositories; presence/push/feed return empty in live mode. Schema, RLS, and helpers are authored as repo SQL migrations and applied to the remote via the Supabase MCP. The promoted OnboardingLab sign-in/sign-up UI, driven by a production `AuthViewModel → AuthService`, is the live auth surface.

**Tech Stack:** Swift / SwiftUI (iOS 17+), MVVM, `supabase-swift` (Auth + PostgREST) via SwiftPM, Postgres + RLS on Supabase project `tzzvwjhvjduyqywlszqc`, XCTest.

## Global Constraints

- **Spec of record:** `tasks/spec.md` → "Issue #27 — Supabase Migration (Day 1)". Every task inherits it.
- **Environment:** DEBUG defaults to **mock**; DEBUG opts into live via the `--live` launch argument; **Release is always live**. Existing `--pucklab` / `--onboardinglab` / `--friends` DEBUG args keep working.
- **Reads-only** for migrated social data on Day 1. No client writes to live social tables.
- **No mock data in live sessions.** Live presence/push/feed reads return empty.
- **No direct Supabase access from Views or application ViewModels.** Only `AuthService` (and Supabase repositories) touch the SDK; an `AuthViewModel` may call an injected `AuthService`.
- **Secrets:** app ships only project URL + anon/publishable key. **Never** embed the service-role key.
- **IDs:** domain IDs stay opaque `String`; Supabase UUIDs map via `uuid.uuidString`. No domain ID type change.
- **Preserve** `AppDataContainer(seed:)`, all existing deterministic tests, and previews unchanged.
- **`sharing_policies` is the single source of truth for visibility.** `group_memberships` has no sharing column; `GroupMembership.sharingLevel` maps to `.full`.
- **`SECURITY DEFINER` hardening (every helper/trigger):** `set search_path = ''`, fully schema-qualified references, `revoke execute ... from public, anon`, `grant execute ... to authenticated` only where needed, single narrow responsibility, no dynamic SQL.
- **Advisor gate:** no unresolved **high-severity** `get_advisors(security)` findings from the new schema/RLS/`SECURITY DEFINER` objects.
- **Migrations are repo-first:** write the `.sql` file under `supabase/migrations/`, apply the identical SQL via MCP `apply_migration` with the same name. The remote is never the sole source.
- **supabase-swift version:** pin `from: "2.0.0"` (`import Supabase`). Auth is `client.auth`; Postgrest is `client.from(_:)`. If the resolved version's method labels differ, adapt the call sites — the types and responsibilities in this plan do not change.
- **Coding standards:** files ≤ 400 lines, functions ≤ 40 lines, named constants (no magic numbers), comments explain WHY. Commit after each task.
- **Test command (serial):**
  `xcodebuild test -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:PushTests -parallel-testing-enabled NO`
- **Register new app-target Swift files** with `python3 scripts/pbxproj_add.py <path relative to Push/>`; test files with `python3 scripts/pbxproj_add.py --target tests <path relative to PushTests/>`.
- **Test identities (created via real Supabase Auth, never SQL-seeded into `auth.users`):**
  - User A: `alice@push.test` / `push-test-alice`
  - User B: `bob@push.test` / `push-test-bob`
  - Unrelated third user (for deny tests): `carol@push.test` / `push-test-carol`

---

## File Structure

**Supabase (repo source of truth):**
- `supabase/migrations/0001_profiles.sql` — profiles table, self-RLS, signup trigger.
- `supabase/migrations/0002_friendships.sql` — friendships table, `is_friend`, friendship + friend-visibility RLS.
- `supabase/migrations/0003_groups.sql` — groups, group_memberships, `is_group_member`/`shares_group`, RLS.
- `supabase/migrations/0004_sharing_policies.sql` — sharing_policies table + RLS.
- `supabase/seed.sql` — idempotent, email-lookup public-graph seed (no `auth.users` writes).
- `supabase/README.md` — how to create the real Auth identities and run the seed.

**iOS — new:**
- `Push/Data/Supabase/SupabaseConfig.swift` — URL + anon key access.
- `Push/Data/Supabase/SupabaseClientProvider.swift` — single `SupabaseClient`.
- `Push/Data/Supabase/AppEnvironment.swift` — mock/live resolution.
- `Push/Data/Supabase/AuthService.swift` — protocol + Supabase impl + auth state.
- `Push/Data/Supabase/Rows/*.swift` — PostgREST row DTOs.
- `Push/Data/Supabase/SupabaseProfileRepository.swift`
- `Push/Data/Supabase/SupabaseFriendRepository.swift`
- `Push/Data/Supabase/SupabaseGroupRepository.swift`
- `Push/Data/Supabase/SupabaseSharingRepository.swift`
- `Push/Data/Supabase/EmptyLiveRepositories.swift` — empty push/feed (+ empty presence via friend repo).
- `Push/Auth/AuthViewModel.swift` — production auth VM.
- `Push/Auth/AuthGateView.swift` — production auth surface reusing promoted onboarding UI.
- `Push/RootView.swift` — environment + auth bootstrap.
- `Push/Config/Supabase.xcconfig` — `SUPABASE_URL`, `SUPABASE_ANON_KEY` (committed: URL + anon only).

**iOS — modified:**
- `Push/Data/AppDataContainer.swift` — mock/live factories + identity/change abstraction.
- `Push/PushApp.swift` — route to `RootView`.
- `Push/OnboardingLab/OnboardingLabTheme.swift`, `OnboardingLabComponents.swift` — remove `#if DEBUG` (promote to production).
- `Push/OnboardingLab/OnboardingSignInScreen.swift` + a new sign-up screen — promote and bind to an auth-form seam.
- `Push/OnboardingLab/OnboardingLabViewModel.swift` — conform to the auth-form seam (DEBUG).

**Tests — new:** `PushTests/AppEnvironmentTests.swift`, `PushTests/AuthViewModelTests.swift`, `PushTests/SupabaseMappingTests.swift`, `PushTests/LiveContainerIsolationTests.swift`, `PushTests/AuthBootstrapTests.swift`.

---

## PHASE 1 — Supabase backend (schema, RLS, seed)

### Task 1: `profiles` table, self-RLS, and signup trigger

**Files:**
- Create: `supabase/migrations/0001_profiles.sql`
- Verify: MCP `apply_migration`, `execute_sql`, `get_advisors`

**Interfaces:**
- Produces: `public.profiles(id uuid, first_name text, handle text, image_asset_path text, availability_choice text, visibility_note text, created_at, updated_at)`; trigger `public.handle_new_user()`.

- [ ] **Step 1: Write the migration SQL file**

```sql
-- supabase/migrations/0001_profiles.sql
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null default '',
  handle text not null unique,
  image_asset_path text,
  availability_choice text not null default 'free_now',
  visibility_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Owner can read and maintain only their own row (Day 1: no cross-user reads yet;
-- friend/group visibility is added in later migrations).
create policy profiles_select_self on public.profiles
  for select using ((select auth.uid()) = id);
create policy profiles_insert_self on public.profiles
  for insert with check ((select auth.uid()) = id);
create policy profiles_update_self on public.profiles
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Auto-create a profile row when a new auth user is created.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, first_name, handle)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'handle', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

- [ ] **Step 2: Apply via MCP and verify the table exists**

Apply with MCP `apply_migration` (name `0001_profiles`, query = file contents). Then MCP `execute_sql`:
`select count(*) from public.profiles;`
Expected: returns `0` (table exists, empty).

- [ ] **Step 3: Verify RLS is enabled and advisors are clean**

MCP `execute_sql`: `select relrowsecurity from pg_class where oid = 'public.profiles'::regclass;` → Expected `true`.
MCP `get_advisors(security)` → Expected: no high-severity finding referencing `public.profiles` or `public.handle_new_user`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0001_profiles.sql
git commit -m "feat(db): profiles table with self-RLS and signup trigger"
```

### Task 2: `friendships` table, `is_friend` helper, friend-visibility RLS

**Files:**
- Create: `supabase/migrations/0002_friendships.sql`

**Interfaces:**
- Consumes: `public.profiles`.
- Produces: `public.friendships(id, user_low, user_high, status, created_at)`; `public.is_friend(a uuid, b uuid) returns boolean`; a `profiles` SELECT policy allowing friends to read each other.

- [ ] **Step 1: Write the migration SQL file**

```sql
-- supabase/migrations/0002_friendships.sql
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles (id) on delete cascade,
  user_high uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'accepted',
  created_at timestamptz not null default now(),
  constraint friendships_ordered check (user_low < user_high),
  constraint friendships_unique_pair unique (user_low, user_high)
);
create index friendships_user_high_idx on public.friendships (user_high);

alter table public.friendships enable row level security;

-- Hardened helper: true when a and b have an accepted friendship (either order).
create function public.is_friend(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.user_low = a and f.user_high = b)
        or (f.user_low = b and f.user_high = a))
  );
$$;

revoke execute on function public.is_friend(uuid, uuid) from public, anon;
grant execute on function public.is_friend(uuid, uuid) to authenticated;

-- A user can read friendship rows they are part of.
create policy friendships_select_own on public.friendships
  for select using (
    (select auth.uid()) = user_low or (select auth.uid()) = user_high
  );

-- Friends can now read each other's profile.
create policy profiles_select_friends on public.profiles
  for select using (public.is_friend((select auth.uid()), id));
```

- [ ] **Step 2: Apply via MCP and verify the helper**

Apply (name `0002_friendships`). MCP `execute_sql`:
`select public.is_friend(gen_random_uuid(), gen_random_uuid());` → Expected `false` (no rows).

- [ ] **Step 3: Advisors**

MCP `get_advisors(security)` → Expected: no high-severity finding for `public.friendships` or `public.is_friend` (helper has fixed `search_path`, restricted grants).

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0002_friendships.sql
git commit -m "feat(db): friendships table, hardened is_friend, friend profile visibility"
```

### Task 3: `groups`, `group_memberships`, membership helpers, RLS

**Files:**
- Create: `supabase/migrations/0003_groups.sql`

**Interfaces:**
- Consumes: `public.profiles`.
- Produces: `public.groups(id, name, image_asset_path, created_at)`; `public.group_memberships(id, person_id, group_id, role, membership_status, joined_at)`; `public.is_group_member(u uuid, g uuid) returns boolean`; `public.shares_group(a uuid, b uuid) returns boolean`; RLS for groups/memberships + group-based profile visibility.

- [ ] **Step 1: Write the migration SQL file**

```sql
-- supabase/migrations/0003_groups.sql
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  image_asset_path text,
  created_at timestamptz not null default now()
);

create table public.group_memberships (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  role text not null default 'member',
  membership_status text not null default 'active',
  joined_at timestamptz not null default now(),
  constraint group_memberships_unique unique (person_id, group_id)
);
create index group_memberships_group_idx on public.group_memberships (group_id);
create index group_memberships_person_idx on public.group_memberships (person_id);

alter table public.groups enable row level security;
alter table public.group_memberships enable row level security;

-- Hardened: is u an active member of group g?
create function public.is_group_member(u uuid, g uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_memberships m
    where m.group_id = g and m.person_id = u and m.membership_status = 'active'
  );
$$;
revoke execute on function public.is_group_member(uuid, uuid) from public, anon;
grant execute on function public.is_group_member(uuid, uuid) to authenticated;

-- Hardened: do a and b share any active group?
create function public.shares_group(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_memberships ma
    join public.group_memberships mb on ma.group_id = mb.group_id
    where ma.person_id = a and mb.person_id = b
      and ma.membership_status = 'active' and mb.membership_status = 'active'
  );
$$;
revoke execute on function public.shares_group(uuid, uuid) from public, anon;
grant execute on function public.shares_group(uuid, uuid) to authenticated;

-- Read groups you actively belong to.
create policy groups_select_member on public.groups
  for select using (public.is_group_member((select auth.uid()), id));

-- Read memberships of groups you actively belong to (incl. your own row).
create policy group_memberships_select_comember on public.group_memberships
  for select using (public.is_group_member((select auth.uid()), group_id));

-- Co-members can read each other's profile.
create policy profiles_select_group on public.profiles
  for select using (public.shares_group((select auth.uid()), id));
```

- [ ] **Step 2: Apply via MCP and verify helpers**

Apply (name `0003_groups`). MCP `execute_sql`:
`select public.is_group_member(gen_random_uuid(), gen_random_uuid()), public.shares_group(gen_random_uuid(), gen_random_uuid());`
Expected: `false, false`.

- [ ] **Step 3: Advisors**

MCP `get_advisors(security)` → Expected: no high-severity finding for the new objects.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0003_groups.sql
git commit -m "feat(db): groups + memberships, hardened membership helpers, RLS"
```

### Task 4: `sharing_policies` table + RLS

**Files:**
- Create: `supabase/migrations/0004_sharing_policies.sql`

**Interfaces:**
- Consumes: `public.profiles`, `public.is_friend`, `public.is_group_member`.
- Produces: `public.sharing_policies(id, owner_person_id, audience_type, audience_id, location_visibility, activity_visibility, availability_visibility, expires_at)`; SELECT RLS scoped to owner or audience.

- [ ] **Step 1: Write the migration SQL file**

```sql
-- supabase/migrations/0004_sharing_policies.sql
create table public.sharing_policies (
  id uuid primary key default gen_random_uuid(),
  owner_person_id uuid not null references public.profiles (id) on delete cascade,
  audience_type text not null check (audience_type in ('friend', 'group', 'global_default')),
  audience_id uuid,
  location_visibility text not null default 'exact'
    check (location_visibility in ('exact', 'vague', 'hidden')),
  activity_visibility text not null default 'full'
    check (activity_visibility in ('full', 'vague', 'hidden')),
  availability_visibility text not null default 'full'
    check (availability_visibility in ('full', 'hidden')),
  expires_at timestamptz
);
create index sharing_policies_owner_idx on public.sharing_policies (owner_person_id);

alter table public.sharing_policies enable row level security;

-- You can read a policy if you own it, or if you are its audience:
--   friend policy targeting you, group policy for a group you're in,
--   or a global default owned by a friend.
create policy sharing_policies_select_relevant on public.sharing_policies
  for select using (
    owner_person_id = (select auth.uid())
    or (audience_type = 'friend' and audience_id = (select auth.uid()))
    or (audience_type = 'group' and public.is_group_member((select auth.uid()), audience_id))
    or (audience_type = 'global_default' and public.is_friend((select auth.uid()), owner_person_id))
  );
```

- [ ] **Step 2: Apply via MCP and verify**

Apply (name `0004_sharing_policies`). MCP `execute_sql`:
`select count(*) from public.sharing_policies;` → Expected `0`.

- [ ] **Step 3: Advisors**

MCP `get_advisors(security)` → Expected: no high-severity finding for `public.sharing_policies`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0004_sharing_policies.sql
git commit -m "feat(db): sharing_policies table with audience-scoped RLS"
```

### Task 5: Real-Auth test identities + idempotent public-graph seed + authenticated RLS proof

**Files:**
- Create: `supabase/seed.sql`, `supabase/README.md`

**Interfaces:**
- Consumes: all tables + `auth.users` rows for `alice@push.test`, `bob@push.test`.
- Produces: one mutual friendship, one shared group + two active memberships, default global sharing policies for A and B — keyed to the real auth IDs.

- [ ] **Step 1: Create the two identities through real Supabase Auth**

Use the anon key with GoTrue signup (no `auth.users` SQL). Get the anon key via MCP `get_publishable_keys`. Then, for each of A and B:

```bash
# Replace <ANON_KEY> with the publishable/anon key from get_publishable_keys.
curl -s -X POST 'https://tzzvwjhvjduyqywlszqc.supabase.co/auth/v1/signup' \
  -H 'Content-Type: application/json' -H 'apikey: <ANON_KEY>' \
  -d '{"email":"alice@push.test","password":"push-test-alice","data":{"first_name":"Alice","handle":"alice"}}'
curl -s -X POST 'https://tzzvwjhvjduyqywlszqc.supabase.co/auth/v1/signup' \
  -H 'Content-Type: application/json' -H 'apikey: <ANON_KEY>' \
  -d '{"email":"bob@push.test","password":"push-test-bob","data":{"first_name":"Bob","handle":"bob"}}'
```

Verify via MCP `execute_sql`: `select email from auth.users order by email;`
Expected: rows for `alice@push.test` and `bob@push.test` (the trigger also created their `public.profiles`).

- [ ] **Step 2: Write the idempotent seed (email lookup, no auth.users writes)**

```sql
-- supabase/seed.sql — reproducible public-graph seed keyed off real auth IDs.
do $$
declare a uuid; b uuid; g uuid;
begin
  select id into a from auth.users where email = 'alice@push.test';
  select id into b from auth.users where email = 'bob@push.test';
  if a is null or b is null then
    raise exception 'Seed requires alice@push.test and bob@push.test to exist (create them via Auth first)';
  end if;

  -- Ensure profile display fields (trigger already inserted the rows).
  update public.profiles set first_name = 'Alice', handle = 'alice' where id = a;
  update public.profiles set first_name = 'Bob', handle = 'bob' where id = b;

  -- Mutual friendship (canonical ordering).
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
```

- [ ] **Step 3: Apply the seed and verify graph rows**

Run the seed via MCP `execute_sql` (paste `seed.sql` body). Then MCP `execute_sql`:
`select (select count(*) from public.friendships) as f, (select count(*) from public.groups) as g, (select count(*) from public.group_memberships) as m, (select count(*) from public.sharing_policies) as p;`
Expected: `f=1, g=1, m=2, p=2`. Re-running the seed keeps the same counts (idempotent).

- [ ] **Step 4: Prove the full Auth → JWT → RLS → PostgREST path with real tokens (R7)**

Sign in as A to get a real access token, then read through PostgREST as A:

```bash
# Sign in as Alice.
curl -s -X POST 'https://tzzvwjhvjduyqywlszqc.supabase.co/auth/v1/token?grant_type=password' \
  -H 'Content-Type: application/json' -H 'apikey: <ANON_KEY>' \
  -d '{"email":"alice@push.test","password":"push-test-alice"}'    # -> capture .access_token as A_JWT

# Alice reads profiles: sees herself AND Bob (friend), not Carol.
curl -s 'https://tzzvwjhvjduyqywlszqc.supabase.co/rest/v1/profiles?select=handle' \
  -H 'apikey: <ANON_KEY>' -H "Authorization: Bearer <A_JWT>"
# Alice reads her shared group.
curl -s 'https://tzzvwjhvjduyqywlszqc.supabase.co/rest/v1/groups?select=name' \
  -H 'apikey: <ANON_KEY>' -H "Authorization: Bearer <A_JWT>"
```

Expected: profiles returns `alice` and `bob` only; groups returns `Test Crew`.

- [ ] **Step 5: Prove denial with an unrelated third user (R6)**

Create Carol via signup (Step 1 pattern, `carol@push.test`), sign her in for `C_JWT`, then:

```bash
curl -s 'https://tzzvwjhvjduyqywlszqc.supabase.co/rest/v1/groups?select=name' \
  -H 'apikey: <ANON_KEY>' -H "Authorization: Bearer <C_JWT>"
curl -s 'https://tzzvwjhvjduyqywlszqc.supabase.co/rest/v1/profiles?select=handle' \
  -H 'apikey: <ANON_KEY>' -H "Authorization: Bearer <C_JWT>"
```

Expected: groups returns `[]`; profiles returns only `carol` (Carol is neither friend nor co-member).

- [ ] **Step 6: Commit**

```bash
git add supabase/seed.sql supabase/README.md
git commit -m "feat(db): reproducible public-graph seed + authenticated RLS verification"
```

---

## PHASE 2 — iOS foundation (SDK, config, environment)

### Task 6: Add the `supabase-swift` package

**Files:**
- Modify: `Push.xcodeproj/project.pbxproj` (SwiftPM package ref + product dependency)

**Interfaces:**
- Produces: `import Supabase` available to the `Push` app target.

- [ ] **Step 1: Add the package in Xcode**

In Xcode: File ▸ Add Package Dependencies ▸ `https://github.com/supabase/supabase-swift` ▸ Dependency Rule "Up to Next Major" from `2.0.0` ▸ add the `Supabase` product to the `Push` target. (Committing `project.pbxproj` records the `XCRemoteSwiftPackageReference` + `packageProductDependencies`.)

- [ ] **Step 2: Verify it resolves and builds**

Run: `xcodebuild -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' build`
Expected: BUILD SUCCEEDED; `Package.resolved` lists `supabase-swift`.

- [ ] **Step 3: Commit**

```bash
git add Push.xcodeproj/project.pbxproj Push.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "chore: add supabase-swift package dependency"
```

### Task 7: Supabase config + client provider

**Files:**
- Create: `Push/Config/Supabase.xcconfig`, `Push/Data/Supabase/SupabaseConfig.swift`, `Push/Data/Supabase/SupabaseClientProvider.swift`
- Modify: `Push.xcodeproj/project.pbxproj` (register the two Swift files; set the xcconfig on Debug+Release), `Push/Info.plist` (surface the two keys)

**Interfaces:**
- Produces: `SupabaseConfig.url: URL`, `SupabaseConfig.anonKey: String`; `SupabaseClientProvider.shared.client: SupabaseClient`.

- [ ] **Step 1: Add the xcconfig (URL + anon key only — no secrets)**

```
// Push/Config/Supabase.xcconfig
SUPABASE_URL = https:/$()/tzzvwjhvjduyqywlszqc.supabase.co
SUPABASE_ANON_KEY = <paste anon/publishable key from get_publishable_keys>
```
Surface both in `Info.plist` as `SupabaseURL` = `$(SUPABASE_URL)` and `SupabaseAnonKey` = `$(SUPABASE_ANON_KEY)`, and assign `Supabase.xcconfig` to Debug and Release configs.

- [ ] **Step 2: Write `SupabaseConfig`**

```swift
// Push/Data/Supabase/SupabaseConfig.swift
import Foundation

enum SupabaseConfig {
    static var url: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL missing/invalid in Info.plist")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty else {
            fatalError("SupabaseAnonKey missing in Info.plist")
        }
        return key
    }
}
```

- [ ] **Step 3: Write `SupabaseClientProvider`**

```swift
// Push/Data/Supabase/SupabaseClientProvider.swift
import Foundation
import Supabase

/// Single shared SupabaseClient. Session persistence/restoration is handled by
/// the SDK's default local storage (Keychain on Apple platforms).
final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }
}
```

- [ ] **Step 4: Register files and build**

Run: `python3 scripts/pbxproj_add.py Data/Supabase/SupabaseConfig.swift` and `python3 scripts/pbxproj_add.py Data/Supabase/SupabaseClientProvider.swift`, then build.
Run: `xcodebuild -project Push.xcodeproj -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Push/Config/Supabase.xcconfig Push/Data/Supabase/SupabaseConfig.swift Push/Data/Supabase/SupabaseClientProvider.swift Push/Info.plist Push.xcodeproj/project.pbxproj
git commit -m "feat: Supabase config + shared client provider (anon key only)"
```

### Task 8: `AppEnvironment` selection (mock/live)

**Files:**
- Create: `Push/Data/Supabase/AppEnvironment.swift`, `PushTests/AppEnvironmentTests.swift`

**Interfaces:**
- Produces: `enum AppMode { case mock, live }`; `AppEnvironment.resolve(isDebugBuild:arguments:) -> AppMode`; `AppEnvironment.current: AppMode`.

- [ ] **Step 1: Write the failing test**

```swift
// PushTests/AppEnvironmentTests.swift
import XCTest
@testable import Push

final class AppEnvironmentTests: XCTestCase {
    func testDebugDefaultsToMock() {
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: true, arguments: []), .mock)
    }
    func testDebugOptsIntoLiveWithFlag() {
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: true, arguments: ["--live"]), .live)
    }
    func testReleaseAlwaysLive() {
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: false, arguments: []), .live)
        XCTAssertEqual(AppEnvironment.resolve(isDebugBuild: false, arguments: ["--live"]), .live)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run the serial test command with `-only-testing:PushTests/AppEnvironmentTests`.
Expected: FAIL (`AppEnvironment` undefined).

- [ ] **Step 3: Write the implementation**

```swift
// Push/Data/Supabase/AppEnvironment.swift
import Foundation

enum AppMode { case mock, live }

enum AppEnvironment {
    static let liveFlag = "--live"

    /// Release always live; Debug is mock unless `--live` is passed.
    static func resolve(isDebugBuild: Bool, arguments: [String]) -> AppMode {
        guard isDebugBuild else { return .live }
        return arguments.contains(liveFlag) ? .live : .mock
    }

    static var current: AppMode {
        #if DEBUG
        return resolve(isDebugBuild: true, arguments: ProcessInfo.processInfo.arguments)
        #else
        return resolve(isDebugBuild: false, arguments: ProcessInfo.processInfo.arguments)
        #endif
    }
}
```

- [ ] **Step 4: Register test file, run tests to verify pass**

Run: `python3 scripts/pbxproj_add.py --target tests AppEnvironmentTests.swift`, then the serial test command for `AppEnvironmentTests`.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Push/Data/Supabase/AppEnvironment.swift PushTests/AppEnvironmentTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: explicit mock/live environment resolution with tests"
```

---

## PHASE 3 — Authentication

### Task 9: `AuthService` protocol + Supabase implementation + fake

**Files:**
- Create: `Push/Data/Supabase/AuthService.swift`

**Interfaces:**
- Produces:
  - `struct AuthedUser: Equatable { let id: String; let email: String? }`
  - `protocol AuthService { var currentUser: AuthedUser? { get }; func restoreSession() async -> AuthedUser?; func signIn(email: String, password: String) async throws -> AuthedUser; func signUp(email: String, password: String) async throws -> AuthedUser; func signOut() async throws }`
  - `final class SupabaseAuthService: AuthService`
  - `final class FakeAuthService: AuthService` (test/preview double)

- [ ] **Step 1: Write the protocol, model, and Supabase implementation**

```swift
// Push/Data/Supabase/AuthService.swift
import Foundation
import Supabase

struct AuthedUser: Equatable {
    let id: String
    let email: String?
}

protocol AuthService {
    var currentUser: AuthedUser? { get }
    func restoreSession() async -> AuthedUser?
    func signIn(email: String, password: String) async throws -> AuthedUser
    func signUp(email: String, password: String) async throws -> AuthedUser
    func signOut() async throws
}

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient
    private(set) var currentUser: AuthedUser?

    init(client: SupabaseClient = SupabaseClientProvider.shared.client) {
        self.client = client
    }

    func restoreSession() async -> AuthedUser? {
        // The SDK loads any persisted session; `session` returns it or throws if none.
        guard let session = try? await client.auth.session else { return nil }
        let user = Self.map(session.user)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> AuthedUser {
        let session = try await client.auth.signIn(email: email, password: password)
        let user = Self.map(session.user)
        currentUser = user
        return user
    }

    func signUp(email: String, password: String) async throws -> AuthedUser {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = Self.map(response.user)
        currentUser = user
        return user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    private static func map(_ user: Auth.User) -> AuthedUser {
        AuthedUser(id: user.id.uuidString, email: user.email)
    }
}
```

- [ ] **Step 2: Add the fake in the same file**

```swift
// Push/Data/Supabase/AuthService.swift (append)
/// In-memory double for tests/previews — never touches the network.
final class FakeAuthService: AuthService {
    private(set) var currentUser: AuthedUser?
    var restorable: AuthedUser?
    var signInResult: Result<AuthedUser, Error>?

    init(restorable: AuthedUser? = nil) { self.restorable = restorable }

    func restoreSession() async -> AuthedUser? { currentUser = restorable; return restorable }

    func signIn(email: String, password: String) async throws -> AuthedUser {
        switch signInResult ?? .success(AuthedUser(id: "user-\(email)", email: email)) {
        case .success(let u): currentUser = u; return u
        case .failure(let e): throw e
        }
    }

    func signUp(email: String, password: String) async throws -> AuthedUser {
        let u = AuthedUser(id: "user-\(email)", email: email); currentUser = u; return u
    }

    func signOut() async throws { currentUser = nil }
}
```

- [ ] **Step 3: Register file and build**

Run: `python3 scripts/pbxproj_add.py Data/Supabase/AuthService.swift`, then build.
Expected: BUILD SUCCEEDED. (If the resolved SDK spells a label differently, e.g. `Auth.User` vs `User`, adjust the `map` signature only.)

- [ ] **Step 4: Commit**

```bash
git add Push/Data/Supabase/AuthService.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: AuthService protocol, Supabase impl, and test fake"
```

### Task 10: `AuthViewModel` + state-transition tests

**Files:**
- Create: `Push/Auth/AuthViewModel.swift`, `PushTests/AuthViewModelTests.swift`

**Interfaces:**
- Consumes: `AuthService`, `AuthedUser`.
- Produces: `@MainActor final class AuthViewModel: ObservableObject` with `@Published email/password/errorMessage/isBusy`, `@Published private(set) var authedUser: AuthedUser?`, `var canSubmit: Bool`, `func submitSignIn() async`, `func submitSignUp() async`, `func restore() async`.

- [ ] **Step 1: Write the failing test**

```swift
// PushTests/AuthViewModelTests.swift
import XCTest
@testable import Push

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testSuccessfulSignInPublishesUser() async {
        let vm = AuthViewModel(auth: FakeAuthService())
        vm.email = "alice@push.test"; vm.password = "push-test-alice"
        XCTAssertTrue(vm.canSubmit)
        await vm.submitSignIn()
        XCTAssertEqual(vm.authedUser?.email, "alice@push.test")
        XCTAssertNil(vm.errorMessage)
    }

    func testFailedSignInSurfacesError() async {
        let fake = FakeAuthService()
        fake.signInResult = .failure(NSError(domain: "auth", code: 401))
        let vm = AuthViewModel(auth: fake)
        vm.email = "x@push.test"; vm.password = "bad"
        await vm.submitSignIn()
        XCTAssertNil(vm.authedUser)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testCannotSubmitWithEmptyFields() {
        let vm = AuthViewModel(auth: FakeAuthService())
        XCTAssertFalse(vm.canSubmit)
    }

    func testRestoreAdoptsPersistedUser() async {
        let vm = AuthViewModel(auth: FakeAuthService(restorable: AuthedUser(id: "u1", email: "a@b.c")))
        await vm.restore()
        XCTAssertEqual(vm.authedUser?.id, "u1")
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Serial test command with `-only-testing:PushTests/AuthViewModelTests`.
Expected: FAIL (`AuthViewModel` undefined).

- [ ] **Step 3: Write the implementation**

```swift
// Push/Auth/AuthViewModel.swift
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published private(set) var authedUser: AuthedUser?

    private let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isBusy
    }

    func restore() async { authedUser = await auth.restoreSession() }

    func submitSignIn() async { await run { try await self.auth.signIn(email: self.email, password: self.password) } }
    func submitSignUp() async { await run { try await self.auth.signUp(email: self.email, password: self.password) } }

    private func run(_ action: @escaping () async throws -> AuthedUser) async {
        errorMessage = nil; isBusy = true
        defer { isBusy = false }
        do { authedUser = try await action() }
        catch { errorMessage = "Couldn't sign in. Check your email and password." }
    }
}
```

- [ ] **Step 4: Register test, run to verify pass**

Run: `python3 scripts/pbxproj_add.py Auth/AuthViewModel.swift`, `python3 scripts/pbxproj_add.py --target tests AuthViewModelTests.swift`, then the serial test command for `AuthViewModelTests`.
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Push/Auth/AuthViewModel.swift PushTests/AuthViewModelTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: AuthViewModel with sign-in/up/restore state transitions + tests"
```

---

## PHASE 4 — Supabase repositories + container

### Task 11: Row DTOs + `SupabaseProfileRepository` + mapping test

**Files:**
- Create: `Push/Data/Supabase/Rows/ProfileRow.swift`, `Push/Data/Supabase/SupabaseProfileRepository.swift`, `PushTests/SupabaseMappingTests.swift`

**Interfaces:**
- Consumes: `SupabaseClient`, `currentUserID: String`, domain `Person`/`UserProfile`, `ProfileRepository`.
- Produces: `struct ProfileRow: Decodable` + `ProfileRow.person()` / `ProfileRow.userProfile()`; `final class SupabaseProfileRepository: ProfileRepository`.

- [ ] **Step 1: Write the failing mapping test**

```swift
// PushTests/SupabaseMappingTests.swift
import XCTest
@testable import Push

final class SupabaseMappingTests: XCTestCase {
    func testProfileRowMapsToDomain() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","first_name":"Alice",
         "handle":"alice","image_asset_path":null,"availability_choice":"free_now",
         "visibility_note":""}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(ProfileRow.self, from: json)
        XCTAssertEqual(row.person().id, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(row.person().firstName, "Alice")
        XCTAssertEqual(row.userProfile().handle, "alice")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Serial test command with `-only-testing:PushTests/SupabaseMappingTests`. Expected: FAIL (`ProfileRow` undefined).

- [ ] **Step 3: Write `ProfileRow` (DTO + domain mapping)**

```swift
// Push/Data/Supabase/Rows/ProfileRow.swift
import Foundation

struct ProfileRow: Decodable {
    let id: String
    let first_name: String
    let handle: String
    let image_asset_path: String?
    let availability_choice: String
    let visibility_note: String

    func person() -> Person {
        Person(id: id, firstName: first_name, imageAssetPath: image_asset_path)
    }

    func userProfile() -> UserProfile {
        UserProfile(
            personID: id,
            handle: handle,
            chosenAvailability: FriendAvailabilityState(rawValue: availability_choice) ?? .freeNow,
            visibilityNote: visibility_note,
            availabilityOptions: [],   // Day-1 UI scaffolding synthesized client-side.
            activityVisibility: [],
            mapPreferences: [],
            closeFriends: [],
            connectors: []
        )
    }
}
```
(If `FriendAvailabilityState`'s raw values differ from `availability_choice` strings, add a small explicit mapping here rather than `rawValue:`.)

- [ ] **Step 4: Write `SupabaseProfileRepository`**

```swift
// Push/Data/Supabase/SupabaseProfileRepository.swift
import Foundation
import Supabase

final class SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient
    private let currentUserID: String

    init(client: SupabaseClient, currentUserID: String) {
        self.client = client
        self.currentUserID = currentUserID
    }

    func userProfile() async throws -> UserProfile {
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("id", value: currentUserID).limit(1).execute().value
        guard let row = rows.first else { throw SupabaseRepositoryError.notFound }
        return row.userProfile()
    }

    // Day 1 is reads-only for social data; writes are out of scope.
    func updateBasics(displayName: String, handle: String) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func updatePrivacy(activityVisibility: [ProfileToggleItem],
                       mapPreferences: [ProfileToggleItem],
                       closeFriends: [ProfileToggleItem]) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}

enum SupabaseRepositoryError: Error { case notFound, writeNotSupported }
```

- [ ] **Step 5: Register files, run tests to pass**

Register `Rows/ProfileRow.swift`, `SupabaseProfileRepository.swift`, and test file; run `SupabaseMappingTests`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Push/Data/Supabase/Rows/ProfileRow.swift Push/Data/Supabase/SupabaseProfileRepository.swift PushTests/SupabaseMappingTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: SupabaseProfileRepository + ProfileRow mapping"
```

### Task 12: `SupabaseFriendRepository` (friends, currentUser, empty presence)

**Files:**
- Create: `Push/Data/Supabase/SupabaseFriendRepository.swift`
- Modify: `PushTests/SupabaseMappingTests.swift` (add friend-row mapping test)

**Interfaces:**
- Consumes: `SupabaseClient`, `currentUserID`, `ProfileRow`, `FriendRepository`.
- Produces: `final class SupabaseFriendRepository: FriendRepository`. `friends()` reads friends' profiles; `currentUser()` reads own profile; `presenceStatuses()` returns `[]` (R1); `setCurrentUserAvailability` throws write-not-supported.

- [ ] **Step 1: Write the failing test (friends decode from a joined shape)**

```swift
// PushTests/SupabaseMappingTests.swift (add)
func testFriendProfileRowsDecode() throws {
    let json = """
    [{"id":"22222222-2222-2222-2222-222222222222","first_name":"Bob","handle":"bob",
      "image_asset_path":null,"availability_choice":"free_now","visibility_note":""}]
    """.data(using: .utf8)!
    let rows = try JSONDecoder().decode([ProfileRow].self, from: json)
    XCTAssertEqual(rows.map { $0.person().displayName }, ["Bob"])
}
```

- [ ] **Step 2: Run to verify it fails**

Serial test command for `SupabaseMappingTests/testFriendProfileRowsDecode`. Expected: FAIL until re-run after Step 3 (the type exists; assert the new case compiles/passes). If it already passes because `ProfileRow` exists, proceed — the repository still needs writing.

- [ ] **Step 3: Write the repository**

```swift
// Push/Data/Supabase/SupabaseFriendRepository.swift
import Foundation
import Supabase

final class SupabaseFriendRepository: FriendRepository {
    private let client: SupabaseClient
    private let currentUserID: String

    init(client: SupabaseClient, currentUserID: String) {
        self.client = client
        self.currentUserID = currentUserID
    }

    func currentUser() async throws -> Person {
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("id", value: currentUserID).limit(1).execute().value
        guard let row = rows.first else { throw SupabaseRepositoryError.notFound }
        return row.person()
    }

    /// Friends = every profile RLS lets us read that isn't us. RLS already scopes
    /// `profiles` reads to self + friends + co-members; excluding self yields friends
    /// (co-members are also friends in the Day-1 seed).
    func friends() async throws -> [Person] {
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().neq("id", value: currentUserID).execute().value
        return rows.map { $0.person() }
    }

    // Presence is out of scope on Day 1 — no live presence data (R1).
    func presenceStatuses() async throws -> [PresenceStatus] { [] }

    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
```

- [ ] **Step 4: Register file, run tests to pass**

Register the file; run `SupabaseMappingTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Push/Data/Supabase/SupabaseFriendRepository.swift PushTests/SupabaseMappingTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: SupabaseFriendRepository (empty live presence per Day-1 scope)"
```

### Task 13: `SupabaseGroupRepository` (groups, memberships; sharingLevel=.full)

**Files:**
- Create: `Push/Data/Supabase/Rows/GroupRow.swift`, `Push/Data/Supabase/Rows/GroupMembershipRow.swift`, `Push/Data/Supabase/SupabaseGroupRepository.swift`
- Modify: `PushTests/SupabaseMappingTests.swift`

**Interfaces:**
- Consumes: `SupabaseClient`, `GroupRepository`, domain `FriendGroup`/`GroupMembership`.
- Produces: `GroupRow.friendGroup()`, `GroupMembershipRow.membership()` (maps `sharingLevel: .full`, R3), `final class SupabaseGroupRepository: GroupRepository`.

- [ ] **Step 1: Write the failing membership-mapping test**

```swift
// PushTests/SupabaseMappingTests.swift (add)
func testMembershipRowDefaultsSharingLevelToFull() throws {
    let json = """
    {"id":"m1","person_id":"22222222-2222-2222-2222-222222222222",
     "group_id":"g1","role":"member","membership_status":"active",
     "joined_at":"2026-07-12T00:00:00Z"}
    """.data(using: .utf8)!
    let row = try JSONDecoder().decode(GroupMembershipRow.self, from: json)
    let m = row.membership()
    XCTAssertEqual(m.sharingLevel, .full)          // R3: policies are the visibility source, not membership.
    XCTAssertEqual(m.role, .member)
    XCTAssertEqual(m.membershipStatus, .active)
}
```

- [ ] **Step 2: Run to verify it fails**

Serial test command for the new test. Expected: FAIL (`GroupMembershipRow` undefined).

- [ ] **Step 3: Write the row DTOs + repository**

```swift
// Push/Data/Supabase/Rows/GroupRow.swift
import Foundation
struct GroupRow: Decodable {
    let id: String
    let name: String
    let image_asset_path: String?
    func friendGroup() -> FriendGroup {
        FriendGroup(id: id, name: name, imageAssetPath: image_asset_path)
    }
}
```

```swift
// Push/Data/Supabase/Rows/GroupMembershipRow.swift
import Foundation
struct GroupMembershipRow: Decodable {
    let id: String
    let person_id: String
    let group_id: String
    let role: String
    let membership_status: String
    let joined_at: Date

    func membership() -> GroupMembership {
        GroupMembership(
            id: id,
            personID: person_id,
            groupID: group_id,
            role: GroupMembership.Role(rawValue: role) ?? .member,
            sharingLevel: .full,   // R3: membership carries no visibility; policies are the source.
            membershipStatus: GroupMembership.Status(rawValue: membership_status) ?? .active,
            joinedAt: joined_at
        )
    }
}
```

```swift
// Push/Data/Supabase/SupabaseGroupRepository.swift
import Foundation
import Supabase

final class SupabaseGroupRepository: GroupRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func groups() async throws -> [FriendGroup] {
        let rows: [GroupRow] = try await client.from("groups").select().execute().value
        return rows.map { $0.friendGroup() }
    }

    func memberships() async throws -> [GroupMembership] {
        let rows: [GroupMembershipRow] = try await client.from("group_memberships")
            .select().execute().value
        return rows.map { $0.membership() }
    }
}
```
(The DTO decodes `joined_at` as ISO-8601; configure the shared decoder in Task 15 helper or set `.iso8601` on a per-repo `JSONDecoder`. If PostgREST returns fractional seconds, use a custom `DateDecodingStrategy` — noted in the shared decoder step.)

- [ ] **Step 4: Register files, run tests to pass**

Register the three files; run `SupabaseMappingTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Push/Data/Supabase/Rows/GroupRow.swift Push/Data/Supabase/Rows/GroupMembershipRow.swift Push/Data/Supabase/SupabaseGroupRepository.swift PushTests/SupabaseMappingTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: SupabaseGroupRepository; membership sharingLevel defaults to .full (R3)"
```

### Task 14: `SupabaseSharingRepository`

**Files:**
- Create: `Push/Data/Supabase/Rows/SharingPolicyRow.swift`, `Push/Data/Supabase/SupabaseSharingRepository.swift`
- Modify: `PushTests/SupabaseMappingTests.swift`

**Interfaces:**
- Consumes: `SupabaseClient`, `SharingRepository`, domain `SharingPolicy`.
- Produces: `SharingPolicyRow.policy()` (maps `global_default` → `.globalDefault`), `final class SupabaseSharingRepository: SharingRepository`.

- [ ] **Step 1: Write the failing test**

```swift
// PushTests/SupabaseMappingTests.swift (add)
func testSharingPolicyRowMapsGlobalDefault() throws {
    let json = """
    {"id":"p1","owner_person_id":"11111111-1111-1111-1111-111111111111",
     "audience_type":"global_default","audience_id":null,
     "location_visibility":"exact","activity_visibility":"full",
     "availability_visibility":"full","expires_at":null}
    """.data(using: .utf8)!
    let row = try JSONDecoder().decode(SharingPolicyRow.self, from: json)
    let p = row.policy()
    XCTAssertEqual(p.audienceType, .globalDefault)
    XCTAssertEqual(p.locationVisibility, .exact)
    XCTAssertNil(p.audienceID)
}
```

- [ ] **Step 2: Run to verify it fails**

Serial test command for the new test. Expected: FAIL (`SharingPolicyRow` undefined).

- [ ] **Step 3: Write the DTO + repository**

```swift
// Push/Data/Supabase/Rows/SharingPolicyRow.swift
import Foundation
struct SharingPolicyRow: Decodable {
    let id: String
    let owner_person_id: String
    let audience_type: String
    let audience_id: String?
    let location_visibility: String
    let activity_visibility: String
    let availability_visibility: String
    let expires_at: Date?

    func policy() -> SharingPolicy {
        SharingPolicy(
            id: id,
            ownerPersonID: owner_person_id,
            audienceType: mapAudience(audience_type),
            audienceID: audience_id,
            locationVisibility: SharingPolicy.LocationVisibility(rawValue: location_visibility) ?? .hidden,
            activityVisibility: SharingPolicy.DetailVisibility(rawValue: activity_visibility) ?? .hidden,
            availabilityVisibility: SharingPolicy.AvailabilityVisibility(rawValue: availability_visibility) ?? .hidden,
            expiresAt: expires_at
        )
    }

    private func mapAudience(_ raw: String) -> SharingPolicy.AudienceType {
        switch raw {
        case "friend": return .friend
        case "group": return .group
        default: return .globalDefault   // "global_default"
        }
    }
}
```

```swift
// Push/Data/Supabase/SupabaseSharingRepository.swift
import Foundation
import Supabase

final class SupabaseSharingRepository: SharingRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func allPolicies() async throws -> [SharingPolicy] {
        let rows: [SharingPolicyRow] = try await client.from("sharing_policies")
            .select().execute().value
        return rows.map { $0.policy() }
    }
}
```

- [ ] **Step 4: Register files, run tests to pass**

Register both files; run `SupabaseMappingTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Push/Data/Supabase/Rows/SharingPolicyRow.swift Push/Data/Supabase/SupabaseSharingRepository.swift PushTests/SupabaseMappingTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: SupabaseSharingRepository + policy row mapping"
```

### Task 15: Empty live push/feed repositories + shared decoder

**Files:**
- Create: `Push/Data/Supabase/EmptyLiveRepositories.swift`

**Interfaces:**
- Produces: `final class EmptyLivePushRepository: PushRepository`, `final class EmptyLiveFeedRepository: FeedRepository` — all reads return empty; all writes throw `SupabaseRepositoryError.writeNotSupported`.

- [ ] **Step 1: Write the empty repositories**

```swift
// Push/Data/Supabase/EmptyLiveRepositories.swift
import Foundation

/// Day-1 live mode has no pushes or feed (out of scope). Reads are empty;
/// writes are unsupported. This keeps mock data out of authenticated sessions (R1).
final class EmptyLivePushRepository: PushRepository {
    func activePlans() async throws -> [PushPlan] { [] }
    func responses() async throws -> [PushResponse] { [] }
    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout] { [] }
    func allPlaces() async throws -> [Place] { [] }
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func updatePush(planID: PushPlan.ID, with draft: PushDraft) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}

final class EmptyLiveFeedRepository: FeedRepository {
    func events() async throws -> [FeedEvent] { [] }
}
```

- [ ] **Step 2: Register file, build**

Register the file; build. Expected: BUILD SUCCEEDED (confirms these satisfy the current `PushRepository`/`FeedRepository` protocols exactly).

- [ ] **Step 3: Commit**

```bash
git add Push/Data/Supabase/EmptyLiveRepositories.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: empty live push/feed repositories (Day-1 out of scope)"
```

### Task 16: `AppDataContainer` mock/live factories + identity/change abstraction

**Files:**
- Modify: `Push/Data/AppDataContainer.swift`
- Create: `PushTests/LiveContainerIsolationTests.swift`

**Interfaces:**
- Consumes: all `Supabase*`/`EmptyLive*` repos, `SupabaseClient`, `currentUserID`.
- Produces: `AppDataContainer.live(client:currentUserID:referenceDate:)`; unchanged `AppDataContainer(seed:referenceDate:)`; `currentUserID`/`storeRevision`/`onStoreChange` sourced from an internal abstraction so live mode needs no `InMemoryDatabase`.

- [ ] **Step 1: Write the failing isolation test**

```swift
// PushTests/LiveContainerIsolationTests.swift
import XCTest
import Combine
@testable import Push

@MainActor
final class LiveContainerIsolationTests: XCTestCase {
    func testLiveContainerExposesNoMockPresenceOrPushesOrFeed() async throws {
        let container = AppDataContainer.live(
            client: SupabaseClientProvider.shared.client,
            currentUserID: "11111111-1111-1111-1111-111111111111"
        )
        // No network is exercised here: these live repos return empty synchronously.
        let presence = try await container.friends.presenceStatuses()
        let plans = try await container.pushes.activePlans()
        let events = try await container.feed.events()
        XCTAssertTrue(presence.isEmpty)
        XCTAssertTrue(plans.isEmpty)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(container.currentUserID, "11111111-1111-1111-1111-111111111111")
    }

    func testMockContainerStillSeedsData() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertFalse(friends.isEmpty)   // Existing behavior preserved.
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Serial test command for `LiveContainerIsolationTests`. Expected: FAIL (`AppDataContainer.live` undefined).

- [ ] **Step 3: Refactor `AppDataContainer` (additive; keep the seed init verbatim)**

```swift
// Push/Data/AppDataContainer.swift
import Combine
import Foundation
import Supabase

@MainActor
final class AppDataContainer {
    /// Active container. Mock by default; `RootView` installs a live one at bootstrap,
    /// before any ViewModel (which defaults to `.shared`) is created.
    static private(set) var shared = AppDataContainer(seed: .standard())

    /// Replace `.shared` with a live, session-scoped container. Called once at bootstrap.
    @discardableResult
    static func installLive(client: SupabaseClient, currentUserID: Person.ID) -> AppDataContainer {
        let container = live(client: client, currentUserID: currentUserID)
        shared = container
        return container
    }

    let friends: FriendRepository
    let groups: GroupRepository
    let pushes: PushRepository
    let profile: ProfileRepository
    let sharing: SharingRepository
    let feed: FeedRepository
    let referenceDate: Date

    let currentUserID: Person.ID
    /// Present only in mock mode; live mode has no local store (reads-only Day 1).
    private let database: InMemoryDatabase?
    private let liveRevision = CurrentValueSubject<Int, Never>(0)

    var storeRevision: Int { database?.revision ?? liveRevision.value }

    func onStoreChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable {
        if let database { return database.$revision.dropFirst().sink(receiveValue: handler) }
        return liveRevision.dropFirst().sink(receiveValue: handler)   // no-op in live Day 1.
    }

    /// MOCK: unchanged behavior — InMemoryDatabase + Local* repos.
    init(seed: SeedData, referenceDate: Date = Date()) {
        let database = InMemoryDatabase(seed: seed)
        self.database = database
        self.currentUserID = database.currentUserID
        self.referenceDate = referenceDate
        self.friends = LocalFriendRepository(database: database)
        self.groups = LocalGroupRepository(database: database)
        self.pushes = LocalPushRepository(database: database)
        self.profile = LocalProfileRepository(database: database)
        self.sharing = LocalSharingRepository(database: database)
        self.feed = LocalFeedRepository(database: database)
    }

    /// LIVE: Supabase-backed reads; identity from the auth session.
    static func live(client: SupabaseClient, currentUserID: Person.ID,
                     referenceDate: Date = Date()) -> AppDataContainer {
        AppDataContainer(
            currentUserID: currentUserID,
            referenceDate: referenceDate,
            friends: SupabaseFriendRepository(client: client, currentUserID: currentUserID),
            groups: SupabaseGroupRepository(client: client),
            pushes: EmptyLivePushRepository(),
            profile: SupabaseProfileRepository(client: client, currentUserID: currentUserID),
            sharing: SupabaseSharingRepository(client: client),
            feed: EmptyLiveFeedRepository()
        )
    }

    private init(currentUserID: Person.ID, referenceDate: Date,
                 friends: FriendRepository, groups: GroupRepository, pushes: PushRepository,
                 profile: ProfileRepository, sharing: SharingRepository, feed: FeedRepository) {
        self.database = nil
        self.currentUserID = currentUserID
        self.referenceDate = referenceDate
        self.friends = friends; self.groups = groups; self.pushes = pushes
        self.profile = profile; self.sharing = sharing; self.feed = feed
    }
}
```

- [ ] **Step 4: Register test, run the FULL suite (guard the shared refactor)**

Register the test file. Run the full serial `PushTests` command (not just the new file).
Expected: PASS — all pre-existing tests + the two new isolation tests. (This proves the mock path is byte-for-byte preserved.)

- [ ] **Step 5: Commit**

```bash
git add Push/Data/AppDataContainer.swift PushTests/LiveContainerIsolationTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: AppDataContainer.live factory + identity/change abstraction; mock path preserved"
```

---

## PHASE 5 — Auth UI promotion + bootstrap

### Task 17: Promote onboarding theme + components to production

**Files:**
- Modify: `Push/OnboardingLab/OnboardingLabTheme.swift`, `Push/OnboardingLab/OnboardingLabComponents.swift`

**Interfaces:**
- Produces: `OnboardingLabColor`, `OnboardingLabFont`, `OnboardingLabMetric`, `OnboardingCTAButton`, `OnboardingHeader`, `OnboardingAuthSwitchLink`, and the auth field/button building blocks compiled into Release (no behavior change).

- [ ] **Step 1: Remove the `#if DEBUG` / `#endif` guards from the two foundation files**

Delete the outermost `#if DEBUG` (top) and matching `#endif` (bottom) in `OnboardingLabTheme.swift` and `OnboardingLabComponents.swift` so the tokens/components exist in all configurations. (Keep every other line unchanged — this is the smallest promotion, no file reorg per R2.)

- [ ] **Step 2: Build for Release to confirm they compile without DEBUG**

Run: `xcodebuild -project Push.xcodeproj -scheme Push -configuration Release -destination 'platform=iOS Simulator,name=iPhone 14' build`
Expected: BUILD SUCCEEDED (theme + components now available in Release). If a promoted symbol references a still-DEBUG helper (e.g. `PushOnboardingControlStyle`), promote that specific declaration too — smallest set needed to compile.

- [ ] **Step 3: Commit**

```bash
git add Push/OnboardingLab/OnboardingLabTheme.swift Push/OnboardingLab/OnboardingLabComponents.swift
git commit -m "refactor: promote onboarding theme + components out of DEBUG for production auth"
```

### Task 18: Auth-form seam + promote sign-in/sign-up screens

**Files:**
- Modify: `Push/OnboardingLab/OnboardingSignInScreen.swift` (promote; bind to a seam), `Push/OnboardingLab/OnboardingLabViewModel.swift` (conform to seam, DEBUG)
- Create: `Push/Auth/AuthFormModel.swift`, `Push/Auth/AuthGateView.swift`

**Interfaces:**
- Produces:
  - `protocol AuthFormModel: ObservableObject { var email: String { get set }; var password: String { get set }; var errorMessage: String? { get }; var canSubmit: Bool { get }; func submitPrimary() async; func switchMode() }`
  - `AuthGateView` — production sign-in/sign-up surface reusing the promoted components, driven by `AuthViewModel`.

- [ ] **Step 1: Write the auth-form seam**

```swift
// Push/Auth/AuthFormModel.swift
import Foundation

/// Shared surface the promoted onboarding auth views bind to, so the same
/// screen serves the production AuthViewModel and the DEBUG lab view model.
@MainActor
protocol AuthFormModel: ObservableObject {
    var email: String { get set }
    var password: String { get set }
    var errorMessage: String? { get }
    var canSubmit: Bool { get }
    func submitPrimary() async
}

extension AuthViewModel: AuthFormModel {
    func submitPrimary() async { await submitSignIn() }
}
```

- [ ] **Step 2: Build the production `AuthGateView` reusing promoted components**

```swift
// Push/Auth/AuthGateView.swift
import SwiftUI

/// Production auth surface. Reuses the promoted onboarding header/CTA/field
/// components and the same warm styling; backed by real Supabase auth.
struct AuthGateView: View {
    @ObservedObject var model: AuthViewModel
    var onAuthenticated: (AuthedUser) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(title: "Welcome back",
                             subtitle: "Sign in to pick up right where you left off.")
            fields.padding(.top, 26)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            OnboardingCTAButton(title: "Sign in") { Task { await submit() } }
                .padding(.top, 22)
                .disabled(!model.canSubmit)
                .opacity(model.canSubmit ? 1 : 0.5)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding)
        .padding(.top, OnboardingLabMetric.contentTopInset)
        .padding(.bottom, 26)
        .onChange(of: model.authedUser) { _, user in if let user { onAuthenticated(user) } }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            AuthField(systemImage: "envelope.fill", placeholder: "Email",
                      text: $model.email, isSecure: false)
            AuthField(systemImage: "lock.fill", placeholder: "Password",
                      text: $model.password, isSecure: true)
        }
    }

    private func submit() async { await model.submitPrimary() }
}

/// Production copy of the credential row (mirrors the promoted onboarding field
/// styling). Kept here so the shipping auth screen owns its input control.
private struct AuthField: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingLabColor.walnut)
                .frame(width: 22)
            Group {
                if isSecure { SecureField(placeholder, text: $text) }
                else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
            }
            .font(OnboardingLabFont.text(17, .medium))
            .foregroundStyle(OnboardingLabColor.espresso)
            .tint(OnboardingLabColor.walnut)
        }
        .padding(.horizontal, 18)
        .frame(height: OnboardingLabMetric.fieldHeight)
        .background(OnboardingLabColor.fieldFill,
                    in: RoundedRectangle(cornerRadius: OnboardingLabMetric.fieldCornerRadius, style: .continuous))
    }
}
```
(Rationale for a production `AuthField` rather than un-DEBUGing the lab screen's `private` field: it is the smallest change that reuses the promoted tokens/components without pulling the lab's `OnboardingLabViewModel`, keypad, and fixtures into Release — honoring "reuse the experience" + "smallest refactor, no reorg for purity". The DEBUG lab keeps its own `OnboardingSignInScreen` for the sandbox.)

- [ ] **Step 3: Register files, build Debug + Release**

Register `Push/Auth/AuthFormModel.swift` and `Push/Auth/AuthGateView.swift`. Build both configurations.
Expected: BUILD SUCCEEDED for Debug and Release.

- [ ] **Step 4: Commit**

```bash
git add Push/Auth/AuthFormModel.swift Push/Auth/AuthGateView.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: production AuthGateView reusing promoted onboarding auth UI"
```

### Task 19: Root bootstrap (environment + session gating)

**Files:**
- Create: `Push/RootView.swift`, `PushTests/AuthBootstrapTests.swift`
- Modify: `Push/PushApp.swift`

**Interfaces:**
- Consumes: `AppEnvironment`, `AuthService`, `AuthViewModel`, `AppDataContainer`, `AuthGateView`, `ContentView`.
- Produces: `RootView` that renders mock `ContentView` in `.mock`; in `.live` shows `AuthGateView` until authenticated, then `ContentView` on a live container. `BootstrapState` (pure enum) drives it and is unit-tested.

- [ ] **Step 1: Write the failing bootstrap-state test**

```swift
// PushTests/AuthBootstrapTests.swift
import XCTest
@testable import Push

@MainActor
final class AuthBootstrapTests: XCTestCase {
    func testMockModeSkipsAuthGate() {
        XCTAssertEqual(BootstrapState.initial(mode: .mock, restored: nil), .app(nil))
    }
    func testLiveWithNoSessionShowsGate() {
        XCTAssertEqual(BootstrapState.initial(mode: .live, restored: nil), .gate)
    }
    func testLiveWithRestoredSessionShowsApp() {
        let u = AuthedUser(id: "u1", email: "a@b.c")
        XCTAssertEqual(BootstrapState.initial(mode: .live, restored: u), .app(u))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Serial test command for `AuthBootstrapTests`. Expected: FAIL (`BootstrapState` undefined).

- [ ] **Step 3: Write `RootView` + `BootstrapState`**

```swift
// Push/RootView.swift
import SwiftUI

/// Pure, testable description of what the root should show.
enum BootstrapState: Equatable {
    case loading
    case gate
    case app(AuthedUser?)   // nil user = mock mode (identity comes from the seed container).

    static func initial(mode: AppMode, restored: AuthedUser?) -> BootstrapState {
        switch mode {
        case .mock: return .app(nil)
        case .live: return restored.map { .app($0) } ?? .gate
        }
    }
}

struct RootView: View {
    @StateObject private var authModel: AuthViewModel
    @State private var state: BootstrapState = .loading
    private let mode: AppMode
    private let auth: AuthService

    init(mode: AppMode = AppEnvironment.current,
         auth: AuthService = SupabaseAuthService()) {
        self.mode = mode
        self.auth = auth
        _authModel = StateObject(wrappedValue: AuthViewModel(auth: auth))
    }

    var body: some View {
        content
            .task {
                guard case .loading = state else { return }
                let restored = mode == .live ? await auth.restoreSession() : nil
                enter(.initial(mode: mode, restored: restored))
            }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .gate:
            AuthGateView(model: authModel) { user in enter(.app(user)) }
        case .app:
            ContentView()   // ViewModels default to AppDataContainer.shared (installed in `enter`).
        }
    }

    /// Install the live container BEFORE flipping to `.app`, so `ContentView`'s
    /// @StateObject ViewModels capture the live `.shared`, not the mock one.
    /// Mock mode keeps the default seed container.
    private func enter(_ next: BootstrapState) {
        if case .app(let user?) = next {
            AppDataContainer.installLive(
                client: SupabaseClientProvider.shared.client, currentUserID: user.id
            )
        }
        state = next
    }
}
```
(This reuses the existing `container: AppDataContainer = .shared` default every ViewModel already has — the smallest wiring, no per-VM changes and no new Environment key. `installLive` runs in `enter(_:)` before the state flips, so it precedes `ContentView`'s ViewModel construction.)

- [ ] **Step 4: Point `PushApp` at `RootView`**

```swift
// Push/PushApp.swift  (body)
WindowGroup {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--pucklab") { PuckLabView() }
    else if ProcessInfo.processInfo.arguments.contains("--onboardinglab") { OnboardingLabView() }
    else if ProcessInfo.processInfo.arguments.contains("--friends") { FriendsView() }
    else { RootView() }
    #else
    RootView()
    #endif
}
```

- [ ] **Step 5: Register files, run bootstrap tests + full suite**

Register `RootView.swift` and the test. Run `AuthBootstrapTests` (Expected: PASS 3), then the full serial `PushTests` suite (Expected: all pass — mock default unchanged).

- [ ] **Step 6: Commit**

```bash
git add Push/RootView.swift Push/PushApp.swift PushTests/AuthBootstrapTests.swift Push.xcodeproj/project.pbxproj
git commit -m "feat: RootView environment + session bootstrap; default mock unchanged"
```

---

## PHASE 6 — End-to-end verification + docs

### Task 20: End-to-end live verification against real Supabase

**Files:** none (verification task; captures evidence)

- [ ] **Step 1: Run mock default and confirm parity**

Run the full serial `PushTests` suite and launch the app with no arguments (Debug). Expected: today's mock app; all tests green (Success Criterion 8).

- [ ] **Step 2: Run live and verify the Day-1 criteria as user A**

Launch with `--live` (Debug scheme argument). Expected, in order:
1. No session → `AuthGateView`.
2. Sign in `alice@push.test` / `push-test-alice` → app appears.
3. Relaunch the app (still `--live`) → **stays signed in** (session restored).
4. Profile screen shows Alice's profile.
5. Friends screen shows **Bob** as a friend (calm "Hidden right now" row — no live presence per R1).
6. Groups screen shows **Test Crew** with Alice + Bob.
7. No error state on sharing-policy load.

- [ ] **Step 3: Verify symmetry as user B**

Sign out, sign in `bob@push.test` / `push-test-bob`. Expected: Bob sees Alice as a friend and the same Test Crew group (Success Criterion 7).

- [ ] **Step 4: Final advisor + authenticated-RLS gate**

MCP `get_advisors(security)` → Expected: no unresolved **high-severity** findings from the new schema/RLS/`SECURITY DEFINER` objects (R10). Re-confirm the Task 5 authenticated REST checks still pass (allow for A/B, deny for Carol) (R6/R7).

- [ ] **Step 5: Commit evidence (if any) / no-op**

```bash
git commit --allow-empty -m "test: verified Day-1 live auth + social reads end-to-end"
```

### Task 21: Documentation + lessons

**Files:**
- Modify: `docs/data-architecture.md` (add a "Live (Supabase) mode" subsection), `tasks/lessons.md` (create if missing), `tasks/todo.md`

- [ ] **Step 1: Document the live seam**

In `docs/data-architecture.md`, add a subsection under "Swapping to Supabase later" noting it is now implemented for Day-1 reads: `AppDataContainer.live`, the four Supabase repos, empty presence/push/feed, environment selection, and that `sharing_policies` is the sole visibility source.

- [ ] **Step 2: Capture lessons**

In `tasks/lessons.md`, record: hardened `SECURITY DEFINER` pattern (`set search_path = ''` + restricted grants), the SPM-in-pbxproj friction, the auth-form promotion approach, and the authenticated-REST RLS verification recipe.

- [ ] **Step 3: Final full-suite run**

Run the full serial `PushTests` command. Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add docs/data-architecture.md tasks/lessons.md tasks/todo.md
git commit -m "docs: document live Supabase mode and Day-1 lessons"
```

---

## Self-Review Notes (traceability to spec)

- **R1 (empty live presence):** Tasks 12 (`presenceStatuses → []`), 15 (empty push/feed), 16 isolation test, 20 Step 2.5.
- **R2 (reuse onboarding auth):** Tasks 17–18 (promote theme/components; production gate reuses them; lab untouched).
- **R3 (one visibility source):** Task 3 (no `sharing_level` column), Task 13 (`sharingLevel: .full` + test), Task 4/14 (`sharing_policies`).
- **R4 (real-Auth test users):** Task 5 (signup via GoTrue; email-lookup idempotent seed; no `auth.users` SQL).
- **R5 (explicit env):** Task 8 + tests; Task 19 routing.
- **R6 (hardened SECURITY DEFINER + deny tests):** Tasks 1–3 (fixed `search_path`, restricted grants), Task 5 Step 5 (Carol deny).
- **R7 (full-path RLS):** Task 5 Step 4 (real JWT via PostgREST), Task 20 Step 4.
- **R8 (layered tests):** env (8), auth VM (10), mapping (11–14), isolation (16), bootstrap (19).
- **R9 (abstraction rule):** `AuthService`/repos are the only SDK callers; `AuthViewModel` calls injected `AuthService`; no root-coordinator overcentralization.
- **R10 (advisor gate):** Tasks 1–4 per-migration advisor checks + Task 20 Step 4.
- **Preserved:** `AppDataContainer(seed:)` (Task 16), full mock suite green (Tasks 16/19/20/21).
