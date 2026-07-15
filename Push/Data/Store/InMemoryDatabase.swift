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

    /// Atomic: inserts the plan and all its initial responses together, then
    /// notifies once, so no observer can see a plan without its responses.
    func createPush(plan: PushPlan, responses newResponses: [PushResponse]) {
        plansByID[plan.id] = plan
        orderedPlans.append(plan)
        self.responses.append(contentsOf: newResponses)
        didMutate()
    }

    /// Atomic: updates the plan and replaces its response set together, then
    /// notifies once so observers never see mixed edit state.
    func updatePush(plan: PushPlan, responses newResponses: [PushResponse]) {
        guard plansByID[plan.id] != nil else { return }
        plansByID[plan.id] = plan
        if let index = orderedPlans.firstIndex(where: { $0.id == plan.id }) {
            orderedPlans[index] = plan
        }
        responses.removeAll { $0.pushID == plan.id }
        responses.append(contentsOf: newResponses)
        didMutate()
    }

    /// Updates only the firstName of a person, preserving all other fields. displayName
    /// and initials derive from firstName, so callers never pass them explicitly.
    func updatePerson(id: Person.ID, firstName: String) {
        guard let existing = peopleByID[id] else { return }
        let updated = Person(
            id: existing.id, firstName: firstName, imageAssetPath: existing.imageAssetPath
        )
        peopleByID[id] = updated
        if let index = orderedPeople.firstIndex(where: { $0.id == id }) {
            orderedPeople[index] = updated
        }
        didMutate()
    }

    /// Rewrites the privacy/settings fields of the current user's profile.
    /// Call this for handle, activityVisibility, mapPreferences, or closeFriends
    /// changes; pass the unchanged fields through from `profile` to avoid wiping them.
    func updateProfile(
        handle: String,
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) {
        profile = UserProfile(
            personID: profile.personID, handle: handle,
            chosenAvailability: profile.chosenAvailability,
            visibilityNote: profile.visibilityNote,
            availabilityOptions: profile.availabilityOptions,
            activityVisibility: activityVisibility,
            mapPreferences: mapPreferences,
            closeFriends: closeFriends,
            connectors: profile.connectors
        )
        didMutate()
    }

    /// Writes the user's chosen availability to both their PresenceStatus (with
    /// source .manualOverride) and their UserProfile.chosenAvailability so both
    /// the map layer and profile screen read from the same source of truth.
    func setAvailability(_ availability: FriendAvailabilityState) {
        if let status = statusesByPersonID[currentUserID] {
            statusesByPersonID[currentUserID] = PresenceStatus(
                id: status.id, personID: status.personID, availability: availability,
                activity: status.activity, placeID: status.placeID,
                statusNote: status.statusNote, confidence: status.confidence,
                observedAt: status.observedAt, updatedAt: Date(),
                expiresAt: status.expiresAt, source: .manualOverride
            )
        }
        profile = UserProfile(
            personID: profile.personID, handle: profile.handle,
            chosenAvailability: availability, visibilityNote: profile.visibilityNote,
            availabilityOptions: profile.availabilityOptions,
            activityVisibility: profile.activityVisibility,
            mapPreferences: profile.mapPreferences,
            closeFriends: profile.closeFriends, connectors: profile.connectors
        )
        didMutate()
    }

    /// Soft-cancel: sets `cancelledAt` so `activePlans()` filters the push out,
    /// while leaving its row (and responses) intact for history/audit.
    func cancelPush(planID: PushPlan.ID, at date: Date) {
        guard let existing = plansByID[planID] else { return }
        let cancelled = PushPlan(
            id: existing.id, title: existing.title, groupID: existing.groupID,
            creatorID: existing.creatorID, createdAt: existing.createdAt, updatedAt: date,
            startsAt: existing.startsAt, hasExplicitTime: existing.hasExplicitTime,
            isApproximateTime: existing.isApproximateTime, expiresAt: existing.expiresAt,
            cancelledAt: date, placeID: existing.placeID, placeIsSuggested: existing.placeIsSuggested,
            state: existing.state, audience: existing.audience, note: existing.note,
            locationText: existing.locationText
        )
        plansByID[planID] = cancelled
        if let index = orderedPlans.firstIndex(where: { $0.id == planID }) {
            orderedPlans[index] = cancelled
        }
        didMutate()
    }

    /// Hard-delete: removes the push row and its responses entirely,
    /// mirroring the `on delete cascade` on `push_responses` in Supabase.
    func deletePush(planID: PushPlan.ID) {
        guard plansByID[planID] != nil else { return }
        plansByID[planID] = nil
        orderedPlans.removeAll { $0.id == planID }
        responses.removeAll { $0.pushID == planID }
        didMutate()
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
