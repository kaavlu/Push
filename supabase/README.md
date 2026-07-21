# Supabase (Push — Day 1)

Project ref: `tzzvwjhvjduyqywlszqc` · URL: `https://tzzvwjhvjduyqywlszqc.supabase.co`

The **repo is the source of truth** for schema, RLS, helpers, and the public-graph
seed. Migrations under `migrations/` were authored here and applied to the remote via
the Supabase MCP `apply_migration` (recorded in migration history). A from-scratch run
of the files in order reproduces the schema.

## Layout
- `migrations/0001_profiles.sql` — `profiles` (id == `auth.users.id`), self-RLS, hardened
  `handle_new_user` signup trigger (auto-creates a profile row per new auth user).
- `migrations/0002_friendships.sql` — `friendships` (mutual, `user_low < user_high`),
  `private.is_friend`, friend profile visibility. Creates the non-API-exposed `private`
  schema that holds all `SECURITY DEFINER` RLS helpers.
- `migrations/0003_groups.sql` — `groups`, `group_memberships` (membership only; **no**
  visibility column — `sharing_policies` is the sole visibility source), `private.is_group_member`,
  `private.shares_group`, RLS.
- `migrations/0004_sharing_policies.sql` — `sharing_policies` (sole visibility source) +
  audience-scoped SELECT RLS.
- `migrations/0005_profile_settings.sql` — adds `settings_activity_visibility`,
  `settings_map_preferences`, `settings_close_friends` (`jsonb`, nullable) to `profiles`
  for the profile screen's toggle overrides. No RLS change: covered by the existing
  `profiles_update_self` policy.
- `migrations/0009_friend_requests.sql` — `friendships.requested_by` + pending/accepted/denied
  status checks; `search_profiles`, `send_friend_request`, and `resolve_friend_request`
  RPCs; pending-pair profile SELECT policy for Alerts/Add Friends.
- `migrations/0013_friend_relationship_lifecycle.sql` — `cancel_friend_request` (requester,
  pending only, hard-delete); race-safe `send_friend_request` (unique_violation re-read);
  `remove_friend` deletes any status between the pair so re-request starts clean.
  Applied remotely via MCP (`list_migrations` includes `0013_friend_relationship_lifecycle`).
- `migrations/0012_profile_photos.sql` (+ `0012b_…_select_own`) — public `avatars`
  Storage bucket; owner-only SELECT/INSERT/UPDATE/DELETE under `{auth.uid()}/…`.
  No listable public SELECT (public object URLs still work). App stores the public
  object URL on existing `profiles.image_asset_path`.
- `seed.sql` — idempotent public-graph seed keyed off **real** auth IDs (resolved by email).

## Security model
- All app tables have RLS enabled from creation.
- `SECURITY DEFINER` helpers live in the `private` schema (not exposed by PostgREST), with a
  fixed `search_path = ''`, `execute` revoked from `public`/`anon`, granted to `authenticated`.
- The iOS app ships only the project URL + anon/publishable key. The service-role key is
  never used by the app.

## Test identities (created via REAL Supabase Auth — never SQL-inserted)
`.test`/`.example` TLDs are rejected by GoTrue's validator, so real-TLD emails are used.
The project may have **"Confirm email" OFF** (`mailer_autoconfirm = true`) for immediate
sessions, or ON for a confirmation email — the iOS client handles both via `SignUpResult`
(`.authenticated` vs `.confirmationRequired`).

### Auth deep links (Issue #32)
- Custom URL scheme: `pushapp`
- Password recovery redirect: `pushapp://auth/reset`
- Add that URL under Authentication → URL Configuration → Redirect URLs in the
  Supabase dashboard (and keep it in sync if the scheme changes).
- The shared `SupabaseClient` sets `redirectToURL` to the same value so recovery and
  related auth emails open the app.

| Role | Email | Password | In graph? |
|---|---|---|---|
| A | `alice@pushapp.dev` | `push-test-alice` | friend of B, owner of Test Crew |
| B | `bob@pushapp.dev` | `push-test-bob` | friend of A, member of Test Crew |
| C (deny test) | `carol@pushapp.dev` | `push-test-carol` | intentionally unrelated |

### Recreate from scratch
1. Ensure Authentication → Email → **Confirm email = OFF**.
2. Create A/B/C via real Auth signup (anon key), e.g.:
   ```bash
   curl -s -X POST "$URL/auth/v1/signup" -H 'Content-Type: application/json' \
     -H "apikey: $ANON_KEY" \
     -d '{"email":"alice@pushapp.dev","password":"push-test-alice","data":{"first_name":"Alice","handle":"alice"}}'
   ```
   The `handle_new_user` trigger creates each `profiles` row automatically.
3. Run `seed.sql` (via MCP `execute_sql` or `psql`) to add the friendship, group,
   memberships, and sharing policies. It is idempotent.

## Verified (Day 1)
Authenticated PostgREST reads with a real JWT:
- Alice → profiles `[alice, bob]`, groups `[Test Crew]`, 2 memberships, 2 policies.
- Carol → profiles `[carol]` only, groups `[]`, memberships `[]` (RLS deny).
- Security advisors: no findings after all migrations.
