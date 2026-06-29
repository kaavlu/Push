//
//  ProfileModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

struct ProfileData: Equatable {
    let name: String
    let initials: String
    let handle: String
    let imageAssetName: String?
    let availability: FriendAvailabilityState
    let activityTitle: String
    let placeTitle: String
    let visibilityNote: String
    let availabilityOptions: [ProfileAvailabilityOption]
}

struct ProfileAvailabilityOption: Identifiable, Equatable {
    let availability: FriendAvailabilityState
    let subtitle: String

    var id: FriendAvailabilityState { availability }
    var title: String { availability.title }
    var symbolName: String { availability.symbolName }
}

enum ProfileStatusOption: Identifiable, Equatable {
    case ghostMode
    case availability(ProfileAvailabilityOption)

    var id: String {
        switch self {
        case .ghostMode:
            return "ghost-mode"
        case .availability(let option):
            return option.availability.title
        }
    }

    var title: String {
        switch self {
        case .ghostMode:
            return "Ghost Mode"
        case .availability(let option):
            return option.title
        }
    }

    var subtitle: String {
        switch self {
        case .ghostMode:
            return "Hide from friends' map and social context."
        case .availability(let option):
            return option.subtitle
        }
    }

    var symbolName: String {
        switch self {
        case .ghostMode:
            return "eye.slash.fill"
        case .availability(let option):
            return option.symbolName
        }
    }
}

enum ProfileSection: String, Equatable {
    case settings = "Settings"
    case privacy = "Privacy"
}

enum ProfileRoute: String, CaseIterable, Identifiable, Equatable {
    case editProfile
    case activityVisibility
    case mapPreferences
    case closeFriends

    var id: String {
        switch self {
        case .editProfile:
            return "edit-profile"
        case .activityVisibility:
            return "activity-visibility"
        case .mapPreferences:
            return "map-preferences"
        case .closeFriends:
            return "close-friends"
        }
    }

    var title: String {
        switch self {
        case .editProfile:
            return "Edit profile"
        case .activityVisibility:
            return "Activity visibility"
        case .mapPreferences:
            return "Map preferences"
        case .closeFriends:
            return "Close Friends"
        }
    }

    var subtitle: String {
        switch self {
        case .editProfile:
            return "Name, photo, and basics"
        case .activityVisibility:
            return "Choose what shows up on the map"
        case .mapPreferences:
            return "Tune your default map view"
        case .closeFriends:
            return "Can see your live social context"
        }
    }

    var symbolName: String {
        switch self {
        case .editProfile:
            return "pencil"
        case .activityVisibility:
            return "eye.fill"
        case .mapPreferences:
            return "map.fill"
        case .closeFriends:
            return "person.2.fill"
        }
    }

    var section: ProfileSection {
        switch self {
        case .editProfile, .activityVisibility, .mapPreferences:
            return .settings
        case .closeFriends:
            return .privacy
        }
    }
}

struct ProfileToggleItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    var isEnabled: Bool
}

struct ProfileConnector: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let buttonTitle: String
    let permissionCopy: String
    let alertTitle: String
    let alertMessage: String
}

struct ProfileConnectorAlert: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
}
