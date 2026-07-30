// Push/Auth/PostAuthOnboardingCascade.swift
import SwiftUI

/// Shared top-down reveal timing for post-auth onboarding screens.
enum OnboardingCascadeTiming {
    static let staggerNanoseconds: UInt64 = 140_000_000
    static let friendPopNanoseconds: UInt64 = 160_000_000
    static let revealOffsetY: CGFloat = 10
    /// Pause after map paints before friend pops / ghost sequence.
    static let beatNanoseconds: UInt64 = 220_000_000
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
            withAnimation(PushMotion.contentCrossfade) {
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
    case leading, trailing, lower

    var id: String { rawKey }

    private var rawKey: String {
        switch self {
        case .leading: return "leading"
        case .trailing: return "trailing"
        case .lower: return "lower"
        }
    }

    var assetName: String {
        switch self {
        case .leading: return "assets/friends/ohm.png"
        case .trailing: return "assets/friends/ram.png"
        case .lower: return "assets/friends/nitin.png"
        }
    }

    var ring: Color {
        switch self {
        case .leading: return OnboardingLabColor.stateJoinable
        case .trailing: return OnboardingLabColor.stateDriving
        case .lower: return OnboardingLabColor.stateMaybe
        }
    }

    /// Offset from map center (self puck).
    var offset: CGSize {
        switch self {
        case .leading: return CGSize(width: -78, height: -40)
        case .trailing: return CGSize(width: 80, height: -28)
        case .lower: return CGSize(width: 52, height: 50)
        }
    }

    var size: CGFloat {
        switch self {
        case .leading: return 40
        case .trailing: return 38
        case .lower: return 40
        }
    }

    static let all: [PostAuthTeachFriendFixture] = [.leading, .trailing, .lower]
}
