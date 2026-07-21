# Complete production email authentication (Issue #32)

**Date:** 2026-07-17  
**Issue:** [kaavlu/Push#32](https://github.com/kaavlu/Push/issues/32)  
**Status:** Approved design — ready for implementation plan

## Problem

Live auth only supports email/password **sign-in**. Sign-up and social buttons surface “coming soon,” there is no forgot/reset password path, and new accounts still require dashboard (or manual Auth API) setup. Production needs a complete email path so real users can register, recover, and enter the live app.

## Goals / done when

- A new user can register with email and enter the live app (no dashboard-created account).
- Display name and handle are collected at sign-up and persisted on the profile row.
- Both immediate-session and email-confirmation-required sign-up behaviors work.
- A returning user can request a password reset, open the recovery link in-app, set a new password, and sign back in.
- Common auth failures show useful, calm copy.
- Unimplemented auth methods (Apple / Google / phone) are **hidden**, not stubbed with “coming soon.”

## Non-goals

- Real Apple, Google, or phone auth.
- Full post-auth onboarding lab (privacy, location, contacts, friends discovery).
- Universal Links / Associated Domains (custom URL scheme only for this issue).
- Changing Supabase email HTML templates beyond documenting redirect allow-list needs.
- Mock-mode auth gate (DEBUG mock still skips auth and uses seed).

## Product decisions

| Decision | Choice |
|---|---|
| Password recovery | In-app reset via deep link |
| Sign-up surface | Single form: name, handle, email, password |
| Deep link mechanism | Custom URL scheme `pushapp://auth/reset` |
| Architecture | Extend existing auth gate (`AuthService` → `AuthViewModel` → gate views) |

## User flows

### New user (sign-up)

1. Welcome → **Continue with email** → sign-up form (display name, handle, email, password).
2. Submit → `AuthService.signUp`.
3. **Immediate session** (Confirm email OFF / autoconfirm): publish `AuthedUser` → same `RootView` path as sign-in (`.preparing` → warm snapshot → `.app`).
4. **Confirmation required** (no session): stay on gate, show **Check your email**; primary action returns to Sign in.

Profile row is created by existing `handle_new_user` trigger from signup `raw_user_meta_data` (`first_name`, `handle`).

### Returning user (sign-in)

1. Welcome → **Sign in** (or switch link from sign-up).
2. Email + password → existing prepare/app path.
3. **Forgot password?** → email field → send recovery email → success copy (no account enumeration).

### Password reset (deep link)

1. User taps link in email; OS opens `pushapp://auth/reset…`.
2. App exchanges/establishes recovery session from the URL.
3. Gate shows **Set new password** (password + confirm).
4. `updatePassword` → if session present, prepare/app; else return to Sign in with clear success guidance.
5. Missing/expired recovery session → “This reset link expired. Request a new one.” and path back to Forgot password.

## Architecture

### Layering (unchanged project rules)

- Only `AuthService` talks to GoTrue (`import Supabase` only in the auth/repo layer).
- `AuthViewModel` owns form state, screen routing, busy/errors, and service calls.
- Views are dumb: bind fields, call VM methods.
- Application ViewModels still do not call Supabase directly.

### Approach

**Extend the existing production auth gate** (not a separate coordinator module, not hosted Auth UI). Smallest change that matches Day-1 patterns and stays testable via `FakeAuthService`.

### `AuthService` expansion

```text
protocol AuthService {
  var currentUser: AuthedUser? { get }
  func restoreSession() async -> AuthedUser?
  func signIn(email: String, password: String) async throws -> AuthedUser
  func signUp(email: String, password: String, displayName: String, handle: String) async throws -> SignUpResult
  func resetPasswordRequest(email: String) async throws
  func updatePassword(newPassword: String) async throws -> AuthedUser
  func signOut() async throws
  /// Establish recovery (or other) session from an inbound auth URL, if applicable.
  func handleAuthURL(_ url: URL) async throws -> AuthURLResult
}

enum SignUpResult: Equatable {
  case authenticated(AuthedUser)
  case confirmationRequired(email: String)
}

enum AuthURLResult: Equatable {
  case passwordRecovery  // ready for updatePassword
  case ignored           // not an auth callback we handle
}
```

- `signUp` passes user metadata `first_name` + `handle` so `public.handle_new_user` fills `profiles`.
- Immediate session → `.authenticated`; user created but no session → `.confirmationRequired`.
- Recovery email redirect URL: `pushapp://auth/reset` (must be on Supabase Auth redirect allow-list).
- `FakeAuthService` gains configurable results for sign-up, reset, update-password, and auth URL handling.

### Gate screens

```text
enum AuthGateScreen: Equatable {
  case welcome
  case signUp
  case signIn
  case checkEmail
  case forgotPassword
  case setNewPassword
}
```

### Views

| View | Role |
|---|---|
| `AuthWelcomeView` | Hero + **Continue with email** + Sign in switch link; **no** Apple/Google/mobile |
| `AuthSignUpView` | Name, handle, email, password + submit |
| `AuthSignInView` | Email, password, Forgot password?, Sign up switch; **no** social |
| `AuthCheckEmailView` | Confirmation-required after sign-up |
| `AuthForgotPasswordView` | Email + send reset link |
| `AuthSetNewPasswordView` | New password + confirm after deep link |

Reuse promoted onboarding components (`OnboardingCredentialField`, `OnboardingCTAButton`, `OnboardingHeader`, `OnboardingAuthSwitchLink`, theme). Remove production `ComingSoonToast` / `requestUnavailable` paths once social stubs are gone.

### Deep link wiring

- Register custom URL scheme **`pushapp`** on the app target (Info.plist / generated Info.plist keys).
- `PushApp` / `RootView` handle `onOpenURL`.
- On live mode: call `AuthService.handleAuthURL`; on `.passwordRecovery`, force gate navigation to `.setNewPassword` (even if previously in-app, prefer returning to auth UI for recovery).
- Implementation detail of token exchange follows supabase-swift 2.x APIs available in-tree; keep parsing inside `SupabaseAuthService`.

### Form binding

Extend `AuthFormModel` (or small per-screen binding surfaces) so production screens share email/password/error/busy patterns without forcing every field onto one protocol. Sign-up and set-password add name/handle/confirm fields on the VM.

### Bootstrap interaction

- Unchanged: authenticated user → `BootstrapState.preparing` → `AppDataContainer.prepareLive` → `.app`.
- Sign-up confirmation path never installs live container until a real session exists.
- `signOutReset` clears new fields and returns to `.welcome`.

## Validation

| Field | Rules |
|---|---|
| Email | Non-empty after trim; basic shape (`@` + domain with `.`) |
| Password (sign-in) | Non-empty |
| Password (sign-up / set-new) | ≥ 8 characters |
| Confirm password | Must match new password |
| Display name | Non-empty after trim |
| Handle | 3–20 chars; lowercase letters, numbers, underscore only |

`canSubmit` (per screen) is false while `isBusy` or any required field for that screen is invalid.

## Error mapping

Map failures in one place (`AuthErrorMapper` or private VM helper). Never show raw SDK strings.

| Condition | User-facing copy |
|---|---|
| Wrong email/password | Couldn't sign in. Check your email and password. |
| Email already registered | That email already has an account. Try signing in. |
| Invalid / weak password | Choose a stronger password (at least 8 characters). |
| Handle taken (if API surfaces it) | That handle is taken. Try another. |
| Rate limited | Too many attempts. Wait a moment and try again. |
| Network / unknown | Something went wrong. Check your connection and try again. |
| Reset request (success UX always) | If an account exists for that email, we sent a reset link. |
| Recovery session missing/expired | This reset link expired. Request a new one. |
| Confirmation required | Not an error — `checkEmail` screen |

## Config & ops notes

Document in `supabase/README.md` (or adjacent auth note):

- Redirect URL allow-list must include `pushapp://auth/reset`.
- Confirm email ON and OFF are both supported by `SignUpResult`.
- Test identities remain real Auth users; sign-up no longer requires dashboard creation for new people.
- App still ships only project URL + anon key.

No new DB migration required for the happy path: `handle_new_user` already reads `first_name` / `handle` from metadata. Unique `profiles.handle` conflicts remain a possible failure if the trigger insert races or metadata is empty — client validates handle shape; mapper covers “taken” if exposed.

## Testing plan

### Automated

- **`AuthViewModelTests`** (extend):
  - Screen navigation: welcome ↔ sign-up ↔ sign-in ↔ forgot ↔ check-email.
  - Sign-up → authenticated publishes user.
  - Sign-up → confirmationRequired sets check-email, no `authedUser`.
  - Sign-in failure mapping.
  - Forgot password always shows non-enumerating success copy (even if fake “fails” optionally still success UX if product chooses always-success — default: map service success to that copy; service errors → network copy).
  - Set password success / expired recovery.
  - Field clearing on screen switches and `signOutReset`.
  - No remaining “coming soon” production path tests required once removed.
- **`FakeAuthService`**: `signUpResult`, `resetPasswordResult`, `updatePasswordResult`, `authURLResult`.
- Optional pure helper test for URL classification if parsing is non-trivial.
- Register new Swift files via `scripts/pbxproj_add.py`.
- Verify with `scripts/test.sh` scoped to auth/bootstrap suites + `build` (not full suite every edit).

### Manual / live smoke

1. New email sign-up → profile name/handle visible → map/app loads.
2. Sign-up with Confirm email ON (if enabled in project) → check-email UI.
3. Forgot password → receive email → open `pushapp://…` on Simulator/device → set password → enter app or sign in.
4. Wrong password / duplicate email show mapped copy.
5. Confirm Apple/Google/phone controls are gone from welcome and sign-in.

## File touch list (expected)

| Area | Files |
|---|---|
| Service | `Push/Data/Supabase/AuthService.swift` |
| VM / form | `Push/Auth/AuthViewModel.swift`, `AuthFormModel.swift` |
| Gate | `AuthGateView.swift`, `AuthWelcomeView.swift`, `AuthSignInView.swift` |
| New views | `AuthSignUpView.swift`, `AuthCheckEmailView.swift`, `AuthForgotPasswordView.swift`, `AuthSetNewPasswordView.swift` (names flexible) |
| App entry | `PushApp.swift`, `RootView.swift` (URL handling / scheme) |
| Config | `Info.plist` or build settings for URL scheme |
| Tests | `PushTests/AuthViewModelTests.swift` (+ optional URL tests) |
| Docs | `supabase/README.md`, `tasks/spec.md` / `tasks/todo.md` as needed |

## Implementation order (high level)

1. Expand `AuthService` + fake + `SignUpResult` / URL handling.
2. Expand `AuthViewModel` validation, navigation, error mapping, tests first where practical.
3. Wire views + gate routing; strip social / coming soon.
4. Register `pushapp` scheme + `onOpenURL`.
5. Docs + live smoke.

## Open implementation details (not product blockers)

- Exact supabase-swift API for recovery URL session exchange (inspect package usage at implement time; keep behind `handleAuthURL`).
- Whether password update after recovery leaves a full session or requires explicit sign-in (handle both in VM).
- Handle uniqueness: prefer client validation + mapper; no new RPC in this issue unless live testing proves trigger failures need a dedicated pre-check.
