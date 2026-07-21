# Harden Release Configuration and Observability (Issue #37) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add crash reporting and structured, PII-free logging around live startup and Supabase backend failures, plus a runtime guard confirming the configured Supabase project is production — closing the observability gap identified in Issue #37. (Release/mock isolation was audited and found already correct; no changes needed there.)

**Architecture:** A new `Push/Diagnostics/` module (`PushLog` for `os.Logger`-based structured logging + redaction, `CrashReporter` for MetricKit crash/hang diagnostics) is consumed from three existing call sites: `SupabaseConfig` (host guard), `SupabaseLiveDataLoader` (the single network boundary all live PostgREST/RPC calls already funnel through), and `RootView` (live bootstrap). No third-party dependency, no new backend, no new Supabase project.

**Tech Stack:** Swift 6 / SwiftUI, `os.Logger` (unified logging, Apple-native), `MetricKit` (Apple-native crash/hang diagnostics), XCTest.

## Global Constraints

- Files ≤ 400 lines; functions ≤ 40 lines, single responsibility (`CLAUDE.md`).
- No magic numbers; comments explain WHY, not WHAT (`CLAUDE.md`).
- **Redaction rule (spec):** never log an error's `.localizedDescription`, or a `PostgrestError`'s `.message` / `.detail` / `.hint` — only the error's Swift type name and, for `PostgrestError`, its stable `.code`.
- **`os.Logger` privacy gotcha:** string-interpolated values default to `.private` (shown as `<private>` in Console) unless explicitly marked `privacy: .public`. Every interpolation in this plan is already-redacted, safe-to-reveal data, so every one is marked `privacy: .public` explicitly — don't drop this or the logs become useless.
- Deployment target is iOS 16.4 (confirmed via `IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj`, not the stale "iOS 17+" in `CLAUDE.md`). MetricKit's `MXMetricManagerSubscriber`/`MXCrashDiagnostic`/`MXHangDiagnostic` are available since iOS 13/14, so no availability guards are needed.
- New Swift files must be registered in `Push.xcodeproj/project.pbxproj` via `python3 scripts/pbxproj_add.py <path relative to Push/>` (app target) or `python3 scripts/pbxproj_add.py --target tests <path relative to PushTests/>` (test target) — the project does not auto-discover files.
- Run tests via `scripts/test.sh suite <ClassName>` / `scripts/test.sh full` / `scripts/test.sh build`, never raw `xcodebuild test` with an unlabeled simulator (see `tasks/lessons.md`).

---

### Task 1: Link the Supabase SPM product to the `PushTests` target

Today only the `Push` app target links the `Supabase` Swift package product; `PushTests` does not, so no test file can `import Supabase`. Task 2 needs to construct a real `PostgrestError` in a test, so this must land first.

**Files:**
- Modify: `Push.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `import Supabase` becomes usable from any file under `PushTests/`.

- [ ] **Step 1: Add a new `PBXBuildFile` entry for the `PushTests` target's copy of the Supabase product reference**

Read `Push.xcodeproj/project.pbxproj` and find this exact line (it's the app target's existing Frameworks entry for Supabase):

```
		AA00000000000000000000B3 /* Supabase in Frameworks */ = {isa = PBXBuildFile; productRef = AA00000000000000000000B2 /* Supabase */; };
```

Using the Edit tool, insert a new line directly after it (same file, same section — `PBXBuildFile`), reusing the same product reference (`AA00000000000000000000B2`) with a new unique build-file ID:

```
		AA00000000000000000000B4 /* Supabase in Frameworks */ = {isa = PBXBuildFile; productRef = AA00000000000000000000B2 /* Supabase */; };
```

- [ ] **Step 2: Add that build file to the `PushTests` target's Frameworks build phase**

Find the `PushTests` target's (empty) `PBXFrameworksBuildPhase` block — it's the one with ID `5217A2732FF1B6DA0011F860` and an empty `files = ( );`:

```
		5217A2732FF1B6DA0011F860 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

