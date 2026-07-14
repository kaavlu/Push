# Project lessons & gotchas

Durable, non-obvious learnings. Keep entries short; link code/docs rather than restating them.

## Supabase migration (Issue #27)

### Toolchain / simulator
- Xcode 26.x ships **without an iOS simulator runtime**. If every simulator shows
  "runtime profile not found", install one: `xcodebuild -downloadPlatform iOS`.
  It must run **unsandboxed** (writes to `/Library/Developer/CoreSimulator`); a
  sandboxed run fails silently with zero output.
- Test/build destination is `platform=iOS Simulator,name=iPhone 17` (the plan's
  older `iPhone 14` does not exist on Xcode 26).
- SourceKit's live index frequently shows false "No such module 'Supabase'" /
  "cannot find type X" across files after edits. `xcodebuild` is the source of
  truth — trust a green build/test over live diagnostics.

### SwiftPM in a hand-managed `project.pbxproj` (objectVersion 56)
- No Xcode GUI here, so an SPM package is added by editing `project.pbxproj`
  directly: add `XCRemoteSwiftPackageReference` + `XCSwiftPackageProductDependency`
  sections, a `PBXBuildFile` for the product, and reference them from the target's
  `packageProductDependencies` + Frameworks phase and the project's
  `packageReferences`. Then `xcodebuild -resolvePackageDependencies` (no runtime
  needed) validates it. supabase-swift pinned upToNextMajor from 2.0.0 → resolved 2.51.0.
- supabase-swift's auth user type is `User` (not `Auth.User`) under `import Supabase`.

### Custom Info.plist keys with `GENERATE_INFOPLIST_FILE = YES`
- Xcode only injects its **own known** `INFOPLIST_KEY_*` names into the generated
  Info.plist — arbitrary custom keys (e.g. `INFOPLIST_KEY_SupabaseURL`) are
  silently dropped. To surface custom keys, add a **partial** `Push/Info.plist`
  holding just those keys with `$(VAR)` substitution and set `INFOPLIST_FILE` to
  it while keeping `GENERATE_INFOPLIST_FILE = YES`; Xcode merges the generated keys
  on top and expands the vars. Config vars live in `Push/Config/Supabase.xcconfig`
  (URL + anon key only — never the service-role key). The xcconfig fileRef must be
  `SOURCE_ROOT`-relative (`Push/Config/Supabase.xcconfig`), not group-relative.

### PostgREST DTO decoding
- PostgREST timestamps are ISO-8601 with fractional seconds/offset. A bare
  `JSONDecoder()` (used in mapping tests) fails on them, and the SDK's decoder
  strategy is easy to get wrong. Decode timestamp columns as **`String`** in the
  DTO and convert in the mapping func with a tolerant `ISO8601DateFormatter` chain
  (`.withFractionalSeconds` then plain; epoch fallback for non-optional, `nil` for
  optional). Decoder-agnostic → works for both tests and production.
- Enum raw values that are camelCase in Swift but snake_case in the DB
  (`FriendAvailabilityState.freeNow` vs `free_now`; `SharingPolicy.AudienceType.globalDefault`
  vs `global_default`) need an **explicit `switch`** map, not `EnumType(rawValue:)`.
- A cached multi-profile response has no guaranteed row order. Never use `.first` for the
  authenticated person/profile; select by the lowercased auth ID. Returning the first visible
  friend as self duplicates that person in `(friends + [user])` and traps ID-keyed dictionaries.

### Shared-container refactor (`AppDataContainer`)
- `DataLayerTests` accesses `container.database` and existing tests must stay
  unchanged, so `database` is an **internal implicitly-unwrapped optional**
  (`InMemoryDatabase!`), not `private ... ?` — `@testable import` doesn't expose
  `private`. (Trade-off: live-mode `container.database.x` would trap at runtime.)
- Making `.shared` a `static private(set) var` (needed for `installLive`) breaks
  ViewModels that used `container: AppDataContainer = .shared` as a **default
  parameter** (Swift evaluates default args in a nonisolated context; a mutable
  `@MainActor` static can't be referenced there). Fix: `container: AppDataContainer? = nil`
  + `?? .shared` in the init body — which also preserves the "capture live `.shared`
  after `installLive`" bootstrap timing `RootView` relies on.

### SwiftUI / deployment target
- Deployment target is iOS 16.4: use the **single-parameter** `.onChange(of:) { new in }`.
  The two-closure `.onChange(of:_:)` is iOS 17+ and won't compile.

### Authenticated RLS verification recipe (proves Auth→JWT→RLS→PostgREST)
- Sign in via GoTrue password grant to get a real access token, then read through
  PostgREST with `apikey: <anon>` + `Authorization: Bearer <jwt>`:
  `POST /auth/v1/token?grant_type=password` → `GET /rest/v1/<table>?select=...`.
  Verify an in-graph user sees the expected rows and an unrelated user is denied.
- After DDL, run `get_advisors(security)`; treat only high-severity findings from
  the new schema/RLS/`SECURITY DEFINER` objects as blocking. (The
  `auth_leaked_password_protection` WARN is an unrelated dashboard toggle.)
