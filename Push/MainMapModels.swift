//
//  MainMapModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

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
            return "Friends"
        case .create:
            return "+"
        case .feed:
            return "Feed"
        case .plans:
            return "Pushes"
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
    case alerts
    case startPlan
    case addFriend
    case feed
    case plans
    case startPush

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .groups:
            return "Friends"
        case .profile:
            return "Profile"
        case .alerts:
            return "Alerts"
        case .startPlan:
            return "Start Push"
        case .addFriend:
            return "Add Friend"
        case .feed:
            return "Feed"
        case .plans:
            return "Pushes"
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
        case .alerts:
            return "bell.fill"
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
