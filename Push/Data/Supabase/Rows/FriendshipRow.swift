//
//  FriendshipRow.swift
//  Push
//

import Foundation

/// PostgREST row for `friendships`. Snake_case matches table columns.
struct FriendshipRow: Decodable, Equatable {
    let id: String
    let user_low: String
    let user_high: String
    let status: String
    let requested_by: String?
    let created_at: String

    var isPending: Bool { status == "pending" }
    var isAccepted: Bool { status == "accepted" }

    func otherUserID(relativeTo userID: String) -> String? {
        if user_low.caseInsensitiveCompare(userID) == .orderedSame { return user_high }
        if user_high.caseInsensitiveCompare(userID) == .orderedSame { return user_low }
        return nil
    }

    func isRequester(_ userID: String) -> Bool {
        guard let requested_by else { return false }
        return requested_by.caseInsensitiveCompare(userID) == .orderedSame
    }

    func involves(_ userID: String) -> Bool {
        user_low.caseInsensitiveCompare(userID) == .orderedSame
            || user_high.caseInsensitiveCompare(userID) == .orderedSame
    }
}

/// Aggregate returned only for the caller's pending incoming requests.
/// It intentionally exposes a count, never the mutual friends' identities.
struct IncomingFriendRequestMutualCountRow: Decodable, Equatable {
    let request_id: String
    let mutual_friend_count: Int
}

/// Limited public fields returned by `search_profiles`.
struct SearchProfileRow: Decodable, Equatable {
    let id: String
    let first_name: String
    let handle: String
    let image_asset_path: String?

    func person() -> Person {
        Person(id: id, firstName: first_name, imageAssetPath: image_asset_path)
    }
}
