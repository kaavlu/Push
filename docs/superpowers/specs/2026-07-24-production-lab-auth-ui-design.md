# Production auth uses Onboarding Lab UI (auth-only)

**Date:** 2026-07-24  
**Status:** Approved — implementation in progress  
**Scope:** Auth gate only (no post-auth privacy / location / notifications / contacts)

## Problem

Production live auth (`AuthGateView` + `Auth*View`) reuses onboarding **components** but is a thinner parallel stack: no lab shell (gradient, back chrome), single-screen sign-up instead of the lab multi-step feel, and the designed welcome/sign-in flow lives primarily under `#if DEBUG` in Onboarding Lab.

## Goals

- Production gate **looks and navigates like** the lab auth path (welcome, multi-step email sign-up, sign-in, recovery).
- All actions remain wired through `AuthViewModel` → `AuthService` (no Supabase in Views).
- One implementation of shared auth screens where practical; DEBUG lab keeps mock phone/setup steps.

## Non-goals

- Phone / SMS auth
- Post-auth privacy, location permission primer, notifications, contacts/friends discovery
- ~~Profile photo upload at sign-up~~ — **now supported**: pick on profile step, upload after live prepare (or first post-confirm sign-in); soft-fail if Storage fails
- Sign in with Apple
- Issue #50 first-run in-app checklist

## Product flow

```
Welcome
  ├─ Google → session → RootView prepare → app
  ├─ Continue with email → Profile (name, handle) → Credentials (email, password) → signUp
  │     ├─ authenticated → prepare → app
  │     └─ confirmationRequired → Check email → Sign in
  └─ Sign in
        ├─ email/password → session → prepare → app
        ├─ Google → session → prepare → app
        └─ Forgot password → (deep link) Set new password
```

No mobile number CTA on production welcome.

## Architecture

| Piece | Role |
|---|---|
| `AuthViewModel` | Screen routing, validation, busy/errors, service calls, back stack for multi-step sign-up |
| `AuthGateView` | Lab shell: warm gradient, optional back chevron, screen router + transitions |
| Auth screens | Dumb views bound to `AuthViewModel` |
| `AuthService` | Unchanged contracts (`signUp`, `signIn`, Google, recovery URL) |
| Onboarding Lab | DEBUG sandbox for non-prod steps; may share hero fixtures / components |

### `AuthGateScreen`

```text
welcome
signUpProfile
signUpCredentials
signIn
checkEmail
forgotPassword
setNewPassword
```

Replaces the single `signUp` case with a two-step profile → credentials path.

### Navigation rules

| From | Back / secondary |
|---|---|
| `signUpProfile` | → `welcome` |
| `signUpCredentials` | → `signUpProfile` (keeps name/handle/photo) |
| `signIn` | → `welcome` |
| `forgotPassword` | → `signIn` |
| `setNewPassword` | Request new link → `forgotPassword` |
| `checkEmail` | Primary: Back to sign in |
| `welcome` | No back |

`showSignUp()` lands on `signUpProfile` and clears credentials + name/handle + pending photo.  
`continueSignUpProfile()` advances only when name + handle are valid (photo optional).  
`submitSignUp()` only from credentials when full `canSubmitSignUp` is true.  
Optional photo: JPEG held on the VM → after `prepareLive`, `RootView` uploads via `ProfileRepository.updateProfilePhoto` (soft-fail).  
Email confirm redirect uses `pushapp://auth/callback` (not reset) so confirm links are not treated as recovery.

### Validation (unchanged rules)

| Field | Rule |
|---|---|
| Display name | Non-empty after trim |
| Handle | 3–20 chars; `a-z`, `0-9`, `_` only (lowercased) |
| Email | Basic `@` + domain with `.` |
| Password (sign-up / new) | ≥ 8 characters |
| Sign-in password | Non-empty |

### Visual parity

- Full-gate gradient: `OnboardingLabColor.screenTop/Mid/Bottom`
- Back button: lab circular material chevron
- Shared components: `OnboardingHeader`, `OnboardingCredentialField`, `OnboardingCTAButton`, `OnboardingAuthButton` / `AuthSocialButtons`, `OnboardingAuthSwitchLink`, `LegalConsentText`
- Welcome hero: shared non-DEBUG puck fixtures (not lab-only fixtures)
- No progress bar on auth-only gate (progress is for lab setup steps)

## Testing

Extend `AuthViewModelTests`:

- `showSignUp` → `.signUpProfile`
- Invalid profile blocks advance; valid profile → `.signUpCredentials`
- Back from credentials returns to profile with name/handle preserved
- `canSubmitSignUp` still requires all fields
- Existing sign-up success / check-email / sign-in / recovery / Google tests updated for new screen enum

Verify: `scripts/test.sh suite AuthViewModelTests` + `scripts/test.sh build`

## File touch list

| Area | Files |
|---|---|
| Spec | `docs/superpowers/specs/2026-07-24-production-lab-auth-ui-design.md` |
| VM | `Push/Auth/AuthViewModel.swift` |
| Gate | `Push/Auth/AuthGateView.swift` |
| Screens | `AuthWelcomeView`, `AuthSignInView`, `AuthSignUpView` (profile), new credentials view, recovery screens (shell only) |
| Fixtures | Promote welcome hero pucks for prod + lab reuse |
| Lab | Point intro welcome hero at shared fixtures if easy; keep mock steps DEBUG |
| Tests | `PushTests/AuthViewModelTests.swift` |
