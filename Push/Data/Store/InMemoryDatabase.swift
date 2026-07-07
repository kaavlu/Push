//
//  InMemoryDatabase.swift
//  Push
//
//  Normalized in-memory tables acting as the mock backend. Repositories are
//  the only consumers; view models never touch this directly.
//

import Combine
import Foundation

@MainActor
final class InMemoryDatabase: ObservableObject {
    let currentUserID: Person.ID

    /// Bumped once after every mutation so view models can reload. Emitted only
    /// after a write completes — never during reads — to avoid reload loops.
    @Published private(set) var revision: Int = 0

    private(set) var peopleByID: [Person.ID: Person]
    private(set) var groupsByID: [FriendGroup.ID: FriendGroup]
    private(set) var memberships: [GroupMembership]
    private(set) var placesByID: [Place.ID: Place]
    private(set) var statusesByPersonID: [Person.ID: PresenceStatus]
    private(set) var policies: [SharingPolicy]
    private(set) var plansByID: [PushPlan.ID: PushPlan]
    private(set) var responses: [PushResponse]
    private(set) var hangouts: [PastHangout]
    private(set) var feedEvents: [FeedEvent]
    private(set) var profile: UserProfile

    /// Seed order matters for deterministic UI (avatar stacks, card order).
    private(set) var orderedPeople: [Person]
    private(set) var orderedGroups: [FriendGroup]
    private(set) var orderedPlans: [PushPlan]

    init(seed: SeedData) {
        currentUserID = seed.currentUserID
        orderedPeople = seed.people
        orderedGroups = seed.groups
        orderedPlans = seed.plans
        peopleByID = Dictionary(uniqueKeysWithValues: seed.people.map { ($0.id, $0) })
        groupsByID = Dictionary(uniqueKeysWithValues: seed.groups.map { ($0.id, $0) })
        memberships = seed.memberships
        placesByID = Dictionary(uniqueKeysWithValues: seed.places.map { ($0.id, $0) })
        statusesByPersonID = Dictionary(uniqueKeysWithValues: seed.statuses.map { ($0.personID, $0) })
        policies = seed.policies
        plansByID = Dictionary(uniqueKeysWithValues: seed.plans.map { ($0.id, $0) })
        responses = seed.responses
        hangouts = seed.hangouts
        feedEvents = seed.feedEvents
        profile = seed.profile
    }

    private func didMutate() {
        revision += 1
    }

    func setResponse(
        pushID: PushPlan.ID,
        personID: Person.ID,
        response: PushResponse.Response,
        at date: Date
    ) {
        let row = PushResponse(
            id: "\(pushID)-\(personID)",
            pushID: pushID,
            personID: personID,
            response: response,
            respondedAt: response == .pending ? nil : date,
            readyState: .unknown
        )
        if let index = responses.firstIndex(where: { $0.pushID == pushID && $0.personID == personID }) {
            responses[index] = row
        } else {
            responses.append(row)
        }
        didMutate()
    }
}
