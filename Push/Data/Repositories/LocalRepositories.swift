//
//  LocalRepositories.swift
//  Push
//
//  In-memory implementations. They never throw; failure modes arrive with a
//  real backend and flow through the same protocol seam.
//

import Foundation

@MainActor
final class LocalFriendRepository: FriendRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func friends() async throws -> [Person] {
        database.orderedPeople.filter { $0.id != database.currentUserID }
    }

    func currentUser() async throws -> Person {
        // Seed integrity tests guarantee the current user exists.
        database.peopleByID[database.currentUserID] ?? database.orderedPeople[0]
    }

    func presenceStatuses() async throws -> [PresenceStatus] {
        database.orderedPeople.compactMap { database.statusesByPersonID[$0.id] }
    }
}

@MainActor
final class LocalGroupRepository: GroupRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func groups() async throws -> [FriendGroup] {
        database.orderedGroups
    }

    func memberships() async throws -> [GroupMembership] {
        database.memberships
    }
}

@MainActor
final class LocalPushRepository: PushRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func activePlans() async throws -> [PushPlan] {
        database.orderedPlans.compactMap { database.plansByID[$0.id] }.filter { $0.cancelledAt == nil }
    }

    func responses() async throws -> [PushResponse] {
        database.responses
    }

    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        database.setResponse(
            pushID: planID,
            personID: database.currentUserID,
            response: response,
            at: Date()
        )
    }

    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout] {
        let calendar = Calendar.current
        return database.hangouts.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
    }

    func allPlaces() async throws -> [Place] {
        Array(database.placesByID.values)
    }

    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID {
        let groupIDs = draft.recipientIDs.compactMap { token in
            token.hasPrefix("group_") ? String(token.dropFirst("group_".count)) : nil
        }
        let friendIDs = draft.recipientIDs.compactMap { token in
            token.hasPrefix("friend_") ? String(token.dropFirst("friend_".count)) : nil
        }
        let singleGroupOnly = groupIDs.count == 1 && friendIDs.isEmpty
        let planID = "push-\(UUID().uuidString)"
        let now = Date()

        // Invitees: selected friends plus members of any selected groups,
        // deduped, with the creator excluded (they get an explicit .in below).
        let groupMemberIDs = database.memberships
            .filter { $0.membershipStatus == .active && groupIDs.contains($0.groupID) }
            .map(\.personID)
        var invitees = Set(friendIDs).union(groupMemberIDs)
        invitees.remove(draft.creatorID)

        let plan = PushPlan(
            id: planID,
            title: draft.title,
            groupID: singleGroupOnly ? groupIDs[0] : nil,
            creatorID: draft.creatorID,
            createdAt: now,
            updatedAt: now,
            startsAt: draft.startsAt,
            hasExplicitTime: true,
            isApproximateTime: false,
            expiresAt: draft.startsAt.addingTimeInterval(CreatePushConstants.expiryWindow),
            cancelledAt: nil,
            placeID: nil,
            placeIsSuggested: false,
            state: .collecting,
            audience: singleGroupOnly ? .group : .inviteesOnly,
            note: draft.notes.isEmpty ? nil : draft.notes,
            locationText: draft.locationText.isEmpty ? nil : draft.locationText
        )

        let creatorResponse = PushResponse(
            id: "\(planID)-\(draft.creatorID)", pushID: planID,
            personID: draft.creatorID, response: .in,
            respondedAt: now, readyState: .unknown
        )
        let inviteeResponses = invitees.map { personID in
            PushResponse(
                id: "\(planID)-\(personID)", pushID: planID,
                personID: personID, response: .pending,
                respondedAt: nil, readyState: .unknown
            )
        }
        database.createPush(plan: plan, responses: [creatorResponse] + inviteeResponses)
        return planID
    }
}

@MainActor
final class LocalProfileRepository: ProfileRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func userProfile() async throws -> UserProfile {
        database.profile
    }
}

@MainActor
final class LocalSharingRepository: SharingRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func allPolicies() async throws -> [SharingPolicy] {
        database.policies
    }
}

@MainActor
final class LocalFeedRepository: FeedRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func events() async throws -> [FeedEvent] {
        database.feedEvents
    }
}

private enum CreatePushConstants {
    /// Pushes expire six hours after their start, matching seed plans.
    static let expiryWindow: TimeInterval = 6 * 60 * 60
}
