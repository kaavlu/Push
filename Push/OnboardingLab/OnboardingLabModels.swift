//
//  OnboardingLabModels.swift
//  Push
//
//  Screen definitions and static fixtures for the Onboarding Lab.
//  Fixtures exist only to render the flow; no data layer is involved.
//

#if DEBUG
import SwiftUI

/// The eleven onboarding steps, in flow order.
enum OnboardingScreen: String, CaseIterable, Identifiable {
    case welcome, signIn, phone, verify, preview, profile, privacy
    case location, notifications, contacts, friends, done

    var id: String { rawValue }

    /// Whether the in-frame back chevron shows on this screen.
    var showsBackButton: Bool { self != .welcome && self != .done }

    /// 1-based position in the top progress bar, or 0 when hidden.
    /// Progress runs across the five setup screens (profile → contacts).
    var progressStep: Int {
        switch self {
        case .profile: return 1
        case .privacy: return 2
        case .location: return 3
        case .notifications: return 4
        case .contacts: return 5
        case .friends: return 5
        default: return 0
        }
    }

    static let progressTotal = 5
}

/// Sign-in method chosen on the welcome screen. Mobile routes through
/// phone + verify before the value preview.
enum OnboardingAuthMethod {
    case google, mobile
}

/// Location-sharing choice on the privacy screen.
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
}

/// A friend surfaced on the value-preview map + rows.
struct OnboardingPreviewFriend: Identifiable {
    let id = UUID()
    let name: String
    let assetName: String
    let detail: String
    let chip: String
    let chipIcon: String
    let ring: Color
    let chipFill: Color
    let chipText: Color
}

/// A contact that can be added on the "already on Push" screen.
struct OnboardingContact: Identifiable {
    let id: String
    let name: String
    let assetName: String
    let detail: String
}

/// A sample push notification shown on the notifications primer.
struct OnboardingNotificationSample: Identifiable {
    let id = UUID()
    let assetName: String?
    let badge: String?
    let ring: Color
    let title: String
    let subtitle: String
}

/// All static content the flow renders.
enum OnboardingLabFixtures {
    static let previewFriends: [OnboardingPreviewFriend] = [
        OnboardingPreviewFriend(
            name: "aarav", assetName: "assets/friends/ohm.png",
            detail: "At Blue Bottle", chip: "joinable?", chipIcon: "☕",
            ring: OnboardingLabColor.stateJoinable,
            chipFill: OnboardingLabColor.stateJoinable,
            chipText: .white
        ),
        OnboardingPreviewFriend(
            name: "sid", assetName: "assets/friends/ram.png",
            detail: "Driving home", chip: "ETA 14 min", chipIcon: "🚗",
            ring: OnboardingLabColor.stateDriving,
            chipFill: OnboardingLabColor.stateDriving.opacity(0.28),
            chipText: OnboardingLabColor.stateDrivingText
        ),
        OnboardingPreviewFriend(
            name: "maya", assetName: "assets/friends/nitin.png",
            detail: "At work", chip: "Free after 5:45", chipIcon: "🕔",
            ring: OnboardingLabColor.stateMaybe,
            chipFill: OnboardingLabColor.stateMaybe.opacity(0.50),
            chipText: OnboardingLabColor.walnut
        ),
    ]

    static let contacts: [OnboardingContact] = [
        OnboardingContact(id: "ryan", name: "ryan", assetName: "assets/friends/ryan.png", detail: "12 mutual friends"),
        OnboardingContact(id: "roh", name: "roh", assetName: "assets/friends/roh.png", detail: "8 mutual friends"),
        OnboardingContact(id: "pranay", name: "pranay", assetName: "assets/friends/pranay.png", detail: "21 mutual friends"),
        OnboardingContact(id: "chitty", name: "chitty", assetName: "assets/friends/chitty.png", detail: "5 mutual friends"),
        OnboardingContact(id: "rohan", name: "rohan", assetName: "assets/friends/rohan.png", detail: "9 mutual friends"),
        OnboardingContact(id: "viplove", name: "viplove", assetName: "assets/friends/viplove.png", detail: "3 mutual friends"),
    ]

    static let notificationSamples: [OnboardingNotificationSample] = [
        OnboardingNotificationSample(
            assetName: "assets/friends/ram.png", badge: nil,
            ring: OnboardingLabColor.stateJoinable,
            title: "sid is 2 min away 🚗", subtitle: "heading toward the mission"
        ),
        OnboardingNotificationSample(
            assetName: "assets/friends/nitin.png", badge: nil,
            ring: OnboardingLabColor.stateMaybe,
            title: "maya started a plan ☕", subtitle: "coffee at blue bottle · join?"
        ),
        OnboardingNotificationSample(
            assetName: nil, badge: "3",
            ring: OnboardingLabColor.sage,
            title: "3 friends are free now", subtitle: "nobody's texting the group chat"
        ),
    ]

    static let profileImageAssetName = "assets/profile/manav.jpeg"

    static let heroPucks: [FriendPuckData] = [
        heroFriend(
            id: "onboarding-free-now",
            name: "ava",
            initials: "AV",
            activity: "Coffee",
            symbolName: "cup.and.saucer.fill",
            displayText: "Blue Bottle",
            availability: .freeNow,
            venueStatusText: "At Blue Bottle",
            locationLabel: "Hayes Valley"
        ),
        heroFriend(
            id: "onboarding-joinable",
            name: "leo",
            initials: "LE",
            activity: "Gym",
            symbolName: "figure.strengthtraining.traditional",
            displayText: "Crunch",
            availability: .joinable,
            venueStatusText: "At Crunch",
            locationLabel: "Mission"
        ),
        heroFriend(
            id: "onboarding-maybe-down",
            name: "mia",
            initials: "MI",
            activity: "Park",
            symbolName: "leaf.fill",
            displayText: "Dolores",
            availability: .maybeDown,
            venueStatusText: "Near Dolores",
            locationLabel: "Dolores"
        ),
    ]

    /// Floating avatars on the welcome / done hero, with ring colors.
    static let heroFriends: [(asset: String, ring: Color)] = [
        ("assets/friends/ryan.png", OnboardingLabColor.stateFree),
        ("assets/friends/pranay.png", OnboardingLabColor.stateJoinable),
        ("assets/friends/roh.png", OnboardingLabColor.stateMaybe),
    ]

    private static func heroFriend(
        id: String,
        name: String,
        initials: String,
        activity: String,
        symbolName: String,
        displayText: String,
        availability: FriendAvailabilityState,
        venueStatusText: String,
        locationLabel: String
    ) -> FriendPuckData {
        FriendPuckData(
            id: id,
            name: name,
            avatarPlaceholder: initials,
            profileImageAssetName: nil,
            activity: activity,
            activitySymbolName: symbolName,
            activityDisplayText: displayText,
            availability: availability,
            venueStatusText: venueStatusText,
            locationLabel: locationLabel,
            placeName: displayText
        )
    }
}
#endif
