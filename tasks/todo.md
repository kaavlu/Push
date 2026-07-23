# Issue #61 — Restore Apple and Google Authentication

**Issue:** https://github.com/kaavlu/Push/issues/61  
**Design:** `docs/superpowers/specs/2026-07-21-restore-apple-google-auth-design.md`

## Status

- [x] Design: native Apple id-token + Google OAuth web session
- [x] `AuthService.signInWithApple` / `signInWithGoogle` + FakeAuthService
- [x] Apple presentation (`SocialAuthSignIn`) with nonce
- [x] Auth URL: `.signedIn` vs password recovery
- [x] Welcome + Sign in UI (Apple / Google)
- [x] Sign in with Apple entitlements
- [x] Migration `0017_oauth_profile_handle` (applied remotely via MCP)
- [x] Unit tests for social + OAuth callback
- [x] Fix pre-existing FriendRepository test doubles for full test compile
- [ ] Dashboard: enable Apple Client IDs + Google provider + redirect URLs (operator)
- [ ] Live smoke on simulator/device with providers configured

## Verification

- [x] `scripts/test.sh suite AuthViewModelTests` — 25/25, 0 failures
- [x] `scripts/test.sh suite AuthBootstrapTests` — 4/4, 0 failures
- [ ] `scripts/test.sh build`