Replace the empty `files = ( );` so it contains the new build file:

```
		5217A2732FF1B6DA0011F860 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA00000000000000000000B4 /* Supabase in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

(Do not touch the app target's Frameworks phase at ID `5217A2632FF1B6D90011F860` — leave its existing `AA00000000000000000000B3` entry as-is.)

- [ ] **Step 3: Declare the package product dependency on the `PushTests` native target**

Find the `PushTests` `PBXNativeTarget` block (ID `5217A2752FF1B6DA0011F860`):

```
			name = PushTests;
			productName = PushTests;
```

Insert a `packageProductDependencies` entry between them, mirroring how the app target (`5217A2652FF1B6D90011F860`) already declares it:

```
			name = PushTests;
			packageProductDependencies = (
				AA00000000000000000000B2 /* Supabase */,
			);
			productName = PushTests;
```

- [ ] **Step 4: Verify the package graph still resolves and nothing else broke**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -resolvePackageDependencies -project Push.xcodeproj -scheme Push
```
Expected: resolves without error (no new packages — this only changes which targets link the existing `Supabase` product).

Then:
```bash
scripts/test.sh full
```
Expected: same pass count as before this change (no test file uses `import Supabase` yet, so behavior is unaffected — this just confirms the pbxproj edit didn't break the build or test target linkage).

- [ ] **Step 5: Commit**

```bash
git add Push.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
build: link Supabase package product to the PushTests target

Needed so test files can construct a real PostgrestError to verify the
upcoming log-redaction rule, instead of only exercising it indirectly.
EOF
)"
```

---

### Task 2: `PushLog` — structured logging + redaction (TDD)

**Files:**
- Create: `Push/Diagnostics/PushLog.swift`
- Test: `PushTests/PushLogTests.swift`
- Modify: `Push.xcodeproj/project.pbxproj` (registration)

**Interfaces:**
- Produces:
  - `PushLog.bootstrap: Logger`, `PushLog.network: Logger`, `PushLog.auth: Logger` — categorized loggers later tasks use.
  - `PushLog.safeDescription(for error: Error) -> String` — pure redaction helper.
  - `PushLog.logged<T>(_ label: String, category: Logger = PushLog.network, operation: () async throws -> T) async rethrows -> T` — generic "run, log-and-rethrow on failure" wrapper `SupabaseLiveDataLoader` (Task 5) will call at every network call site.
  - `PushLog.logStartupBanner(mode: AppMode)` — one-line version/build/mode log, called from `RootView` (Task 6).

- [ ] **Step 1: Write the failing tests**

Create `PushTests/PushLogTests.swift`:

```swift
import XCTest
import Supabase
@testable import Push

private struct SampleNetworkFailure: Error {}

final class PushLogTests: XCTestCase {
    func testSafeDescriptionForPostgrestErrorIncludesOnlyTypeAndCode() {
        let error = PostgrestError(
            detail: "Key (handle)=(alice123) already exists.",
            hint: "hint text mentioning alice123",
            code: "23505",
            message: "duplicate key value violates unique constraint mentioning alice123"
        )

        let description = PushLog.safeDescription(for: error)

        XCTAssertTrue(description.contains("PostgrestError"))
        XCTAssertTrue(description.contains("23505"))
        XCTAssertFalse(description.contains("alice123"))
    }

    func testSafeDescriptionForGenericErrorIsTypeNameOnly() {
        let description = PushLog.safeDescription(for: SampleNetworkFailure())

        XCTAssertTrue(description.contains("SampleNetworkFailure"))
    }

    func testLoggedPassesThroughSuccessValue() async throws {
        let value = try await PushLog.logged("op") { 42 }

        XCTAssertEqual(value, 42)
    }

    func testLoggedRethrowsFailure() async {
        do {
            let _: Int = try await PushLog.logged("op") {
                throw SampleNetworkFailure()
            }
            XCTFail("expected logged(_:) to rethrow")
        } catch is SampleNetworkFailure {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
scripts/test.sh build
```
Expected: FAIL to compile — `PushLog` does not exist yet. (The test file must be registered first — see next step — or `build` won't even see it; registering now is fine since the file will fail to compile either way until `PushLog.swift` exists.)

Register the test file:
```bash
python3 scripts/pbxproj_add.py --target tests PushLogTests.swift
```

- [ ] **Step 3: Write `Push/Diagnostics/PushLog.swift`**

```swift
//
//  PushLog.swift
//  Push
//
//  Structured logging for live startup and Supabase backend failures.
//
//  Redaction rule: never log an error's `.localizedDescription`, or a
//  `PostgrestError`'s `.message` / `.detail` / `.hint` — PostgREST
//  constraint-violation messages can embed user input (e.g. a duplicate
//  handle in a unique-violation message). Only the error's Swift type name,
//  and for `PostgrestError` its stable `.code` (a Postgres error code like
//  "23505", never user data), are safe to log.
//
//  `os.Logger` treats interpolated values as `.private` (shown as
//  `<private>` in Console) unless marked `privacy: .public`. Everything
//  interpolated below has already been redacted by this file, so every
//  interpolation is explicitly `.public`.
//

import Foundation
import Supabase
import os

enum PushLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.manav.Push"

    static let bootstrap = Logger(subsystem: subsystem, category: "bootstrap")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")

    static func safeDescription(for error: Error) -> String {
        let typeName = String(describing: type(of: error))
        if let postgrestError = error as? PostgrestError, let code = postgrestError.code {
            return "\(typeName)(code: \(code))"
        }
        return typeName
    }

    /// Runs `operation`, logging a one-line failure (label + safe error
    /// description) to `category` before rethrowing. Success is a silent
    /// passthrough — this only adds a logging side effect on failure.
    static func logged<T>(
        _ label: String,
        category: Logger = network,
        operation: () async throws -> T
    ) async rethrows -> T {
        do {
            return try await operation()
        } catch {
            category.error("\(label, privacy: .public) failed: \(safeDescription(for: error), privacy: .public)")
            throw error
        }
    }

    static func logStartupBanner(mode: AppMode) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        bootstrap.log("Push \(version, privacy: .public) (\(build, privacy: .public)) launching, mode=\(String(describing: mode), privacy: .public)")
    }
}
```

Register it:
```bash
python3 scripts/pbxproj_add.py Diagnostics/PushLog.swift
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
scripts/test.sh suite PushLogTests
```
Expected: PASS, 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Push/Diagnostics/PushLog.swift PushTests/PushLogTests.swift Push.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: add PushLog structured logging with PII-redaction policy

Adds os.Logger-based categories, a generic logged(_:) run-and-log-on-
failure wrapper backend call sites will use, and a redaction rule that
only ever logs an error's type and (for PostgrestError) its stable
Postgres error code — never localizedDescription/message/detail/hint,
which can embed user input.
EOF
)"
```

---

### Task 3: `CrashReporter` — MetricKit crash/hang diagnostics

**Files:**
- Create: `Push/Diagnostics/CrashReporter.swift`
- Modify: `Push/PushApp.swift`
- Modify: `Push.xcodeproj/project.pbxproj` (registration)

**Interfaces:**
- Consumes: `PushLog.bootstrap` (Task 2).
- Produces: `CrashReporter.shared.start()`, called once from `PushApp.init()`.

Not unit-testable: `MXDiagnosticPayload` and its nested diagnostic types have no public initializers, so a test can't construct one. Verified instead by a generic build (Step 3) and covered by the manual `--live` smoke check in Task 7.

- [ ] **Step 1: Write `Push/Diagnostics/CrashReporter.swift`**

```swift
//
//  CrashReporter.swift
//  Push
//
//  Subscribes to MetricKit diagnostic payloads (crash/hang reports) and logs
//  their presence via PushLog. Apple delivers these on next launch after a
//  crash or hang on a real device — at least once per day when conditions
//  permit, never guaranteed. No third-party dependency, no account, no PII:
//  MetricKit diagnostics are aggregate stack signatures and durations, not
//  user data.
//

import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()

    private override init() {}

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            let hangCount = payload.hangDiagnostics?.count ?? 0
            guard crashCount > 0 || hangCount > 0 else { continue }
            PushLog.bootstrap.error(
                "MetricKit payload: \(crashCount, privacy: .public) crash diagnostic(s), \(hangCount, privacy: .public) hang diagnostic(s)"
            )
        }
    }
}
```

Register it:
```bash
python3 scripts/pbxproj_add.py Diagnostics/CrashReporter.swift
```

- [ ] **Step 2: Wire it up at launch in `Push/PushApp.swift`**

Current file:
```swift
@main
struct PushApp: App {
    var body: some Scene {
        WindowGroup {
```

Add an `init()` before `var body`:
```swift
@main
struct PushApp: App {
    init() {
        CrashReporter.shared.start()
    }

    var body: some Scene {
        WindowGroup {
```

- [ ] **Step 3: Verify it builds**

Run:
```bash
scripts/test.sh build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Push/Diagnostics/CrashReporter.swift Push/PushApp.swift Push.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: add MetricKit-based crash/hang diagnostic logging

Registers a CrashReporter MXMetricManagerSubscriber at launch. Apple-
native, no new dependency or account — crash/hang counts are logged via
PushLog on next launch after an incident.
EOF
)"
```

---

### Task 4: `SupabaseConfig` production-host guard (TDD)

**Files:**
- Modify: `Push/Data/Supabase/SupabaseConfig.swift`
- Test: `PushTests/SupabaseConfigTests.swift`
- Modify: `Push.xcodeproj/project.pbxproj` (test file registration)

**Interfaces:**
- Consumes: `PushLog.bootstrap` (Task 2).
- Produces: `SupabaseConfig.isProductionHost(_ url: URL) -> Bool` — pure, testable.

- [ ] **Step 1: Write the failing tests**

Create `PushTests/SupabaseConfigTests.swift`:

```swift
import XCTest
@testable import Push

final class SupabaseConfigTests: XCTestCase {
    func testValidProductionHostPasses() {
        let url = URL(string: "https://tzzvwjhvjduyqywlszqc.supabase.co")!

        XCTAssertTrue(SupabaseConfig.isProductionHost(url))
    }

    func testLocalhostFailsProductionCheck() {
        let url = URL(string: "http://localhost:54321")!

        XCTAssertFalse(SupabaseConfig.isProductionHost(url))
    }

    func testEmptyHostFailsProductionCheck() {
        let url = URL(string: "file:///dev/null")!

        XCTAssertFalse(SupabaseConfig.isProductionHost(url))
    }
}
```

Register it:
```bash
python3 scripts/pbxproj_add.py --target tests SupabaseConfigTests.swift
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
scripts/test.sh build
```
Expected: FAIL to compile — `SupabaseConfig.isProductionHost` does not exist yet.

- [ ] **Step 3: Update `Push/Data/Supabase/SupabaseConfig.swift`**

Current file:
```swift
import Foundation

/// Reads the committed project URL + anon key from the generated Info.plist
/// (fed by Push/Config/Supabase.xcconfig). No secrets: anon key only.
enum SupabaseConfig {
    static var url: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL missing/invalid in Info.plist")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty else {
            fatalError("SupabaseAnonKey missing in Info.plist")
        }
        return key
    }
}
```

Replace it with:
```swift
import Foundation

/// Reads the committed project URL + anon key from the generated Info.plist
/// (fed by Push/Config/Supabase.xcconfig). No secrets: anon key only.
enum SupabaseConfig {
    /// Every Supabase project URL resolves under this host suffix. Guards
    /// against an empty, localhost, or otherwise misconfigured
    /// `Supabase.xcconfig` value shipping silently in a Release build.
    private static let productionHostSuffix = ".supabase.co"

    static func isProductionHost(_ url: URL) -> Bool {
        url.host?.hasSuffix(productionHostSuffix) == true
    }

    static var url: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL missing/invalid in Info.plist")
        }
        guard isProductionHost(url) else {
            fatalError("SupabaseURL is not a production Supabase host: \(url.host ?? "nil")")
        }
        PushLog.bootstrap.log("Supabase host: \(url.host ?? "unknown", privacy: .public)")
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty else {
            fatalError("SupabaseAnonKey missing in Info.plist")
        }
        return key
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
scripts/test.sh suite SupabaseConfigTests
```
Expected: PASS, 3 tests, 0 failures.

- [ ] **Step 5: Run the full suite to confirm no regression**

Run:
```bash
scripts/test.sh full
```
Expected: same pass count as Task 1's baseline, plus the new `PushLogTests` (4) and `SupabaseConfigTests` (3). `SupabaseConfig.url`/`.anonKey` are not called by any existing test (they'd `fatalError` against the test bundle's `Info.plist`, which has no `SupabaseURL`/`SupabaseAnonKey` keys) — same as before this change, so nothing new exercises the `fatalError` paths.

- [ ] **Step 6: Commit**

```bash
git add Push/Data/Supabase/SupabaseConfig.swift PushTests/SupabaseConfigTests.swift Push.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: guard SupabaseConfig.url against a non-production host

Fails loudly (matching the file's existing fatalError style for missing
keys) instead of silently shipping a misconfigured xcconfig value. Logs
the resolved host (never the anon key) on success.
EOF
)"
```

---

### Task 5: Route `SupabaseLiveDataLoader` backend calls through `PushLog.logged`

Every live PostgREST/RPC call already funnels through this one file (~20 methods). This task only adds a logging side effect on the failure path — return values and thrown errors are unchanged, so there's no new test; verified by the existing suite staying green plus the `logged<T>` unit tests already written in Task 2.

**Files:**
- Modify: `Push/Data/Supabase/SupabaseLiveDataLoader.swift`

**Interfaces:**
- Consumes: `PushLog.logged<T>(_:category:operation:)` (Task 2).

- [ ] **Step 1: Replace the file**

Read `Push/Data/Supabase/SupabaseLiveDataLoader.swift` first (needed before editing per tool rules), then replace its full contents with:

```swift
//
//  SupabaseLiveDataLoader.swift
//  Push
//
//  PostgREST I/O behind `LiveDataStore`. Views and ViewModels never import this.
//
//  Every method routes through `PushLog.logged` so a backend failure gets
//  one consistent, PII-free log line (see PushLog for the redaction rule)
//  before the original error propagates unchanged.
//

import Foundation
import Supabase

@MainActor
final class SupabaseLiveDataLoader: LiveDataLoading {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func loadProfiles() async throws -> [ProfileRow] {
        try await PushLog.logged("loadProfiles") {
            try await client.from("profiles").select().execute().value
        }
    }

    func loadGroups() async throws -> [GroupRow] {
        try await PushLog.logged("loadGroups") {
            try await client.from("groups").select().execute().value
        }
    }

    func loadMemberships() async throws -> [GroupMembershipRow] {
        try await PushLog.logged("loadMemberships") {
            try await client.from("group_memberships").select().execute().value
        }
    }

    func loadPolicies() async throws -> [SharingPolicyRow] {
        try await PushLog.logged("loadPolicies") {
            try await client.from("sharing_policies").select().execute().value
        }
    }

    func updateBasics(userID: String, displayName: String, handle: String) async throws -> ProfileRow {
        try await PushLog.logged("updateBasics") {
            try await client.from("profiles")
                .update(ProfileBasicsPayload(first_name: displayName, handle: handle))
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func updatePrivacy(userID: String, payload: ProfileSettingsPayload) async throws -> ProfileRow {
        try await PushLog.logged("updatePrivacy") {
            try await client.from("profiles").update(payload)
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func updateAvailability(userID: String, rawValue: String) async throws -> ProfileRow {
        try await PushLog.logged("updateAvailability") {
            try await client.from("profiles").update(AvailabilityPayload(availability_choice: rawValue))
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func loadPushes() async throws -> [PushRow] {
        try await PushLog.logged("loadPushes") {
            try await client.from("pushes").select().execute().value
        }
    }

    func loadResponses() async throws -> [PushResponseRow] {
        try await PushLog.logged("loadResponses") {
            try await client.from("push_responses").select().execute().value
        }
    }

    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow {
        try await PushLog.logged("insertPush") {
            try await client.from("pushes").insert(payload).select().single().execute().value
        }
    }

    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow {
        try await PushLog.logged("updatePush") {
            try await client.from("pushes").update(payload)
                .eq("id", value: id).select().single().execute().value
        }
    }

    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow {
        try await PushLog.logged("cancelPush") {
            try await client.from("pushes").update(payload)
                .eq("id", value: id).select().single().execute().value
        }
    }

    func deletePush(id: String) async throws {
        try await PushLog.logged("deletePush") {
            try await client.from("pushes").delete().eq("id", value: id).execute()
        }
    }

    func insertResponses(_ payloads: [PushResponsePayload]) async throws {
        try await PushLog.logged("insertResponses") {
            try await client.from("push_responses").insert(payloads).execute()
        }
    }

    func upsertResponse(_ payload: PushResponsePayload) async throws {
        try await PushLog.logged("upsertResponse") {
            try await client.from("push_responses")
                .upsert(payload, onConflict: "push_id,person_id")
                .execute()
        }
    }

    func deleteResponses(pushID: String, personIDs: [String]) async throws {
        try await PushLog.logged("deleteResponses") {
            try await client.from("push_responses").delete()
                .eq("push_id", value: pushID)
                .in("person_id", values: personIDs)
                .execute()
        }
    }

    func loadFriendships() async throws -> [FriendshipRow] {
        try await PushLog.logged("loadFriendships") {
            try await client.from("friendships").select().execute().value
        }
    }

    func searchProfiles(query: String, limit: Int) async throws -> [SearchProfileRow] {
        try await PushLog.logged("searchProfiles") {
            try await client
                .rpc(
                    "search_profiles",
                    params: SearchProfilesParams(search_query: query, result_limit: limit)
                )
                .execute()
                .value
        }
    }

    func sendFriendRequest(targetUserID: String) async throws -> FriendshipRow {
        try await PushLog.logged("sendFriendRequest") {
            try await client
                .rpc("send_friend_request", params: SendFriendRequestParams(target_user_id: targetUserID))
                .execute()
                .value
        }
    }

    func resolveFriendRequest(id: String, accept: Bool) async throws -> FriendshipRow {
        try await PushLog.logged("resolveFriendRequest") {
            try await client
                .rpc(
                    "resolve_friend_request",
                    params: ResolveFriendRequestParams(request_id: id, accept: accept)
                )
                .execute()
                .value
        }
    }

    func removeFriend(targetUserID: String) async throws {
        try await PushLog.logged("removeFriend") {
            try await client
                .rpc("remove_friend", params: RemoveFriendParams(other_user_id: targetUserID))
                .execute()
        }
    }

    func loadProfile(id: String) async throws -> ProfileRow {
        try await PushLog.logged("loadProfile") {
            try await client.from("profiles")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
        }
    }
}

private struct SearchProfilesParams: Encodable {
    let search_query: String
    let result_limit: Int
}

private struct SendFriendRequestParams: Encodable {
    let target_user_id: String
}

private struct ResolveFriendRequestParams: Encodable {
    let request_id: String
    let accept: Bool
}

private struct RemoveFriendParams: Encodable {
    let other_user_id: String
}

private struct ProfileBasicsPayload: Encodable {
    let first_name: String
    let handle: String
}

private struct AvailabilityPayload: Encodable {
    let availability_choice: String
}
```

- [ ] **Step 2: Run the full suite to confirm no regression**

Run:
```bash
scripts/test.sh full
```
Expected: same pass count as after Task 4 — no existing test constructs a `SupabaseLiveDataLoader` directly (confirmed: `grep -rln "SupabaseLiveDataLoader" PushTests/` returns nothing), so this is a pure regression check that the file still compiles and nothing downstream broke.

- [ ] **Step 3: Commit**

```bash
git add Push/Data/Supabase/SupabaseLiveDataLoader.swift
git commit -m "$(cat <<'EOF'
feat: log Supabase backend failures at the network boundary

Routes every SupabaseLiveDataLoader method through PushLog.logged so a
PostgREST/RPC failure gets one PII-free log line before the original
error propagates unchanged. Behavior (return values, thrown errors) is
unchanged.
EOF
)"
```

---

### Task 6: Startup logging in `RootView`

Like Task 5, this only adds logging side effects — `BootstrapState` transitions are unchanged, so `AuthBootstrapTests` (which test `BootstrapState` directly, not `RootView`'s task body) need no changes. Verified by the existing suite staying green plus the manual `--live` smoke check in Task 7.

**Files:**
- Modify: `Push/RootView.swift`

**Interfaces:**
- Consumes: `PushLog.bootstrap` and `PushLog.logStartupBanner(mode:)` (Task 2).

- [ ] **Step 1: Log the startup banner and session-restore outcome**

In `Push/RootView.swift`, find:
```swift
    var body: some View {
        content
            .task {
                guard case .loading = state else { return }
                let restored = mode == .live ? await auth.restoreSession() : nil
                let initial = BootstrapState.initial(mode: mode, restored: restored)
                enter(initial)
                if case .preparing(let user) = initial { await prepare(user) }
            }
    }
```

Replace with:
```swift
    var body: some View {
        content
            .task {
                guard case .loading = state else { return }
                PushLog.logStartupBanner(mode: mode)
                let restored = mode == .live ? await auth.restoreSession() : nil
                if mode == .live {
                    PushLog.bootstrap.log("session restore: \(restored != nil, privacy: .public)")
                }
                let initial = BootstrapState.initial(mode: mode, restored: restored)
                enter(initial)
                if case .preparing(let user) = initial { await prepare(user) }
            }
    }
```

- [ ] **Step 2: Log live-data preparation outcome**

Find:
```swift
    @MainActor
    private func prepare(_ user: AuthedUser) async {
        do {
            let container = try await AppDataContainer.prepareLive(
                client: SupabaseClientProvider.shared.client, currentUserID: user.id
            )
            AppDataContainer.installPreparedLive(container)
            enter(.app(user))
        } catch {
            enter(.preparationFailed(user, error.localizedDescription))
        }
    }
```

Replace with:
```swift
    @MainActor
    private func prepare(_ user: AuthedUser) async {
        do {
            let container = try await AppDataContainer.prepareLive(
                client: SupabaseClientProvider.shared.client, currentUserID: user.id
            )
            AppDataContainer.installPreparedLive(container)
            PushLog.bootstrap.log("live data ready")
            enter(.app(user))
        } catch {
            PushLog.bootstrap.error("live data preparation failed: \(PushLog.safeDescription(for: error), privacy: .public)")
            enter(.preparationFailed(user, error.localizedDescription))
        }
    }
```

Note: `error.localizedDescription` stored in `BootstrapState.preparationFailed` is unchanged — it's shown only to the affected signed-in user on the `LivePreparationFailureView` screen, not logged. The new `PushLog.bootstrap.error` line above logs the safe, redacted description separately.

- [ ] **Step 3: Verify it builds and the existing bootstrap tests still pass**

Run:
```bash
scripts/test.sh suite AuthBootstrapTests
```
Expected: PASS, 4 tests, 0 failures (unchanged from before — these test `BootstrapState` directly, which this task didn't touch).

Run:
```bash
scripts/test.sh full
```
Expected: same pass count as after Task 5.

- [ ] **Step 4: Commit**

```bash
git add Push/RootView.swift
git commit -m "$(cat <<'EOF'
feat: log live startup banner, session restore, and prepare outcome

Adds a version/build/mode banner and PII-free success/failure logging
around RootView's live bootstrap (session restore + AppDataContainer
preparation), so a broken live launch is diagnosable from device logs.
EOF
)"
```

---

### Task 7: Final verification

Confirms all three of the issue's "Done when" acceptance criteria end-to-end, beyond the per-task unit tests already run.

**Files:** none (verification only).

- [ ] **Step 1: Full test suite**

```bash
scripts/test.sh full
```
Expected: all tests pass (baseline count + `PushLogTests` (4) + `SupabaseConfigTests` (3), 0 failures).

- [ ] **Step 2: Generic Debug build**

```bash
scripts/test.sh build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Release build (acceptance criterion 1 & 2 — Release launches live, no test-only config reachable)**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Push.xcodeproj -scheme Push -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData-ReleaseCheck \
  build
```
Expected: `BUILD SUCCEEDED`.

Then confirm the Debug-only lab routes and their strings are absent from the Release binary (they're inside `#if DEBUG`, so this should find nothing):
```bash
APP_BINARY=$(find DerivedData-ReleaseCheck -name "Push.app" -path "*Release*" | head -1)/Push
strings "$APP_BINARY" | grep -iE "pucklab|onboardinglab|OnboardingLabViewModel" || echo "confirmed: no lab routes in Release binary"
```
Expected: `confirmed: no lab routes in Release binary`.

- [ ] **Step 4: Manual `--live` smoke check (acceptance criterion 3 — startup/backend failures are diagnosable)**

First boot the labeled worktree simulator (do not use a stock unlabeled simulator, see `tasks/lessons.md`):
```bash
scripts/run-ios-sim.sh ensure-booted-udid --iphone-17
```
In one terminal, start streaming logs from that now-booted simulator:
```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.manav.Push"' --level debug
```
In another terminal, build/install/launch the app with the `--live` argument on the same simulator:
```bash
./scripts/run-ios-sim.sh run --iphone-17 -- --live
```
Confirm in the streamed output:
- A `bootstrap` line with the app version, build number, and `mode=live`.
- A `bootstrap` line logging the Supabase host (a `*.supabase.co` value, never the anon key).
- A `bootstrap` line for session restore (`session restore: true` or `false`) and either `live data ready` or a `live data preparation failed: ...` line naming only an error type/code — never an email, name, or handle.
- If reachable, trigger a backend failure (e.g. airplane mode mid-load) and confirm a `network` line like `loadProfiles failed: URLError` (or similar) appears — never a raw PostgREST message.

- [ ] **Step 5: Record verification results**

Append a `## Verification` section to `tasks/todo.md` under a new `# Harden Release Configuration and Observability (Issue #37)` heading, following the existing convention in that file (see the most recent entries), listing the results of Steps 1–4.

- [ ] **Step 6: Commit**

```bash
git add tasks/todo.md
git commit -m "$(cat <<'EOF'
docs: record Issue #37 verification results

Full suite, Release build (no lab routes reachable), and a --live smoke
check confirming startup/backend failures now log diagnosable, PII-free
information.
EOF
)"
```
