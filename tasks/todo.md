# Harden Release Configuration and Observability (Issue #37)

## Completed
- [x] Audited existing Release/mock isolation (`AppEnvironment.resolve`, `#if DEBUG` lab routes,
      `AppDataContainer.installPreparedLive` gating) — already correct, no changes needed.
- [x] `Push/Diagnostics/PushLog.swift`: categorized `os.Logger`s, `safeDescription(for:)`
      PII-redaction helper (type name + `PostgrestError.code` only, never message/detail/hint),
      generic `logged<T>` run-and-log-on-failure wrapper, `logStartupBanner(mode:)`.
- [x] `Push/Diagnostics/CrashReporter.swift`: MetricKit `MXMetricManagerSubscriber`, registered
      once in `PushApp.init()`. Apple-native, no third-party dependency.
- [x] `SupabaseConfig.isProductionHost(_:)` runtime guard — `fatalError`s on a non-`.supabase.co`
      host instead of shipping a misconfigured `xcconfig` silently; logs the resolved host only.
- [x] `SupabaseLiveDataLoader` (all ~22 methods, the single live PostgREST/RPC network boundary)
      routed through `PushLog.logged` for PII-free backend-failure logging.
- [x] `RootView` bootstrap logging: startup banner (version/build/mode), session-restore outcome,
      live-data-preparation success/failure — on-screen failure message left untouched.
- [x] Fix round (Task 5 review): added `@discardableResult` to `PushLog.logged` — the wrap
      introduced 5 new "unused result" warnings on `Void`-returning methods; behavior-neutral fix.

## Verification
- [x] Full `PushTests` suite (clean `DerivedData-Tests`): 205 tests, 0 failures.
- [x] Generic Debug build (`scripts/test.sh build`): `BUILD SUCCEEDED`, 0 warnings.
- [x] Release build (`xcodebuild -configuration Release -destination 'generic/platform=iOS
      Simulator'`): `BUILD SUCCEEDED`. `strings` on the built binary confirms no `pucklab` /
      `onboardinglab` / `OnboardingLabViewModel` symbols reachable — Debug-only lab routes are
      genuinely compiled out of Release.
- [x] `--live` smoke launch (labeled worktree simulator, real device log stream filtered to
      `subsystem == "com.manav.Push"`): observed real log lines with zero PII —
      `[bootstrap] Supabase host: tzzvwjhvjduyqywlszqc.supabase.co`,
      `[bootstrap] Push 1.0 (1) launching, mode=live`, `[bootstrap] session restore: false`.
      App reached `AuthGateView` cleanly (screenshot confirmed), no crash.
- [ ] Not exercised: the `AppDataContainer.prepareLive` success (`"live data ready"`) / failure
      (`"live data preparation failed: ..."`) log lines require an authenticated session past the
      auth gate; no test credentials were available in this session to sign in and reach that
      code path. The code was verified by task review (Task 6) reading the implementation
      directly, but not observed live end-to-end. A future session with live credentials should
      complete this leg (sign in, then optionally toggle airplane mode mid-prepare to also see a
      `SupabaseLiveDataLoader` failure log line, e.g. `[network] loadProfiles failed: URLError`).

---

# Legal Destinations (Issue #36)

- [x] Define feature contract and replacement procedure.
- [x] Add centralized placeholder Terms and Privacy destinations.
- [x] Wire production onboarding, onboarding lab, and Profile.
- [x] Document App Store privacy disclosure inputs.
- [x] Add focused tests and verify build/test compilation.

## Verification
- [x] Both placeholder HTTPS destinations returned HTTP 200.
- [x] `scripts/test.sh build` succeeded.
- [x] Generic Release simulator build succeeded with store validation.
- [x] Generic `build-for-testing` succeeded, including `LegalDestinationsTests` compilation.
- [ ] Focused simulator execution: CoreSimulator XPC interrupted twice; the retry remained hung during simulator startup and was stopped after more than two minutes without test output.

---

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
