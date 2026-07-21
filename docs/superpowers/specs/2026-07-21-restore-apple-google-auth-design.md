# Restore Apple and Google authentication (Issue #61)

**Date:** 2026-07-21  
**Issue:** [kaavlu/Push#61](https://github.com/kaavlu/Push/issues/61)  
**Status:** Implementation design

## Problem

Production auth supports email/password only. Apple and Google buttons were removed when email auth shipped so they would not show dead “coming soon” paths. Returning users and new users need both social providers wired to Supabase Auth on the existing gate.

## Goals / done when

- Welcome and Sign in surfaces show **Continue with Apple** and **Continue with Google**.
- Both providers create a Supabase session (new account or returning user) and enter the same `RootView` prepare → app path as email.
- `handle_new_user` still creates a `profiles` row; first-sign-in name from Apple (when provided) is written to metadata + profile.
- Cancellations are silent; provider/network failures use calm copy; duplicate-account style errors point users to email sign-in when appropriate.
- Mock mode still skips the auth gate.
- Dashboard/provider setup is documented (Apple Client IDs, Google OAuth, redirect URLs).

## Non-goals

- Phone / SMS auth.
- Full post-auth onboarding lab (privacy, contacts, friends discovery).
- Account linking UI (“connect Google to existing email password account”).
- Google Sign-In SDK (native Google button SDK) — use system web auth session + Supabase OAuth instead.
- Changing email/password flows.

## Product decisions

| Decision | Choice |
|---|---|
| Apple | Native `AuthenticationServices` → `signInWithIdToken` |
| Google | Supabase OAuth via `ASWebAuthenticationSession` → `signInWithOAuth` |
| Surfaces | Welcome + Sign in (not Sign up form; social is an alternative entry) |
| Profile | Trigger creates row; best-effort name fill from Apple full name / provider metadata |
| Redirect | `pushapp://auth/callback` for OAuth; keep `pushapp://auth/reset` for recovery |
| Architecture | Extend `AuthService` → `AuthViewModel` → gate views only |

## User flows

### New or returning (Apple)

1. Tap Continue with Apple on welcome or sign-in.
2. System Apple sheet; user authorizes (or cancels → stay on gate, no error).
3. App exchanges identity token with Supabase → session.
4. On first authorize, Apple may supply a full name → save `first_name` on auth metadata and profile when empty.
5. Publish `AuthedUser` → existing prepare/app path. Session persists via SDK Keychain.

### New or returning (Google)

1. Tap Continue with Google.
2. In-app browser (`ASWebAuthenticationSession`) completes Google → Supabase callback `pushapp://auth/callback`.
3. Session established inside the OAuth call (PKCE); same prepare/app path.
4. Cancel closes the session with no error banner.

### Deep link edge case

If an OAuth callback URL is delivered via `onOpenURL` instead of the web-auth session completion, treat it as **signed in** (not password recovery). Recovery remains host/path/`type=recovery` only.

## Architecture

### `AuthService`

```text
func signInWithApple() async throws -> AuthedUser
func signInWithGoogle() async throws -> AuthedUser
```

- `import Supabase` and `AuthenticationServices` only in the auth/data layer (not Views).
- `FakeAuthService` exposes configurable results for unit tests.
- Cancellation maps to `SocialAuthError.cancelled` (or AS error codes) so the VM does not show an error.

### `AuthViewModel`

- `signInWithApple()` / `signInWithGoogle()` set `isBusy`, publish `authedUser` on success.
- Extend `AuthURLResult` with `.signedIn` for non-recovery callbacks.
- `AuthFailureContext.socialSignIn` + copy for rate limits, identity/email conflicts, generic failures.

### UI

- Reuse `OnboardingAuthButton` (already production-ready).
- Shared `AuthSocialButtons` + `AuthOrDivider` for welcome and sign-in.
- Welcome order: Apple → Google → Continue with email → Sign in link → legal.
- Sign-in: email/password → Forgot → or → Apple/Google → Sign up link.

### Backend

- Migration hardens `handle_new_user`: sanitize handle, unique-suffix on collision, prefer `first_name` / `full_name` / `name` / `given_name` from metadata.
- No new public RPCs.

## Dashboard / device config (operator)

1. **Apple:** App ID `com.manav.Push` with Sign in with Apple; list bundle ID under Supabase Auth → Providers → Apple → Client IDs; app entitlements include Sign in with Apple.
2. **Google:** Web client ID + secret on Supabase Google provider; enable provider.
3. **Redirect URLs:** add `pushapp://auth/callback` (and keep `pushapp://auth/reset`) under Auth URL configuration.
4. Simulator: Apple Sign In needs a signed-in iCloud Apple ID on the simulator; Google OAuth works in the web session on simulator and device.

## Testing

- Unit: social success publishes user; cancel leaves nil error; mapped conflict copy; OAuth deep link → signed in without recovery screen; recovery deep link unchanged.
- Build: `scripts/test.sh suite AuthViewModelTests` + `scripts/test.sh build`.
- Live smoke (manual): both providers with dashboard configured.

## Risks

- Handle uniqueness failures historically could leave no profile row → prepare fails. Mitigated by migration suffix loop.
- Apple name only on first consent; later sign-ins leave name empty if never stored.
- Google provider must be enabled remotely or the button will fail with calm generic/network copy.
