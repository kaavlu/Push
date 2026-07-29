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
- `migrations/0016_user_blocks.sql` — directed `user_blocks`, `private.is_blocked`,
  `block_user` / `unblock_user` / `list_blocked_users`; guards friend request, search,
  group invite, and creator-seeded push_responses; soft-hide policy (no hard-delete of
  historical pushes/groups). Shared group membership unchanged on block.
- `migrations/0017_oauth_profile_handle.sql` — hardens `handle_new_user` for OAuth
  (name metadata keys, sanitized unique handles with suffix on collision).
- `migrations/0014_delete_account.sql` — parameterless `delete_account()` RPC
  (`SECURITY DEFINER`, `authenticated` only): best-effort avatars cleanup, group
  ownership transfer (earliest other active member) or group delete when sole
  active, remove memberships/friendships, then `DELETE FROM auth.users` for
  `auth.uid()` (profiles and cascading FKs follow). No target-user argument.
- `migrations/0018_current_presence.sql` — canonical `current_presence` (one row per
  user): orthogonal `is_published`, exact/vague coords (nullable for unpublish),
  availability mirror of `profiles.availability_choice`, expiry, RLS (self +
  friend/co-member excluding blocked/unpublished/expired/legacy-ghost), RPCs
  `unpublish_current_presence()` and `set_availability_choice(text)`. No seed rows.
  Verify with `tests/0018_current_presence_verify.sql` after apply (privileged SQL).
- `migrations/0020_current_presence_realtime.sql` — add `public.current_presence` to
  publication `supabase_realtime` (idempotent) so authenticated clients can receive
  `postgres_changes` for friend-visible presence (Issue #84). RLS still filters rows
  per JWT; app bridge patches `LiveDataStore` and reconciles on gaps.
- `migrations/0021_moments_tables.sql` — `moments` / `moment_members` / `moment_media`
  (Issue #117 S1): soft-delete, `UNIQUE(push_id)` including soft-deleted rows, feed
  index, RLS enabled, **SELECT grant only** (no client writes).
- `migrations/0022_moments_private_helpers.sql` — `private.can_view_moment` and related
  helpers (friends-of-tagged + block-aware media); SELECT policies only. Mutation RPCs
  and Storage deferred (S2/S3). Verify with `tests/0021_moments_verify.sql`.
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

### Auth deep links (Issue #32 / #61)
- Custom URL scheme: `pushapp`
- Password recovery redirect: `pushapp://auth/reset`
- OAuth callback (Google web session): `pushapp://auth/callback`
- Add both URLs under Authentication → URL Configuration → Redirect URLs in the
  Supabase dashboard (and keep them in sync if the scheme changes).
- The shared `SupabaseClient` default `redirectToURL` is the recovery URL; Google
  OAuth passes `pushapp://auth/callback` per call.

### Google provider (Issue #61; Apple currently disabled)
- **Apple (native):** Temporarily removed from the app target so Personal Team
  provisioning works (no `com.apple.developer.applesignin` entitlement). Re-enable
  Sign in with Apple on App ID `com.manav.Push` and list the bundle ID under
  Supabase Auth → Providers → Apple → Client IDs when restoring the flow.
- **Google (OAuth web session):** Create a Google Cloud OAuth **Web** client ID +
  secret; authorize redirect
  `https://tzzvwjhvjduyqywlszqc.supabase.co/auth/v1/callback`. Paste client ID and
  secret into Supabase Auth → Providers → Google and enable the provider.
- Profile rows for new OAuth users still come from `handle_new_user`
  (`0017_oauth_profile_handle` hardens handle uniqueness and name metadata keys).

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
