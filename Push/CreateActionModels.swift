//
//  CreateActionModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Foundation

enum CreateActionMenuItem: String, CaseIterable, Identifiable, Equatable {
    case startPush
    case addFriend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startPush:
            return "Start push"
        case .addFriend:
            return "Add friend"
        }
    }

    var subtitle: String {
        switch self {
        case .startPush:
            return "Send a social signal to your crew"
        case .addFriend:
            return "Invite someone to Push"
        }
    }

    var symbolName: String {
        switch self {
        case .startPush:
            return "bolt.fill"
        case .addFriend:
            return "person.badge.plus"
        }
    }

    var route: MainMapRoute {
        switch self {
        case .startPush:
            return .startPush
        case .addFriend:
            return .addFriend
        }
    }
}
