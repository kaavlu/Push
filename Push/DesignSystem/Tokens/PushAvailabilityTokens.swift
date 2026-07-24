//
//  PushAvailabilityTokens.swift
//  Push
//
//  DS-043 — single availability color path (accent, chip fill, chip text).
//

import SwiftUI

/// Canonical availability colors. Rings, list chips, map badges, and live dots
/// must consume these — no local free-now greens or ad-hoc state colors.
enum PushAvailabilityTokens {
    static let freeNow = Color(red: 0.43, green: 0.91, blue: 0.62)
    static let maybeDown = Color(red: 1.00, green: 0.78, blue: 0.24)
    static let busy = Color(red: 1.00, green: 0.50, blue: 0.25)
    static let joinable = Color(red: 0.25, green: 0.55, blue: 1.00)
    static let driving = Color(red: 0.22, green: 0.88, blue: 1.00)
    static let unavailable = Color(red: 0.55, green: 0.58, blue: 0.64)

    static let avatarForeground = Color.white
    static let badgeForeground = Color.white
    static let avatarGradientBase = Color(red: 0.18, green: 0.15, blue: 0.22)
    static let avatarGradientHighOpacity = 0.88

    // Chip fill opacities — freeSoon vs maybeDown intentionally differ (DS-043).
    static let freeNowChipFillOpacity = 0.88
    static let freeSoonChipFillOpacity = 0.82
    static let maybeDownChipFillOpacity = 0.90
    static let busyChipFillOpacity = 0.82
    static let joinableChipFillOpacity = 0.88
    static let drivingChipFillOpacity = 0.82
    static let unavailableChipFillOpacity = 0.55

    static let freeNowChipText = Color(red: 0.04, green: 0.30, blue: 0.16)
    static let freeSoonChipText = PushColorPalette.Accent.walnut
    static let maybeDownChipText = PushColorPalette.Accent.walnut
    static let busyChipText = Color(red: 0.52, green: 0.15, blue: 0.02)
    static let joinableChipText = Color.white
    static let drivingChipText = Color(red: 0.02, green: 0.30, blue: 0.42)
    static let unavailableChipText = Color(red: 0.22, green: 0.24, blue: 0.28)
}

extension FriendAvailabilityState {
    var accentColor: Color {
        switch self {
        case .freeNow:
            return PushAvailabilityTokens.freeNow
        case .freeSoon, .maybeDown:
            return PushAvailabilityTokens.maybeDown
        case .busy:
            return PushAvailabilityTokens.busy
        case .joinable:
            return PushAvailabilityTokens.joinable
        case .driving:
            return PushAvailabilityTokens.driving
        case .unavailable, .ghost:
            return PushAvailabilityTokens.unavailable
        }
    }

    var chipFillColor: Color {
        switch self {
        case .freeNow:
            return PushAvailabilityTokens.freeNow.opacity(PushAvailabilityTokens.freeNowChipFillOpacity)
        case .freeSoon:
            return PushAvailabilityTokens.maybeDown.opacity(PushAvailabilityTokens.freeSoonChipFillOpacity)
        case .maybeDown:
            return PushColorPalette.Accent.sunbeam.opacity(PushAvailabilityTokens.maybeDownChipFillOpacity)
        case .busy:
            return PushAvailabilityTokens.busy.opacity(PushAvailabilityTokens.busyChipFillOpacity)
        case .joinable:
            return PushAvailabilityTokens.joinable.opacity(PushAvailabilityTokens.joinableChipFillOpacity)
        case .driving:
            return PushAvailabilityTokens.driving.opacity(PushAvailabilityTokens.drivingChipFillOpacity)
        case .unavailable, .ghost:
            return PushAvailabilityTokens.unavailable.opacity(PushAvailabilityTokens.unavailableChipFillOpacity)
        }
    }

    var chipTextColor: Color {
        switch self {
        case .freeNow: return PushAvailabilityTokens.freeNowChipText
        case .freeSoon: return PushAvailabilityTokens.freeSoonChipText
        case .maybeDown: return PushAvailabilityTokens.maybeDownChipText
        case .busy: return PushAvailabilityTokens.busyChipText
        case .joinable: return PushAvailabilityTokens.joinableChipText
        case .driving: return PushAvailabilityTokens.drivingChipText
        case .unavailable, .ghost: return PushAvailabilityTokens.unavailableChipText
        }
    }
}

/// Migration shim — prefer `PushAvailabilityTokens`.
typealias PuckColorTokens = PushAvailabilityTokens
