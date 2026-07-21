# Foreground Refresh & Mutation Errors (Issue #33)

- [x] `LiveDataStore.refresh` + `AppDataContainer.refreshSession` + tests
- [x] Foreground re-warm on `ContentView` (skip first active)
- [x] `ActionErrorState` + `ActionErrorBanner`
- [x] Plans RSVP/cancel/delete rollback + pull-to-refresh
- [x] Friends remove retry + pull-to-refresh (Groups mode shares list)
- [x] Alerts soft load + accept/deny action errors + pull-to-refresh
- [x] Add Group create uses shared banner
- [x] Focused suites: LiveDataStoreTests, PlansViewModelTests, AlertsTests; build SUCCEEDED

## Verification
- [x] `scripts/test.sh build` SUCCEEDED
- [x] PlansViewModelTests 24/24, AlertsTests 8/8, LiveDataStoreTests 13/13

---

# Complete production email authentication (Issue #32)

- [x] Design: `docs/superpowers/specs/2026-07-17-complete-production-email-auth-design.md`
- [x] Plan: `docs/superpowers/plans/2026-07-17-complete-production-email-auth.md`
- [x] `AuthService`: sign-up with name/handle metadata, `SignUpResult`, reset/update password, `handleAuthURL`, error mapper
- [x] Client redirect `pushapp://auth/reset` + Info.plist URL scheme
- [x] `AuthViewModel` screens, validation, deep-link recovery without early app entry
- [x] Views: welcome (email only), sign-up, sign-in + forgot, check-email, set-new-password
- [x] `RootView.onOpenURL` → recovery gate
- [x] Focused tests + `supabase/README.md` redirect notes

## Verification
- [x] `scripts/test.sh suite AuthViewModelTests` — 20 tests, 0 failures
- [ ] Live smoke: new sign-up, forgot → open `pushapp://` → set password (needs dashboard redirect allow-list)

---

# Issue #34 — Persistent Profile Photo Uploads

- [x] Spec in `tasks/spec.md`
- [x] Migration `0012_profile_photos` (avatars bucket + storage RLS) applied via MCP
- [x] `ProfilePhotoProcessor` + `AvatarImageLoader` + avatar view remote support
- [x] `ProfileRepository` photo APIs — Local + Supabase write-through
- [x] ProfileView / ViewModel photo picker + remove
- [x] Focused tests + pbxproj registration
- [x] Build + focused test suites

## Verification
- [x] `scripts/test.sh build` SUCCEEDED
- [x] ProfilePhotoTests: 8 tests, 0 failures
- [x] LiveDataStoreTests: 8 tests, 0 failures
- [x] Migration `0012_profile_photos` applied; `avatars` bucket public; storage policies present

---

# Production Branding Assets (Issue #35)

- [x] Audit production asset catalog, launch settings, and design tokens.
- [x] Write the production-branding contract in `tasks/spec.md`.
- [x] Add and register the production app icon.
- [x] Define AccentColor and launch-background catalog colors.
- [x] Configure native generated launch branding.
- [x] Verify generic Release build and archive contents.

## Verification
- [x] Generic iOS Simulator Release build succeeded.
- [x] Unsigned generic iOS Release archive succeeded.
- [x] Archived app contains compiled `Assets.car`, iPhone/iPad app-icon PNGs, and one valid
      `UILaunchScreen` dictionary resolving `LaunchBackground`.
