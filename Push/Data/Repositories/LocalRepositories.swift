//
//  LocalRepositories.swift
//  Push
//
//  In-memory implementations. They never throw; failure modes arrive with a
//  real backend and flow through the same protocol seam.
//

import Foundation

@MainActor
final class LocalAlertRepository: AlertRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func incomingFriendRequests() async throws -> [FriendRequest] {
        database.friendRequests.filter {
            $0.status == .pending && $0.recipientID == database.currentUserID
        }
    }

    func acceptFriendRequest(id: FriendRequest.ID) async throws {
        database.resolveFriendRequest(id: id, status: .accepted)
    }

    func denyFriendRequest(id: FriendRequest.ID) async throws {
        database.resolveFriendRequest(id: id, status: .denied)
    }

    func incomingGroupInvites() async throws -> [GroupInvite] {
        database.pendingGroupInvites(for: database.currentUserID)
    }

    func acceptGroupInvite(id: GroupInvite.ID) async throws {
        database.resolveGroupInvite(id: id, accept: true)
    }

    func denyGroupInvite(id: GroupInvite.ID) async throws {
        database.resolveGroupInvite(id: id, accept: false)
    }
}

@MainActor
final class LocalFriendRepository: FriendRepository {
    private let database: InMemoryDatabase

    init(database: InMemoryDatabase) {
        self.database = database
    }

    func friends() async throws -> [Person] {
        database.orderedPeople.filter { database.acceptedFriendIDs.contains($0.id) }
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

    func searchPeople(query: String) async throws -> [PersonSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return database.orderedPeople
            .filter { $0.id != database.currentUserID }
            .compactMap { person -> PersonSearchResult? in
                let handle = database.handle(for: person.id)
                let haystack = "\(person.firstName) \(person.displayName) \(handle)".lowercased()
                guard haystack.contains(trimmed) else { return nil }
                return PersonSearchResult(
                    person: person,
                    handle: handle,
                    relation: database.relation(to: person.id)
                )
            }
    }

    @discardableResult
    func sendFriendRequest(to personID: Person.ID) async throws -> FriendRequest.ID {
        guard let request = database.sendFriendRequest(to: personID) else {
            // Already friends / self / unknown: still return any active pending id.
            if case .outgoingPending(let id) = database.relation(to: personID) { return id }
            if case .incomingPending(let id) = database.relation(to: personID) { return id }
            return ""
        }
        return request.id
    }

    func cancelFriendRequest(id: FriendRequest.ID) async throws {
        database.cancelFriendRequest(id: id)
    }

    func removeFriend(_ personID: Person.ID) async throws {
        database.removeFriend(personID)
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

    func createGroup(
        name: String, imageAssetPath: String?, inviteeIDs: [Person.ID]
    ) async throws -> FriendGroup.ID {
        database.createGroup(name: name, imageAssetPath: imageAssetPath, inviteeIDs: inviteeIDs)
    }

    func renameGroup(groupID: FriendGroup.ID, name: String) async throws {
        try database.renameGroup(groupID: groupID, name: name)
    }

    func updateGroupPhoto(groupID: FriendGroup.ID, jpegData: Data) async throws {
        let previous = database.groupsByID[groupID]?.imageAssetPath
        let url = try GroupPhotoFileStore.save(groupID: groupID, jpegData: jpegData)
        try database.setGroupImagePath(groupID: groupID, imageAssetPath: url.path)
        AvatarImageLoader.invalidate(path: previous)
        AvatarImageLoader.invalidate(path: url.path)
    }

    func removeGroupPhoto(groupID: FriendGroup.ID) async throws {
        let previous = database.groupsByID[groupID]?.imageAssetPath
        try database.setGroupImagePath(groupID: groupID, imageAssetPath: nil)
        GroupPhotoFileStore.remove(groupID: groupID)
        AvatarImageLoader.invalidate(path: previous)
    }

    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) async throws {
        try database.inviteToGroup(groupID: groupID, inviteeIDs: inviteeIDs)
    }

    func cancelGroupInvite(membershipID: GroupMembership.ID) async throws {
        try database.cancelGroupInvite(membershipID: membershipID)
    }

    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) async throws {
        try database.removeMember(groupID: groupID, personID: personID)
    }

