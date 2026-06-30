# Friend Detail Sheet — Design Spec

**Date:** 2026-06-29  
**Issue:** [#2 Add Friend Detail sheet](https://github.com/kaavlu/Push/issues/2)  
**Status:** Approved

---

## Overview

When a user taps any puck on the map, a bottom sheet opens with contextual detail about that friend or group. For individual pucks this is a per-person view; for hangout/cluster/friendGroup pucks it is a group-level view.

---

## Data Model Changes

### `FriendPuckData` — two new fields

```swift
let lastUpdated: String        // e.g. "2 min ago", "Just now"
let withWhom: [String]?        // nil = solo; ["Ishan"] = with these people
```

- `lastUpdated` is a static human-readable string in mock data. No real timestamp computation.
- `withWhom` is a structured list of first names. Replaces the informal encoding currently baked into `venueStatusText` (e.g. "With Ishan"). The display string is derived from this array at render time.
- All existing `FriendPuckData` initialisations in `MapPuckMockData` and `PuckLabMockData` are updated with sensible defaults: solo friends get `withWhom: nil`; hangout members get each other's names.

---

## Tap Bridging

### `StyledMapView`

Gains one new property:

```swift
let onPuckSelected: (MapPuckData) -> Void
```

Passed into `Coordinator` at creation.

### `Coordinator`

New delegate method:

```swift
func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let annotation = view.annotation as? MapPuckAnnotation else { return }
    mapView.deselectAnnotation(annotation, animated: false)
    onPuckSelected(annotation.puck)
}
```

`deselectAnnotation` is called immediately so MKMapKit does not hold selection state — ContentView's binding owns that.

### `ContentView`

New state property:

```swift
@State private var selectedPuck: MapPuckData?
```

`StyledMapView` call site gains the callback:

```swift
StyledMapView(region: MapDefaults.region, pucks: filteredPucks) { puck in
    selectedPuck = puck
}
```

Sheet is presented with:

```swift
.sheet(item: $selectedPuck) { puck in
    FriendDetailSheet(puck: puck)
}
```

Swipe-to-dismiss automatically sets `selectedPuck = nil`.

---

## Sheet UI

### Presentation

```swift
.presentationDetents([.medium])
.presentationDragIndicator(.visible)
```

The system sheet chrome handles the drag indicator and background. The content container uses `pushGlassBackground` to match the map overlay controls.

### Individual puck layout

Top to bottom:

1. **Hero row** — `ProfilePhotoAvatar` at ~72pt + name in `.title2.bold` + `ActivityBadge` (availability colour + symbol) inline beneath the name
2. **Venue row** — SF symbol matching `activitySymbolName` + `venueStatusText` in `.subheadline`
3. **With row** *(conditional — only when `withWhom` is non-nil)* — `person.2.fill` icon + comma-joined names in `.subheadline`
4. **Updated row** — `clock` icon + `lastUpdated` in `.subheadline` with `.secondary` foreground
5. **Divider**
6. **Quick actions row** — horizontal, equal-width glass capsule buttons:
   - **Ping** — always shown, silent no-op
   - **Start plan** — always shown, silent no-op
   - **Pull Up?** — shown only when `availability == .joinable`, silent no-op
   - **Hide** — always shown, silent no-op

### Group puck layout (hangout / cluster / friendGroup)

Same structure with these differences:

- Hero row uses `AvatarStack` (existing component) instead of a single avatar. Headline is `"Ishan + Viplove"` for 2 people, `"4 people"` for 3+.
- Venue and activity rows use `MapPuckData.venueStatusText` and `MapPuckData.activity`.
- "With" row is replaced by the avatar stack header — no separate "with" row needed.
- **Ping** button label becomes **Ping all**.

### Styling

- Glass capsule buttons: `pushGlassBackground(cornerRadius: buttonHeight / 2)`, walnut foreground, sunbeam tint for the primary "Pull Up?" action
- Fonts and colours follow existing patterns: walnut for primary text, `.secondary` for metadata rows
- No custom `.presentationBackground` override — system default

---

## New Files

| File | Purpose |
|---|---|
| `FriendDetailSheet.swift` | Sheet view — individual and group layouts |
| `FriendDetailSheetStyle.swift` | Layout constants for the sheet |

No new ViewModels. The sheet is display-only with no mutable state.

---

## Modified Files

| File | Change |
|---|---|
| `PuckModels.swift` | Add `lastUpdated: String` and `withWhom: [String]?` to `FriendPuckData`; update `PuckLabMockData` initialisations with new fields |
| `MapPuckModels.swift` | Update `MapPuckMockData` initialisations with new fields |
| `StyledMapView.swift` | Add `onPuckSelected` closure; implement `mapView(_:didSelect:)` in `Coordinator` |
| `ContentView.swift` | Add `selectedPuck` state; pass callback to `StyledMapView`; add `.sheet(item:)` |

---

## Out of Scope

- Real tap feedback / toasts for quick actions (deferred)
- Navigation from sheet to a full profile page (deferred)
- `MainMapViewModel` extraction — noted as a natural follow-up once map-level logic grows
- Ghost Mode / privacy enforcement on the sheet
