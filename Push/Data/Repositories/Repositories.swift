//
//  Repositories.swift
//  Push
//
//  The seam between UI and data. All methods are async throws even though
//  the local implementations never fail — a Supabase implementation of
//  these protocols is a drop-in swap; view models and views stay untouched.
//

import Foundation

protocol FriendRepository {
    /// All friends in seed order, excluding the current user.
    func friends() async throws -> [Person]
    func currentUser() async throws -> Person
    /// Canonical internal presence — consumed by builders only, never by UI.
    func presenceStatuses() async throws -> [PresenceStatus]
}

protocol GroupRepository {
    func groups() async throws -> [FriendGroup]
    func memberships() async throws -> [GroupMembership]
}

/// Start Push flow output. `recipientIDs` are the flow's tokens
/// ("group_<id>" / "friend_<id>").
struct PushDraft {
    let title: String
    let recipientIDs: Set<String>
    let startsAt: Date
    let locationText: String
    let notes: String
    let creatorID: Person.ID
}

protocol PushRepository {
    /// Non-cancelled plans in seed order.
    func activePlans() async throws -> [PushPlan]
    func responses() async throws -> [PushResponse]
    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws
    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout]
    func allPlaces() async throws -> [Place]
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID
}

protocol ProfileRepository {
    func userProfile() async throws -> UserProfile
}

protocol SharingRepository {
    func allPolicies() async throws -> [SharingPolicy]
}

protocol FeedRepository {
    func events() async throws -> [FeedEvent]
}
