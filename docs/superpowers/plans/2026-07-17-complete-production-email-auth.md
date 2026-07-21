# Complete Production Email Auth Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox syntax for tracking. Spec: `docs/superpowers/specs/2026-07-17-complete-production-email-auth-design.md`.

**Goal:** Finish production email authentication so new users can sign up (name + handle), confirm-email path works, and returning users can reset password in-app via `pushapp://auth/reset`.

**Architecture:** Extend `AuthService` → `AuthViewModel` → `AuthGateView` screens. No Supabase in Views. Custom URL scheme + `auth.session(from:)`. Profile row still created by `handle_new_user` from signup metadata.

**Tech Stack:** SwiftUI, supabase-swift Auth (GoTrue), existing onboarding UI components.

## Global Constraints

- MVVM; only `AuthService` imports/talks to Supabase.
- Files ≤ 400 lines; functions ≤ 40 lines.
- No magic numbers — named constants.
- Register new Swift files with `python3 scripts/pbxproj_add.py`.
- Tests via `scripts/test.sh`; prefer `AuthViewModelTests` + build.
- Hide Apple/Google/phone on production auth (do not stub “coming soon”).
- Redirect URL: `pushapp://auth/reset`.

## File map

| File | Responsibility |
|---|---|
| `Push/Data/Supabase/AuthService.swift` | Protocol, `SignUpResult`, `AuthURLResult`, Supabase + Fake impls, error mapper |
| `Push/Data/Supabase/SupabaseClientProvider.swift` | Default `redirectToURL` for auth flows |
| `Push/Auth/AuthViewModel.swift` | Screens, validation, submit actions, deep-link handler |
| `Push/Auth/AuthFormModel.swift` | Shared form binding seam |
| `Push/Auth/AuthGateView.swift` | Route all gate screens |
| `Push/Auth/AuthWelcomeView.swift` | Continue with email + sign in |
| `Push/Auth/AuthSignInView.swift` | Sign in + forgot link; no social |
| `Push/Auth/AuthSignUpView.swift` | Name, handle, email, password |
| `Push/Auth/AuthCheckEmailView.swift` | Confirmation-required |
| `Push/Auth/AuthForgotPasswordView.swift` | Request reset |
| `Push/Auth/AuthSetNewPasswordView.swift` | Set password after recovery |
| `Push/Info.plist` | `CFBundleURLTypes` for `pushapp` |
| `Push/RootView.swift` / `PushApp.swift` | `onOpenURL` → recovery gate |
| `PushTests/AuthViewModelTests.swift` | Coverage for new flows |
| `supabase/README.md` | Redirect allow-list note |

---

### Task 1: AuthService + Fake + error mapper

**Files:** Modify `Push/Data/Supabase/AuthService.swift`, `SupabaseClientProvider.swift`

- [ ] Expand protocol with `SignUpResult`, `AuthURLResult`, metadata sign-up, reset, update password, `handleAuthURL`
- [ ] Implement `SupabaseAuthService` using `signUp(data:)`, `resetPasswordForEmail`, `update(user:)`, `session(from:)`
- [ ] Configure client `redirectToURL = pushapp://auth/reset`
- [ ] `AuthUserMessage.message(for:context:)` maps `AuthError` codes to copy
- [ ] Expand `FakeAuthService` for tests
- [ ] Build

### Task 2: AuthViewModel + tests

**Files:** `AuthViewModel.swift`, `AuthFormModel.swift`, `AuthViewModelTests.swift`

- [ ] Screens: welcome, signUp, signIn, checkEmail, forgotPassword, setNewPassword
- [ ] Fields: displayName, handle, email, password, confirmPassword
- [ ] Per-screen `canSubmit*` + validation
- [ ] `submitSignUp` handles both `SignUpResult` cases
- [ ] Forgot always non-enumerating success copy on service success; map network errors
- [ ] `handleOpenURL` → setNewPassword without publishing `authedUser` until password update
- [ ] Remove `requestUnavailable` / coming soon from production path
- [ ] Tests green via `scripts/test.sh suite AuthViewModelTests`

### Task 3: Auth views + gate routing

**Files:** Gate + welcome/sign-in + new views; extend credential field if needed for name keyboard

- [ ] Wire all screens in `AuthGateView`
- [ ] Welcome: Continue with email CTA; strip social
- [ ] Sign-in: Forgot password; strip social
- [ ] New screens for sign-up, check email, forgot, set password
- [ ] Register files in pbxproj
- [ ] Build

### Task 4: URL scheme + RootView open URL

**Files:** `Info.plist`, `RootView.swift`, optionally `PushApp.swift`

- [ ] Register `pushapp` URL scheme
- [ ] `onOpenURL` → `authModel.handleOpenURL`; enter `.gate` on recovery
- [ ] Build + auth tests

### Task 5: Docs + todo + verify

- [ ] `supabase/README.md` redirect note
- [ ] `tasks/todo.md` progress
- [ ] Final build + AuthViewModelTests + AuthBootstrapTests
