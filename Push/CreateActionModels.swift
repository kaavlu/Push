//
//  CreateActionModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

enum CreateActionMenuItem: String, CaseIterable, Identifiable, Equatable {
    case startPlan
    case addFriend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startPlan:
            return "Start plan"
        case .addFriend:
            return "Add friend"
        }
    }

    var subtitle: String {
        switch self {
        case .startPlan:
            return "Create a plan with friends"
        case .addFriend:
            return "Invite someone to Bump"
        }
    }

    var symbolName: String {
        switch self {
        case .startPlan:
            return "calendar.badge.plus"
        case .addFriend:
            return "person.badge.plus"
        }
    }

    var route: MainMapRoute {
        switch self {
        case .startPlan:
            return .startPlan
        case .addFriend:
            return .addFriend
        }
    }
}
