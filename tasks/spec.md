# Complete Group Lifecycle (Issue #43)

## Goal
Finish live group lifecycle after create + invite accept/deny (`0011`): owners/members
manage groups from Group Detail; photos persist via Storage; backend-enforced permissions.

## Contract (summary)
- Design: `docs/superpowers/specs/2026-07-20-complete-group-lifecycle-design.md`
- Plan: `docs/superpowers/plans/2026-07-20-complete-group-lifecycle.md`
- Migration `0013_group_lifecycle`: `SECURITY DEFINER` RPCs (rename/photo/invite/cancel/
  remove/leave/transfer/delete) + public `group-photos` bucket; no broad client writes
  on `groups` / `group_memberships`.
- Client: `GroupRepository` lifecycle methods; mock mirrors `0013` rules; live via
  `SupabaseGroupRepository` → `LiveDataStore` → RPCs + `GroupPhotoStoring` (orphan rollback).
- UI: Group Detail management hub; `GroupsViewModel` mutations + `ActionErrorBanner`.
- Hard delete groups; `pushes.group_id` SET NULL; owner leave requires transfer if others remain.

## Acceptance
See design doc acceptance 1–16; unit coverage in `GroupLifecycleTests` / related suites.

---

# Foreground Refresh & Reliable Mutation Errors (Issue #33)

## Goal
Re-warm the live session snapshot on foreground return and pull-to-refresh, and make
covered mutations fail visibly with optimistic rollback and Retry.

## Contract
- `AppDataContainer.refreshSession()` → live `LiveDataStore.refresh()` (clear caches,
  `warm()`, one revision on success; coalesce in-flight; debounce ~2s; restore snapshot
  on failure). Mock is a no-op.
- `ContentView` re-warms on return from background (skip first `.active`); failures silent.
- Pull-to-refresh: Friends (incl. Groups mode), Alerts, Pushes.
- Soft loads keep prior content while refreshing.
- Shared `ActionErrorState` + `ActionErrorBanner` (message, Retry, dismiss).
- Covered mutations: push RSVP/cancel/delete (rollback); friend remove; group create;
  friend-request and group-invite accept/deny (keep list; no full-screen fail).

## Acceptance
See `docs/superpowers/specs/2026-07-17-foreground-refresh-mutation-errors-design.md`.

---

# Persistent Profile Photo Uploads (Issue #34)

## Goal
Replace local-only profile images with persistent Supabase Storage-backed photos so a
user’s avatar survives relaunch and is visible to friends after they refresh.

## Product contract
- Profile avatar is tappable → choose photo / remove photo (when one exists).
- Photos are selected from the library (`PhotosPicker`), resized + JPEG-compressed on
  device, then uploaded.
- Persisted path lives on `profiles.image_asset_path` (existing column — no schema change).
- Mock mode stores a local file and updates `Person.imageAssetPath` via the in-memory store.
- Live mode uploads to a public `avatars` Storage bucket, then writes the public URL to
  `image_asset_path`. On profile-write failure after a successful upload, the new object
  is deleted so the profile never points at a missing file or a new file that was not
  committed.
- Remove clears `image_asset_path` first, then best-effort deletes the Storage object
  (orphan object is preferable to a broken reference).
- Shared avatar UI (`ProfilePhotoAvatar`, profile header, recipient avatars) loads
  bundle assets, local file paths, and remote HTTPS URLs with in-memory caching and
  initials fallback while loading or on failure.
- Surfaces that already pass `Person.imageAssetPath` / `profileImageAssetName` pick up
  remote photos without per-screen wiring (Friends, Alerts, Pushes, map pucks, etc.).

## Architecture
- **MVVM:** View → `ProfileViewModel` → `ProfileRepository` → local store or
  Supabase Storage + PostgREST. No `import Supabase` in Views/ViewModels.
- **`ProfileRepository`:**
  - `updateProfilePhoto(jpegData:)` — caller supplies already-processed JPEG bytes.
  - `removeProfilePhoto()`.