    func leaveGroup(groupID: FriendGroup.ID) async throws {
        let previousPath = database.groupsByID[groupID]?.imageAssetPath
        try database.leaveGroup(groupID: groupID)
        // Sole-owner leave purges the group — clean mock photo file like delete.
        if database.groupsByID[groupID] == nil {
            GroupPhotoFileStore.remove(groupID: groupID)
            AvatarImageLoader.invalidate(path: previousPath)
        }
    }

    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) async throws {
        try database.transferOwnership(groupID: groupID, newOwnerID: newOwnerID)
    }

    func deleteGroup(groupID: FriendGroup.ID) async throws {
        let previousPath = database.groupsByID[groupID]?.imageAssetPath
        try database.deleteGroup(groupID: groupID)
        GroupPhotoFileStore.remove(groupID: groupID)
        AvatarImageLoader.invalidate(path: previousPath)
    }
}

@MainActor
final class LocalPushRepository: PushRepository {
    private let database: InMemoryDatabase
    /// Injectable for frozen-date tests; production always uses wall clock.
    private let clock: () -> Date

    init(database: InMemoryDatabase, clock: @escaping () -> Date = { Date() }) {
        self.database = database
        self.clock = clock
    }

    func activePlans() async throws -> [PushPlan] {
        let now = clock()
        return database.orderedPlans
            .compactMap { database.plansByID[$0.id] }
            .filter { PushLifecycle.isActive($0, now: now) }
    }

    func historicalPlans(forMonthContaining date: Date) async throws -> [PushPlan] {
        let now = clock()
        let calendar = Calendar.current
        return database.orderedPlans
            .compactMap { database.plansByID[$0.id] }
            .filter { PushLifecycle.isHistorical($0, now: now) }
            .filter { calendar.isDate($0.startsAt, equalTo: date, toGranularity: .month) }
    }

    func responses() async throws -> [PushResponse] {
        database.responses
    }

    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        database.setResponse(
            pushID: planID,
            personID: database.currentUserID,
            response: response,
            at: clock()
        )
    }

    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout] {
        let calendar = Calendar.current
        let now = clock()
        let plans = database.orderedPlans.compactMap { database.plansByID[$0.id] }
        let derived = PastHangoutBuilder.hangouts(
            plans: plans,
            responses: database.responses,
            monthContaining: date,
            now: now,
            calendar: calendar
        )
        // Seed hangouts keep mock calendar richness; live never sees these rows.
        let seed = database.hangouts.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
        // Prefer seed hangouts when both share an id (tests freeze a rich calendar).
        let seedIDs = Set(seed.map(\.id))
        let derivedOnly = derived.filter { !seedIDs.contains($0.id) }
        return (derivedOnly + seed).sorted { $0.date < $1.date }
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

    func updateProfilePhoto(jpegData: Data) async throws {
        let previous = database.peopleByID[database.currentUserID]?.imageAssetPath
        let url = try ProfilePhotoFileStore.save(
            userID: database.currentUserID, jpegData: jpegData
        )
        database.updatePersonImage(id: database.currentUserID, imageAssetPath: url.path)
        AvatarImageLoader.invalidate(path: previous)
        AvatarImageLoader.invalidate(path: url.path)
    }

    func removeProfilePhoto() async throws {
        let previous = database.peopleByID[database.currentUserID]?.imageAssetPath
        database.updatePersonImage(id: database.currentUserID, imageAssetPath: nil)
        ProfilePhotoFileStore.remove(userID: database.currentUserID)
        AvatarImageLoader.invalidate(path: previous)
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
