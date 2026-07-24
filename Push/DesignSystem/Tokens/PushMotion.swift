//
//  PushMotion.swift
//  Push
//
//  DS-082 — named motion tokens. Feature code picks a named motion; no new
//  spring/duration literals without promoting a token or a DS decision.
//

import SwiftUI

/// Canonical interaction animations for the design system.
enum PushMotion {
    /// Segmented switch, filter chips, modal choice pills, list selection.
    static let selection = Animation.spring(response: 0.28, dampingFraction: 0.86)

    /// Slightly snappier selection (AM/PM, compact pills, check rows).
    static let selectionSnappy = Animation.spring(response: 0.22, dampingFraction: 0.82)

    /// Expandable person-row rail open/close.
    static let expand = Animation.spring(response: 0.40, dampingFraction: 0.86)

    /// Map bottom sheets + modal sheet presentation (interactive spring).
    static let sheet = Animation.interactiveSpring(
        response: 0.42,
        dampingFraction: 0.86,
        blendDuration: 0.12
    )

    /// Sheet metrics for non-Animation consumers (drag thresholds, etc.).
    enum Sheet {
        static let response = 0.42
        static let damping = 0.86
        static let blendDuration = 0.12
        static let dismissAnimationDuration = 0.40
        static let closedScale: CGFloat = 0.96
    }

    /// Expand metrics for layout/transition constants.
    enum Expand {
        static let response = 0.40
        static let damping = 0.86
    }

    /// Selection metrics for layout enums that still expose response/damping.
    enum Selection {
        static let response = 0.28
        static let damping = 0.86
        static let snappyResponse = 0.22
        static let snappyDamping = 0.82
    }

    /// Button press scale + duration (onboarding primary + shared press style).
    static let press = Animation.easeInOut(duration: 0.18)
    static let pressDuration = 0.18
    static let pressScale: CGFloat = 0.97

    /// Short content fade / mode subtitle change.
    static let contentCrossfade = Animation.easeInOut(duration: 0.20)

    /// Toast / soft list remove.
    static let softRemove = Animation.easeInOut(duration: 0.25)

    /// Map availability ring pulse (repeating ease).
    static let mapPulseDuration = 2.4
    static var mapPulse: Animation {
        .easeInOut(duration: mapPulseDuration).repeatForever(autoreverses: true)
    }

    /// Create-menu / dropdown panel present.
    static let menuPresent = Animation.spring(response: 0.26, dampingFraction: 0.88)

    /// Friend detail hangout action reveal.
    static let hangoutReveal = Animation.spring(response: 0.35, dampingFraction: 0.82)
}
