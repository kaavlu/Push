// Push/Auth/OnboardingPrivacyOption.swift
import SwiftUI

/// Location-sharing choice on the privacy primer (production + DEBUG lab).
enum OnboardingPrivacyOption: String, CaseIterable, Identifiable {
    case exactActivity, exact, vague, ghost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exactActivity: return "Exact location + activity"
        case .exact: return "Exact location only"
        case .vague: return "Vague location"
        case .ghost: return "Ghost mode"
        }
    }

    var subtitle: String {
        switch self {
        case .exactActivity: return "Where you are and what you're up to"
        case .exact: return "Show your spot, skip the activity"
        case .vague: return "Just your neighborhood"
        case .ghost: return "Go invisible. See friends, stay hidden."
        }
    }

    var symbolName: String {
        switch self {
        case .exactActivity: return "mappin.and.ellipse"
        case .exact: return "map"
        case .vague: return "cloud.fill"
        case .ghost: return "eye.slash"
        }
    }

    var iconTint: Color {
        switch self {
        case .exactActivity: return OnboardingLabColor.stateJoinable
        case .exact: return OnboardingLabColor.sage
        case .vague: return OnboardingLabColor.stateVague
        case .ghost: return OnboardingLabColor.walnut
        }
    }

    /// Maps to `sharing_policies` global_default + Ghost publish flag.
    var locationVisibility: SharingPolicy.LocationVisibility {
        switch self {
        case .exactActivity, .exact: return .exact
        case .vague: return .vague
        case .ghost: return .hidden
        }
    }

    var activityVisibility: SharingPolicy.DetailVisibility {
        switch self {
        case .exactActivity: return .full
        case .exact: return .hidden
        case .vague: return .vague
        case .ghost: return .hidden
        }
    }

    var availabilityVisibility: SharingPolicy.AvailabilityVisibility {
        switch self {
        case .ghost: return .hidden
        default: return .full
        }
    }

    /// Ghost = orthogonal unpublish (`is_published` false).
    var isPresencePublishingEnabled: Bool { self != .ghost }
}
