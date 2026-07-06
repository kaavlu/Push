//
//  PushPlan.swift
//  Push
//

import Foundation

/// Canonical coordination object. User-facing copy calls these "Pushes".
struct PushPlan: Identifiable, Codable, Equatable {
    enum State: String, Codable { case collecting, locked, happening }
    enum Audience: String, Codable { case group, inviteesOnly }

    let id: String
    let title: String
    let groupID: FriendGroup.ID
    let creatorID: Person.ID
    let createdAt: Date
    let updatedAt: Date
    let startsAt: Date
    /// false → timing renders as day only ("Saturday").
    let hasExplicitTime: Bool
    /// true → timing renders with "~" prefix.
    let isApproximateTime: Bool
    let expiresAt: Date
    let cancelledAt: Date?
    let placeID: Place.ID
    /// true → location renders as "Suggested: {place}".
    let placeIsSuggested: Bool
    let state: State
    let audience: Audience
}