- **`ProfilePhotoProcessor`:** max dimension + JPEG quality constants; pure UIKit helper.
- **`ProfilePhotoStoring`:** Storage upload/delete seam; live impl uses supabase-swift
  Storage; injectable for tests.
- **`AvatarImageLoader`:** resolves `image_asset_path` → `UIImage?` (bundle / file / URL)
  with `NSCache`. Used by `ProfilePhotoAvatar` and other avatar views via `.task`.
- **Migration `0012_profile_photos`:** public `avatars` bucket + RLS
  (public SELECT; owner-only INSERT/UPDATE/DELETE under `{auth.uid()}/…`).

## Acceptance
- Mock: set photo → path updates → reload keeps it; remove clears path.
- Live (with migration applied): upload → relaunch still shows photo; friend refresh
  sees updated `image_asset_path` / public URL.
- Failed profile update after upload does not leave a non-null path pointing at nothing
  the profile row never adopted.
- Focused unit tests for processor, local repo photo writes, and avatar path resolution.
- `scripts/test.sh build` + focused suites green.

---

# Production Branding Assets (Issue #35)

## Goal
Ship a coherent, non-placeholder Push identity in production and TestFlight builds: a
complete app icon, an explicit brand accent, and a native launch screen whose first frame
matches the app's warm cream presentation.

## Product contract
- App icon uses the Push sunbeam / walnut palette and a simple, legible social-map mark.
- The icon contains no text, transparency, photography, or small detail that disappears at
  SpringBoard sizes.
- `AccentColor` resolves to the canonical sunbeam color in light and dark appearances.
- The generated iOS launch screen uses a catalog-backed cream background so it never flashes
  an unrelated system white/black surface before SwiftUI renders.
- Runtime loading and authentication surfaces remain SwiftUI-owned; no fake interactive launch
  UI or launch-delay behavior is introduced.

## Acceptance criteria
1. `AppIcon.appiconset` contains a valid opaque 1024×1024 production PNG referenced by
   `Contents.json`.
2. `AccentColor.colorset` and the launch-background colorset contain explicit sRGB values.
3. Release build settings reference the app icon, accent, and launch background assets.
4. A generic Release build succeeds without asset-catalog warnings about missing or unassigned
   production branding.
5. An archive succeeds and contains the compiled app icon and expected launch-screen metadata.

---

# Legal Destinations (Issue #36)

## Goal
Make Terms of Service and Privacy Policy actions real and consistent across the app while production documents are still awaiting hosting.

## Contract
- `LegalDestinations` is the single source of truth for both URLs and legal-row metadata.
- Until hosted documents exist, both destinations use reachable HTTPS placeholder pages with distinct query markers.
- Production auth welcome and the DEBUG onboarding lab render tappable inline Terms and Privacy links.
- Profile exposes a Legal card whose rows open the same destinations outside the app.
- No legal-looking text remains styled as interactive without an action.
- `docs/app-store-privacy.md` records current disclosure inputs and clearly separates implemented collection from future features.

## Replacement Procedure
1. Publish the final legal documents at stable public HTTPS URLs that require no authentication.
2. Replace `termsURL` and `privacyURL` in `Push/LegalDestinations.swift`.
3. Run `LegalDestinationsTests`, the build, and manually open all four entry points in a Release build.
4. Re-check `docs/app-store-privacy.md` against the shipping binary before App Store submission.

## Acceptance Criteria
- Both centralized URLs are valid HTTPS URLs and open a reachable destination.
- Onboarding Terms and Privacy are individually tappable.
- Profile contains Terms of Service and Privacy Policy rows.
- Focused tests guard titles, URLs, HTTPS, and the placeholder marker.
- App Store privacy disclosure inputs are documented.

## Release Blocker
The placeholder URLs do not contain Push's legal documents. They must be replaced before public distribution.
