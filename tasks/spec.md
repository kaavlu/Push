# Glass Language Consistency Spec

## Goal
Make the top controls and bottom navigation feel like one Apple-native glass design system.

## Inputs / Outputs
- Input: Existing SwiftUI glass controls in `Push/ContentView.swift`.
- Output: Shared visual tokens for glass background opacity, edge stroke, shadow, icon/text color treatment, and active accent behavior.

## Constraints
- Keep the current map layout, navigation structure, and mock-only prototype behavior unchanged.
- Use SwiftUI and existing local helpers only; add no dependencies.
- Keep changes tightly scoped to visual consistency.
- Preserve iOS 17 compatibility while keeping the existing conditional iOS 26 glass path.

## Edge Cases
- Inactive bottom navigation items must remain readable over the map.
- Selected bottom navigation items and selected dropdown rows must use the same accent language.
- Top icon buttons are actions, not selectable tabs, so their accent treatment should remain stable rather than toggled.

## Out of Scope
- New screens, map annotations, backend, authentication, location services, or notification behavior.
- Layout redesign of the top controls or bottom navigation.
- New color palette exploration beyond the existing walnut and sunbeam accents.

## Acceptance Criteria
- All glass containers use the same background opacity constants.
- All glass containers use the same edge stroke constants.
- All glass containers use the same shadow constants.
- Top and bottom controls share the same active and inactive foreground color rules.
- Selected bottom navigation items and selected dropdown rows share the same active accent fill.
- Existing tests pass, and edited Swift files have no new linter diagnostics.

## Test Stubs
- `testGlassStyleTokensExposeConsistentMaterialValues`
- `testControlStyleTokensExposeSharedAccentBehavior`
