// Push/Auth/PostAuthOnboardingCascade.swift
import SwiftUI

/// Shared top-down reveal timing for post-auth onboarding screens.
/// Tuned deliberately slow — product prefers calm, readable staging over snap.
enum OnboardingCascadeTiming {
    /// Delay between cascade steps (title → subtitle → …).
    static let staggerNanoseconds: UInt64 = 380_000_000
    /// Delay between each friend puck pop on Know the move.
    static let friendPopNanoseconds: UInt64 = 520_000_000
    static let revealOffsetY: CGFloat = 10
    /// Pause after map paints before friend pops / ghost sequence.
    static let beatNanoseconds: UInt64 = 520_000_000

    /// Default fade/rise for staged onboarding content.
    static let cascade = Animation.easeInOut(duration: 0.55)
    /// Friend pucks: slower opacity + scale so they read as sequential arrivals.
    static let friendPop = Animation.easeOut(duration: 0.70)
    /// Between post-auth screens (container transition).
    static let screenChange = Animation.easeOut(duration: 0.65)
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
    static func step(
        _ current: inout Int,
        to target: Int,
        animated: Bool = true
    ) {
        guard target > current else { return }
        if animated {
            withAnimation(OnboardingCascadeTiming.cascade) {
                current = target
            }
        } else {
            current = target
        }
    }

    static func sleepStagger() async {
        try? await Task.sleep(nanoseconds: OnboardingCascadeTiming.staggerNanoseconds)
    }

    static func sleepFriendPop() async {
        try? await Task.sleep(nanoseconds: OnboardingCascadeTiming.friendPopNanoseconds)
    }

    static func sleepBeat() async {
        try? await Task.sleep(nanoseconds: OnboardingCascadeTiming.beatNanoseconds)
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
