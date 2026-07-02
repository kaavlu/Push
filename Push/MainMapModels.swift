//
//  MainMapModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

enum FriendGroupFilter: String, CaseIterable, Identifiable {
    case allFriends
    case india
    case exec
    case michigan

    var id: Self { self }

    var title: String {
        switch self {
        case .allFriends:
            return "All Friends"
        case .india:
            return "India"
        case .exec:
            return "Exec"
        case .michigan:
            return "Michigan"
        }
    }
}

enum BottomNavigationItem: String, CaseIterable, Identifiable {
    case map
    case group
    case create
    case feed
    case plans

    var id: Self { self }

    var title: String {
        switch self {
        case .map:
            return "Map"
        case .group:
            return "Group"
        case .create:
            return "+"
        case .feed:
            return "Feed"
        case .plans:
            return "Plans"
        }
    }

    var systemImageName: String {
        switch self {
        case .map:
            return "map.fill"
        case .group:
            return "person.2.fill"
        case .create:
            return "plus"
        case .feed:
            return "list.bullet"
        case .plans:
            return "calendar"
        }
    }

    var showsSelectionHighlight: Bool {
        self != .group
    }

    var isPrimaryAction: Bool {
        self == .create
    }
}

enum MainMapRoute: String, Identifiable, Equatable {
    case groups
    case profile
    case startPlan
    case addFriend
    case feed
    case plans
    case startPush

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .groups:
            return "Groups"
        case .profile:
            return "Profile"
        case .startPlan:
            return "Start Plan"
        case .addFriend:
            return "Add Friend"
        case .feed:
            return "Feed"
        case .plans:
            return "Plans"
        case .startPush:
            return "Start Push"
        }
    }

    var systemImageName: String {
        switch self {
        case .groups:
            return "person.2.fill"
        case .profile:
            return "person.crop.circle.fill"
        case .startPlan:
            return "calendar.badge.plus"
        case .addFriend:
            return "person.badge.plus"
        case .feed:
            return "list.bullet"
        case .plans:
            return "calendar"
        case .startPush:
            return "bolt.fill"
        }
    }
}
