# Harden Release configuration and observability (Issue #37)

## Problem

The Release build has no crash reporting and no structured logging, so a
failure during live startup or a Supabase backend call is invisible outside
of on-device debugging. Separately, the issue asks to confirm that
test-only configuration (mock seeds, launch overrides, debug identities)
cannot activate in Release, and that the production Supabase configuration
is verified rather than assumed.

## Audit of current state

Most of the "prevent test-only config from leaking" scope is already
satisfied by existing code, confirmed by reading it:

- `AppEnvironment.resolve(isDebugBuild:arguments:)` (`Push/Data/Supabase/AppEnvironment.swift`)
  forces Release to `.live` unconditionally; only a Debug build honors the
  `--live` launch argument.
- `PushApp.swift`'s `--pucklab` / `--onboardinglab` / `--friends` routes, and
  `OnboardingLabViewModel`'s `--screen=` jump, are all inside `#if DEBUG` and
  compiled out of Release (`SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` is
  Debug-only in `project.pbxproj`).
- `AppDataContainer.shared` (`Push/Data/AppDataContainer.swift`) defaults to
  the mock seed, but `RootView.prepare(_:)` always installs a live container
  via `AppDataContainer.prepareLive` / `installPreparedLive` before
  `ContentView` renders whenever `mode == .live` — mock data never reaches
  the screen in a live session.
- No hardcoded test identities or debug auth bypasses exist in `AuthService`,
  `AuthViewModel`, or anywhere else in the auth path.

So this design adds only what's actually missing: a config guard, and a
diagnostics module for crash reporting + structured logging.

## Decisions

- **Crash reporting: Apple-native (MetricKit), not a third-party SDK.**
  There's no existing crash/analytics dependency, and a SaaS SDK
  (Crashlytics/Sentry) would require an account and secrets this session
  can't provision. MetricKit ships with iOS, needs no config, and surfaces
  crash/hang diagnostics in Xcode Organizer.
- **Supabase config "verification": a runtime guard on the single existing
  project, not a staging/prod split.** There is one Supabase project today
  and it already is production; introducing a second project and xcconfig
  is out of scope for this issue. "Verify" means: fail loudly at startup if
  the configured URL/key don't look like the intended production project,
  instead of silently shipping a broken or misdirected build.

## Design

### 1. `Push/Diagnostics/PushLog.swift`

A small enum wrapping `os.Logger` by category, plus a redaction policy:

```swift
enum PushLog {
    static let bootstrap = Logger(subsystem: subsystem, category: "bootstrap")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")

    static func safeDescription(for error: Error) -> String
    static func logStartupBanner(mode: AppMode)
}
```

- `subsystem` is the app bundle identifier.
- `safeDescription(for:)` is a **pure, unit-testable function**. Redaction
  rule: never log `.localizedDescription`, or a `PostgrestError`'s
  `.message` / `.detail` / `.hint` — PostgREST constraint-violation messages
  can embed the offending value (e.g. a duplicate handle). Only the error's
  Swift type name is logged, plus a `PostgrestError`'s `.code` (a stable
  Postgres error code like `23505`, never user data) when present.
- `logStartupBanner` logs one line at launch: app version (`CFBundleShortVersionString`),
  build number (`CFBundleVersion`), and the resolved `AppMode` — the
  "useful version and build information" the issue asks for.

### 2. `Push/Diagnostics/CrashReporter.swift`

A thin `MXMetricManagerSubscriber`:

```swift
final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()
    func start() { MXMetricManager.shared.add(self) }
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // log crashDiagnostics / hangDiagnostics counts + signal info via PushLog.bootstrap
    }
}
```

Registered once from `PushApp.init()`. No PII is available in or logged
from these payloads (MetricKit diagnostics are aggregate/system-level:
stack signatures, exception type, hang duration — not user data).

### 3. Config guard: `SupabaseConfig.swift`

Add a pure, testable validation function alongside the existing accessors:

