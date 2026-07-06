//
//  FriendGroup.swift
//  Push
//

import Foundation

/// Canonical friend group. Member lists and counts derive from
/// `GroupMembership` rows — never stored here.
struct FriendGroup: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let imageAssetPath: String?

    var initials: String {
        name.split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
