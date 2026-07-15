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

    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        database.setAvailability(availability)
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
        let parsed = PushRecipientResolver.parse(draft.recipientIDs)
        let planID = "push-\(UUID().uuidString)"
        let now = Date()

        let invitees = PushRecipientResolver.invitees(
            groupIDs: parsed.groupIDs, friendIDs: parsed.friendIDs,
            memberships: database.memberships, creatorID: draft.creatorID
        )

        let plan = makePlan(
            planID: planID, draft: draft,
            singleGroupOnly: parsed.singleGroupOnly, groupIDs: parsed.groupIDs, now: now
        )
        let responses = makeResponses(planID: planID, draft: draft, invitees: invitees, now: now)
        database.createPush(plan: plan, responses: responses)
        return planID
    }

    func updatePush(planID: PushPlan.ID, with draft: PushDraft) async throws {
        guard let existing = database.plansByID[planID] else { return }
        let parsed = PushRecipientResolver.parse(draft.recipientIDs)
        let invitees = PushRecipientResolver.invitees(
            groupIDs: parsed.groupIDs, friendIDs: parsed.friendIDs,
            memberships: database.memberships, creatorID: existing.creatorID
        )
        let plan = updatedPlan(
            existing: existing, draft: draft, singleGroupOnly: parsed.singleGroupOnly,
            groupIDs: parsed.groupIDs, now: Date()
        )
        let responses = updatedResponses(
            planID: planID, creatorID: existing.creatorID, invitees: invitees
        )
        database.updatePush(plan: plan, responses: responses)
    }

    func cancelPush(planID: PushPlan.ID) async throws {
        database.cancelPush(planID: planID, at: Date())
    }

    func deletePush(planID: PushPlan.ID) async throws {
        database.deletePush(planID: planID)
    }

    private func makePlan(
        planID: String, draft: PushDraft,
        singleGroupOnly: Bool, groupIDs: [String], now: Date
    ) -> PushPlan {
        PushPlan(
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
    }

    private func makeResponses(
        planID: String, draft: PushDraft,
        invitees: Set<String>, now: Date
    ) -> [PushResponse] {
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
        return [creatorResponse] + inviteeResponses
    }

    private func updatedPlan(
        existing: PushPlan, draft: PushDraft,
        singleGroupOnly: Bool, groupIDs: [String], now: Date
    ) -> PushPlan {
        PushPlan(
            id: existing.id,
            title: draft.title,
            groupID: singleGroupOnly ? groupIDs[0] : nil,
            creatorID: existing.creatorID,
            createdAt: existing.createdAt,
            updatedAt: now,
            startsAt: draft.startsAt,
            hasExplicitTime: existing.hasExplicitTime,
            isApproximateTime: existing.isApproximateTime,
            expiresAt: draft.startsAt.addingTimeInterval(CreatePushConstants.expiryWindow),
            cancelledAt: existing.cancelledAt,
            placeID: nil,
            placeIsSuggested: false,
            state: existing.state,
            audience: singleGroupOnly ? .group : .inviteesOnly,
            note: draft.notes.isEmpty ? nil : draft.notes,
            locationText: draft.locationText.isEmpty ? nil : draft.locationText
        )
    }

    private func updatedResponses(
        planID: PushPlan.ID,
        creatorID: Person.ID,
        invitees: Set<Person.ID>
    ) -> [PushResponse] {
        let existing = Dictionary(
            uniqueKeysWithValues: database.responses
                .filter { $0.pushID == planID }
                .map { ($0.personID, $0) }
        )
        let creator = existing[creatorID] ?? PushResponse(
            id: "\(planID)-\(creatorID)", pushID: planID,
            personID: creatorID, response: .in,
            respondedAt: Date(), readyState: .unknown
        )
        let inviteeRows = invitees.map { personID in
            existing[personID] ?? PushResponse(
                id: "\(planID)-\(personID)", pushID: planID,
                personID: personID, response: .pending,
                respondedAt: nil, readyState: .unknown
            )
        }
        return [creator] + inviteeRows
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

    func updateBasics(displayName: String, handle: String) async throws {
        // updatePerson targets firstName; displayName and initials derive automatically.
        database.updatePerson(id: database.currentUserID, firstName: displayName)
        database.updateProfile(
            handle: handle,
            activityVisibility: database.profile.activityVisibility,
            mapPreferences: database.profile.mapPreferences,
            closeFriends: database.profile.closeFriends
        )
    }

    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws {
        database.updateProfile(
            handle: database.profile.handle,
            activityVisibility: activityVisibility,
            mapPreferences: mapPreferences,
            closeFriends: closeFriends
        )
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
