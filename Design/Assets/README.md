# Assets

Copied brand/UI imagery. Nothing generated or from build output is included.

## `Assets.xcassets/`
The app's asset catalog (verbatim copy of `Push/Assets.xcassets`).
- `UserLocationPin.imageset/UserLocationPin.png` — the current user's own map pin (the only
  real image in the catalog).
- `AppIcon.appiconset/Contents.json` — **empty** 1024×1024 slot; no app icon image exists yet.
- `AccentColor.colorset/Contents.json` — **empty**; brand accent is defined in code
  (`PushColorPalette.swift`), not the catalog.
- `Contents.json` — catalog root.

## `BundledImages/`
Verbatim copy of the repo's `assets/` folder. These are the real avatar/tile images the app
loads at runtime via `PushImageAssets.swift` (bundled-path lookup like `friends/ohm.png`,
`groups/Michigan/ohm.png`).
- `friends/` — individual friend avatars (used on pucks, cards, sheets).
- `groups/{Michigan,Exec,India}/` — per-group member avatars (used on group tiles/detail).
- `profile/manav.jpeg` — the current user's profile photo.

These matter to Claude Design because they show the **real faces + tile imagery** the UI is
built around — the app's "people over pins" identity.
