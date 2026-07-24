//
//  PushOpacityTokens.swift
//  Push
//
//  DS-083 — shared disabled/inactive/scrim opacities + minimum text scale.
//

import CoreGraphics

/// Cross-cutting opacity and scale tokens. Component-private surface opacities
/// stay inside surface recipes; these cover shared control states.
enum PushOpacityTokens {
    /// Inactive label / secondary walnut at rest.
    static let inactiveLabel = 0.70

    /// Disabled solid primary fill (sunbeam CTA).
    static let disabledControlFill = 0.45

    /// Generic disabled control chrome.
    static let disabledControl = 0.55

    /// Full-screen dim behind menus (create menu, etc.).
    static let scrim = 0.12

    /// Stronger dim behind centered confirmation dialogs (DS-090).
    static let dialogScrim = 0.36

    /// Dense truncating labels (chips, group rows, pills).
    static let minimumTextScale: CGFloat = 0.82
}