```swift
static func isProductionHost(_ url: URL) -> Bool {
    url.host?.hasSuffix(".supabase.co") == true
}
```

`SupabaseConfig.url` calls this and `fatalError`s (matching the existing
style used for missing/invalid keys two lines above it) if the configured
host doesn't match — catching an empty, `localhost`, or otherwise
misconfigured `xcconfig` value before it ships silently. On success, logs
the resolved **host only** (never the anon key) via `PushLog.bootstrap`.
`SupabaseConfig.url` is a computed property with no memoization, but its
only caller is `SupabaseClientProvider.init`, which runs exactly once via
`static let shared` — so in practice this logs once per process lifetime
without needing `SupabaseConfig` itself to cache anything.

### 4. Startup instrumentation: `RootView.swift`

- On the bootstrap `.task`: log the startup banner (version/build/mode) via
  `PushLog.logStartupBanner`.
- `restoreSession()` outcome: log whether a session was restored or not
  (boolean only, no user identifier).
- `prepare(_:)`: log success (`"live data ready"`) or failure — on failure,
  log `PushLog.safeDescription(for: error)` via `PushLog.bootstrap` in
  addition to the existing `error.localizedDescription` stored in
  `BootstrapState.preparationFailed` for on-screen display (that string is
  shown only to the affected signed-in user, not logged — left unchanged).

### 5. Backend-failure instrumentation: `SupabaseLiveDataLoader.swift`

Every live PostgREST/RPC call already funnels through this one file (~20
methods, all calling `client.from(...)` / `client.rpc(...)`). Add one
private wrapper and route each method through it, rather than duplicating
try/catch 20 times:

```swift
private func run<T>(_ label: String, _ operation: () async throws -> T) async throws -> T {
    do { return try await operation() }
    catch {
        PushLog.network.error("\(label) failed: \(PushLog.safeDescription(for: error))")
        throw error
    }
}
```

Each method body becomes `try await run("loadProfiles") { try await client.from("profiles")... }`.
Behavior (return values, thrown errors) is unchanged — this only adds a
logging side effect on failure.

## Non-goals

- No staging/prod Supabase project split.
- No third-party crash/analytics SDK or new SPM dependency.
- No per-ViewModel or per-repository-protocol logging — `SupabaseLiveDataLoader`
  is the single real network boundary, so that's where backend-failure
  logging lives.
- No change to user-facing failure copy in `LivePreparationFailureView`.
- No logging in mock mode beyond what already exists (mock has no backend
  to fail against).

## Testing plan

- `PushLog.safeDescription(for:)`: unit tests for a `PostgrestError` (asserts
  `.message`/`.detail`/`.hint` never appear in the output, `.code` does when
  present) and a generic `Error` (asserts only the type name appears).
- `SupabaseConfig.isProductionHost(_:)`: unit tests for a valid
  `*.supabase.co` URL, `localhost`, and an empty-host URL.
- `CrashReporter` and the `PushLog.logStartupBanner` line are not
  meaningfully unit-testable (system-delivered payloads / `Bundle.main`
  side effects); covered by a generic Release build + manual `--live`
  smoke launch instead.
- Existing `PushTests` suite must stay green; `SupabaseLiveDataLoader`'s
  `run` wrapper changes control flow, not return/throw semantics, so no
  existing repository test behavior should change.

## Acceptance criteria (from the issue)

1. An archived Release build launches into the real production flow —
   already true (`AppEnvironment.resolve`), reconfirmed by a Release archive
   smoke check.
2. Test-only configuration cannot be activated accidentally — already true
   (`#if DEBUG` gating), reconfirmed by inspecting the Release binary has no
   lab routes reachable.
3. Startup and backend failures provide enough information to investigate —
   satisfied by the `PushLog` startup banner, `RootView` bootstrap logging,
   and `SupabaseLiveDataLoader` failure logging, all visible in Console.app
   / Xcode Organizer without any new backend or account.
