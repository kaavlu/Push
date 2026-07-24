//
//  PushRadiusTokens.swift
//  Push
//
//  DS-080 — named radius roles. Always use continuous corner style in views.
//

import CoreGraphics
import SwiftUI

/// Role-based radii. Prefer adaptive `layout.cardCornerRadius` for cards when
/// available; fixed roles below cover controls that are not width-adaptive.
enum PushRadiusTokens {
    /// Ivory list / Plans glass cards — use with `PushAdaptiveLayout.cardCornerRadius`.
    static func card(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.cardCornerRadius
    }

    /// Circular control size (close buttons, header icons).
    static let controlCircle: CGFloat = 44

    /// Compact ivory segmented item.
    static let segmentedItem: CGFloat = 18

    /// Segmented track container.
    static let segmentedTrack: CGFloat = 22

    /// Search / field rows on cream.
    static let field: CGFloat = 18

    /// Dense list inner row corners.
    static let listRow: CGFloat = 20

    /// Review deck card (fixed premium radius).
    static let reviewCard: CGFloat = 30

    /// Capsule / pill — use `Capsule()` rather than a numeric radius.
    static let pillUsesCapsule = true
}
