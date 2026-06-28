# Glass Language Consistency Plan

## Goal
Make the top controls and bottom navigation feel like one Apple-native glass design system.

## Architecture
Keep the existing SwiftUI view structure and extract shared visual constants inside `ContentView.swift`. The `pushGlassBackground` modifier will read from shared glass tokens, while top controls, dropdown rows, and bottom navigation labels will read from shared control color tokens.

## Files
- Modify: `Push/ContentView.swift`
- Test: `PushTests/PushTests.swift`
- Reference: `tasks/spec.md`

## Global Constraints
- Keep the current map layout, navigation structure, and mock-only prototype behavior unchanged.
- Use SwiftUI and existing local helpers only; add no dependencies.
- Preserve iOS 17 compatibility while keeping the existing conditional iOS 26 glass path.

## Tasks
- [x] Add tests for shared glass and control color tokens in `PushTests/PushTests.swift`.
- [x] Add shared `PushGlassStyle` and `PushControlColors` constants in `Push/ContentView.swift`.
- [x] Update `pushMaterialBackground`, dropdown rows, top controls, bottom nav labels, and primary nav button to consume shared constants.
- [x] Run the focused test suite and check edited Swift files for linter diagnostics.

## Expected Test Additions
```swift
func testGlassStyleTokensExposeConsistentMaterialValues() throws {
    XCTAssertEqual(PushGlassStyle.materialPresenceOpacity, 0.72)
    XCTAssertEqual(PushGlassStyle.tintOpacity, 0.24)
    XCTAssertEqual(PushGlassStyle.strokeOpacity, 0.62)
    XCTAssertEqual(PushGlassStyle.strokeWidth, 0.8)
    XCTAssertEqual(PushGlassStyle.shadowOpacity, 0.24)
    XCTAssertEqual(PushGlassStyle.shadowRadius, 26)
    XCTAssertEqual(PushGlassStyle.shadowYOffset, 12)
}

func testControlStyleTokensExposeSharedAccentBehavior() throws {
    XCTAssertEqual(PushControlStyle.activeFillOpacity, 1)
    XCTAssertEqual(PushControlStyle.inactiveForegroundOpacity, 0.7)
    XCTAssertEqual(PushControlStyle.primaryStrokeOpacity, 0.72)
    XCTAssertEqual(PushControlStyle.primaryGlowOpacity, 0.34)
}
```

## Verification
- Run: `xcodebuild test -scheme Push -destination 'platform=iOS Simulator,name=iPhone 15'`
- Read linter diagnostics for `Push/ContentView.swift`, `Push/PushColorPalette.swift`, and `PushTests/PushTests.swift`.

## Results
- Passed: `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild test -scheme Push -destination 'platform=iOS Simulator,name=iPhone 14' CODE_SIGNING_ALLOWED=NO`
- Lints: no diagnostics for edited Swift files.
