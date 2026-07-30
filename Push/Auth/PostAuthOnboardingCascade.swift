// Push/Auth/PostAuthOnboardingCascade.swift
import SwiftUI

/// Shared top-down reveal timing for post-auth onboarding screens.
/// Slide 1 (Know the move) uses default pace; slides 2+ use `later` pace (slower).
enum OnboardingCascadeTiming {
    // MARK: Slide 1 (Know the move)

    static let staggerNanoseconds: UInt64 = 380_000_000
    static let friendPopNanoseconds: UInt64 = 520_000_000
    static let beatNanoseconds: UInt64 = 520_000_000
    static let revealOffsetY: CGFloat = 10
    static let cascade = Animation.easeInOut(duration: 0.55)
    static let friendPop = Animation.easeOut(duration: 0.70)

    // MARK: Slide 2 onwards (noticeably slower)

    static let laterStaggerNanoseconds: UInt64 = 620_000_000
    static let laterBeatNanoseconds: UInt64 = 780_000_000
    static let laterCascade = Animation.easeInOut(duration: 0.90)
    /// Between post-auth screens (container transition).
    static let screenChange = Animation.easeOut(duration: 0.95)
}

extension View {
    /// Fade + slight rise used for staged onboarding reveals.
    func onboardingCascadeVisible(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : OnboardingCascadeTiming.revealOffsetY)
    }

    /// Scale-pop for friend pucks on the teaching map.
    func onboardingFriendPopVisible(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.55)
    }
}

@MainActor
enum OnboardingCascadeRunner {
    /// Jump to a completed reveal step with no animation (used after Back).
    static func revealInstantly(_ current: inout Int, to target: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            current = target
        }
    }

    static func step(
        _ current: inout Int,
        to target: Int,
        laterScreen: Bool = false,
        animated: Bool = true
    ) {
        guard target > current else { return }
        let animation = laterScreen
            ? OnboardingCascadeTiming.laterCascade
            : OnboardingCascadeTiming.cascade
        if animated {
            withAnimation(animation) {
                current = target
            }
        } else {
            current = target
        }
    }

    static func sleepStagger(laterScreen: Bool = false) async {
        let ns = laterScreen
            ? OnboardingCascadeTiming.laterStaggerNanoseconds
            : OnboardingCascadeTiming.staggerNanoseconds
        try? await Task.sleep(nanoseconds: ns)
    }

    static func sleepFriendPop() async {
        try? await Task.sleep(nanoseconds: OnboardingCascadeTiming.friendPopNanoseconds)
    }

    static func sleepBeat(laterScreen: Bool = false) async {
        let ns = laterScreen
            ? OnboardingCascadeTiming.laterBeatNanoseconds
            : OnboardingCascadeTiming.beatNanoseconds
        try? await Task.sleep(nanoseconds: ns)
    }
}

// MARK: - Production teach fixtures (not DEBUG-only lab)

enum PostAuthTeachFriendFixture: Identifiable {
    case leading, lowerLeading, lowerTrailing

    var id: String { rawKey }

    private var rawKey: String {
        switch self {
        case .leading: return "leading"
        case .lowerLeading: return "lowerLeading"
        case .lowerTrailing: return "lowerTrailing"
        }
    }

    var assetName: String {
        switch self {
        case .leading: return "assets/friends/ohm.png"
        case .lowerLeading: return "assets/friends/ram.png"
        case .lowerTrailing: return "assets/friends/nitin.png"
        }
    }

    var ring: Color {
        switch self {
        case .leading: return OnboardingLabColor.stateJoinable
        case .lowerLeading: return OnboardingLabColor.stateDriving
        case .lowerTrailing: return OnboardingLabColor.stateMaybe
        }
    }

    /// Offset from map center (self puck).
    /// Layout: one upper-left, two lower (left + right) — no top-right puck.
    var offset: CGSize {
        switch self {
        case .leading: return CGSize(width: -78, height: -40)
        case .lowerLeading: return CGSize(width: -72, height: 48)
        case .lowerTrailing: return CGSize(width: 58, height: 50)
        }
    }

    var size: CGFloat {
        switch self {
        case .leading: return 40
        case .lowerLeading: return 38
        case .lowerTrailing: return 40
        }
    }

    static let all: [PostAuthTeachFriendFixture] = [.leading, .lowerLeading, .lowerTrailing]
}
