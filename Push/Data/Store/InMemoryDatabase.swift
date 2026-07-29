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
    /// Writable by store extensions in this module; callers outside treat as read-only.
    var groupsByID: [FriendGroup.ID: FriendGroup]
    var memberships: [GroupMembership]
    private(set) var placesByID: [Place.ID: Place]
    private(set) var statusesByPersonID: [Person.ID: PresenceStatus]
    private(set) var policies: [SharingPolicy]

    /// Upserts the current user's global_default policy (mock mirror of
    /// `set_global_sharing_defaults`).
    func setGlobalSharingDefaults(
        location: SharingPolicy.LocationVisibility,
        activity: SharingPolicy.DetailVisibility,
        availability: SharingPolicy.AvailabilityVisibility
    ) {
        let owner = currentUserID
        if let index = policies.firstIndex(where: {
            $0.ownerPersonID == owner && $0.audienceType == .globalDefault
        }) {
            let existing = policies[index]
            policies[index] = SharingPolicy(
                id: existing.id,
                ownerPersonID: owner,
                audienceType: .globalDefault,
                audienceID: nil,
                locationVisibility: location,
                activityVisibility: activity,
                availabilityVisibility: availability,
                expiresAt: existing.expiresAt
            )
        } else {
            policies.append(
                SharingPolicy(
                    id: "policy-global-\(owner)",
                    ownerPersonID: owner,
                    audienceType: .globalDefault,
                    audienceID: nil,
                    locationVisibility: location,
                    activityVisibility: activity,
                    availabilityVisibility: availability,
                    expiresAt: nil
                )
            )
        }
        didMutate()
    }
    var plansByID: [PushPlan.ID: PushPlan]
    private(set) var responses: [PushResponse]
    private(set) var hangouts: [PastHangout]
    private(set) var feedEvents: [FeedEvent]
    private(set) var friendRequests: [FriendRequest]
    private(set) var acceptedFriendIDs: Set<Person.ID>
    private(set) var profile: UserProfile
    /// Directed block rows (blocker → blocked). Soft-hide only — no hard delete of history.
    private(set) var userBlocks: [UserBlock]

    /// Moment tables (mock mirror of 0021). Writable by `+Moments`; soft-deleted
    /// rows are retained so Push slots stay consumed.
    var momentsByID: [Moment.ID: Moment]
    var momentMembers: [MomentMember]
    var momentMedia: [MomentMedia]

    /// Seed order matters for deterministic UI (avatar stacks, card order).
    private(set) var orderedPeople: [Person]
    var orderedGroups: [FriendGroup]
    var orderedPlans: [PushPlan]

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
        friendRequests = seed.friendRequests
        acceptedFriendIDs = seed.acceptedFriendIDs
        profile = seed.profile
        userBlocks = []
        momentsByID = Dictionary(uniqueKeysWithValues: seed.moments.map { ($0.id, $0) })
        momentMembers = seed.momentMembers
        momentMedia = seed.momentMedia
    }

    /// Internal so lifecycle extensions in sibling files can notify once per write.
    func didMutate() {
        revision += 1
    }

    func resolveFriendRequest(id: FriendRequest.ID, status: FriendRequest.Status) {
        guard let index = friendRequests.firstIndex(where: { $0.id == id }) else { return }
        let request = friendRequests[index]
        friendRequests[index] = FriendRequest(
            id: request.id,
            requester: request.requester,
            recipientID: request.recipientID,
            createdAt: request.createdAt,
            status: status,
            isUnread: false,
            mutualFriendCount: request.mutualFriendCount
        )
        if status == .accepted {
            acceptedFriendIDs.insert(request.requester.id)
            if peopleByID[request.requester.id] == nil {
                peopleByID[request.requester.id] = request.requester
                orderedPeople.append(request.requester)
            }
        }
        didMutate()
    }

    /// Sends an outgoing pending request. Guards self, existing friends, block
    /// pairs, and any pending row in either direction between the pair.
    @discardableResult
    func sendFriendRequest(to personID: Person.ID) -> FriendRequest? {
        guard personID != currentUserID else { return nil }
        guard let person = peopleByID[personID] else { return nil }
        guard !acceptedFriendIDs.contains(personID) else { return nil }
        guard !isBlocked(currentUserID, personID) else { return nil }

        if let existing = friendRequests.first(where: {
            $0.status == .pending && involvesPair(personID, request: $0)
        }) {
            return existing
        }

        // Re-open a previously denied pair as a new outgoing pending request.
        if let deniedIndex = friendRequests.firstIndex(where: {
            $0.status == .denied && involvesPair(personID, request: $0)
        }) {
            let denied = friendRequests[deniedIndex]
            let reopened = FriendRequest(
                id: denied.id,
                requester: peopleByID[currentUserID] ?? Person(id: currentUserID, firstName: "me", imageAssetPath: nil),
                recipientID: personID,
                createdAt: Date(),
                status: .pending,
                isUnread: true,
                mutualFriendCount: 0
            )
            friendRequests[deniedIndex] = reopened
            didMutate()
            return reopened
        }

        let me = peopleByID[currentUserID]
            ?? Person(id: currentUserID, firstName: "me", imageAssetPath: nil)
        let request = FriendRequest(
            id: "request-\(UUID().uuidString)",
            requester: me,
            recipientID: personID,
            createdAt: Date(),
            status: .pending,
            isUnread: true,
            mutualFriendCount: 0
        )
        // Keep person in the directory so the recipient can resolve them later.
        _ = person
        friendRequests.append(request)
        didMutate()
        return request
    }

    /// Cancels an outgoing pending request the current user started.
    func cancelFriendRequest(id: FriendRequest.ID) {
        guard let index = friendRequests.firstIndex(where: {
            $0.id == id
                && $0.status == .pending
                && $0.requester.id == currentUserID
        }) else { return }
        friendRequests.remove(at: index)
        didMutate()
    }

    /// Hard-deletes the friendship edge; removes any stale request row too so a
    /// fresh `sendFriendRequest` between the pair inserts cleanly afterward.
    func removeFriend(_ personID: Person.ID) {
        let hadFriend = acceptedFriendIDs.remove(personID) != nil
        let pendingCount = friendRequests.count
        friendRequests.removeAll { involvesPair(personID, request: $0) }
        guard hadFriend || friendRequests.count != pendingCount else { return }
        didMutate()
    }

    /// True if either direction of a block exists between `a` and `b`.
    func isBlocked(_ a: Person.ID, _ b: Person.ID) -> Bool {
        userBlocks.contains {
            ($0.blockerID == a && $0.blockedID == b) || ($0.blockerID == b && $0.blockedID == a)
        }
    }

    /// Outbound block from current user: tears down friendship + pending requests.
    /// Shared group membership and historical pushes are preserved (soft-hide).
    func blockUser(_ personID: Person.ID) {
        guard personID != currentUserID else { return }
        if !userBlocks.contains(where: {
            $0.blockerID == currentUserID && $0.blockedID == personID
        }) {
            userBlocks.append(UserBlock(blockerID: currentUserID, blockedID: personID))
        }
        acceptedFriendIDs.remove(personID)
        friendRequests.removeAll { involvesPair(personID, request: $0) }
        didMutate()
    }

    /// Removes only the current user's outbound block; friendship stays gone.
    func unblockUser(_ personID: Person.ID) {
        userBlocks.removeAll {
            $0.blockerID == currentUserID && $0.blockedID == personID
        }
        didMutate()
    }

    /// People the current user blocked, with public identity fields.
    func blockedPeople() -> [BlockedPerson] {
        userBlocks
            .filter { $0.blockerID == currentUserID }
            .compactMap { block -> BlockedPerson? in
                guard let person = peopleByID[block.blockedID] else { return nil }
                return BlockedPerson(
                    id: person.id,
                    firstName: person.firstName,
                    handle: handle(for: person.id),
                    imageAssetPath: person.imageAssetPath
                )
            }
    }

    /// Creates a group: caller becomes its active owner, each invitee gets a
    /// pending (`invited`) membership row rather than an immediate one.
    /// Blocked invitees are skipped (mirrors server `private.is_blocked` guard).
    @discardableResult
    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [Person.ID]) -> FriendGroup.ID {
        let groupID = "group-\(UUID().uuidString)"
        let group = FriendGroup(id: groupID, name: name, imageAssetPath: imageAssetPath)
        groupsByID[groupID] = group
        orderedGroups.append(group)

        let now = Date()
        let ownerMembership = GroupMembership(
            id: "membership-\(groupID)-\(currentUserID)",
            personID: currentUserID, groupID: groupID,
            role: .owner, sharingLevel: .full, membershipStatus: .active, joinedAt: now
        )
        let allowedInvitees = inviteeIDs.filter { !isBlocked(currentUserID, $0) }
        let inviteeMemberships = allowedInvitees.map { personID in
            GroupMembership(
                id: "membership-\(groupID)-\(personID)",
                personID: personID, groupID: groupID,
                role: .member, sharingLevel: .full, membershipStatus: .invited, joinedAt: now
            )
        }
        memberships.append(contentsOf: [ownerMembership] + inviteeMemberships)
        didMutate()
        return groupID
    }

    /// Enriches the caller's pending group invites with group + inviter (owner)
    /// identity, mirroring what the `incoming_group_invites()` RPC hands the
    /// live client — the invitee has no other read path to this data.
    func pendingGroupInvites(for personID: Person.ID) -> [GroupInvite] {
        memberships
            .filter { $0.personID == personID && $0.membershipStatus == .invited }
            .compactMap { membership -> GroupInvite? in
                guard let group = groupsByID[membership.groupID] else { return nil }
                let owner = memberships.first {
                    $0.groupID == membership.groupID && $0.role == .owner && $0.membershipStatus == .active
                }
                let inviter = owner.flatMap { peopleByID[$0.personID] }
                let memberCount = memberships.filter {
                    $0.groupID == membership.groupID && $0.membershipStatus == .active
                }.count
                return GroupInvite(
                    id: membership.id,
                    groupID: group.id,
                    groupName: group.name,
                    imageAssetPath: group.imageAssetPath,
                    inviterID: inviter?.id ?? "",
                    inviterName: inviter?.displayName ?? "",
                    inviterImageAssetPath: inviter?.imageAssetPath,
                    memberCount: memberCount,
                    createdAt: membership.joinedAt
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Accept flips the membership to active; deny hard-deletes the row so a
    /// future re-invite for the same pair inserts cleanly, mirroring the
    /// Supabase RPC's behavior.
    func resolveGroupInvite(id: GroupMembership.ID, accept: Bool) {
        guard let index = memberships.firstIndex(where: { $0.id == id }) else { return }
        if accept {
            let existing = memberships[index]
            memberships[index] = GroupMembership(
                id: existing.id, personID: existing.personID, groupID: existing.groupID,
                role: existing.role, sharingLevel: existing.sharingLevel,
                membershipStatus: .active, joinedAt: existing.joinedAt
            )
        } else {
            memberships.remove(at: index)
        }
        didMutate()
    }

    private func involvesPair(_ personID: Person.ID, request: FriendRequest) -> Bool {
        let a = request.requester.id
        let b = request.recipientID
        return (a == currentUserID && b == personID) || (a == personID && b == currentUserID)
    }

    func relation(to personID: Person.ID) -> FriendshipRelation {
        if personID == currentUserID { return .friends }
        if acceptedFriendIDs.contains(personID) { return .friends }
        if let pending = friendRequests.first(where: { $0.status == .pending && involvesPair(personID, request: $0) }) {
            if pending.requester.id == currentUserID {
                return .outgoingPending(requestID: pending.id)
            }
            return .incomingPending(requestID: pending.id)
        }
        return .none
    }

    /// Mock handles mirror the seed slug/display name lowercased.
    func handle(for personID: Person.ID) -> String {
        if personID == currentUserID { return profile.handle }
        return (peopleByID[personID]?.firstName ?? personID).lowercased()
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
        replacePerson(Person(
            id: existing.id, firstName: firstName, imageAssetPath: existing.imageAssetPath
        ))
    }

    /// Updates only the profile image path (bundle asset, local file, or remote URL).
    func updatePersonImage(id: Person.ID, imageAssetPath: String?) {
        guard let existing = peopleByID[id] else { return }
        replacePerson(Person(
            id: existing.id, firstName: existing.firstName, imageAssetPath: imageAssetPath
        ))
    }

    private func replacePerson(_ updated: Person) {
        peopleByID[updated.id] = updated
        if let index = orderedPeople.firstIndex(where: { $0.id == updated.id }) {
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
    /// Does **not** change `isPublished` (Ghost is orthogonal — Issue #76).
    func setAvailability(_ availability: FriendAvailabilityState) {
        // Social availability only — never treat `.ghost` as a publish flag here.
        let social = availability == .ghost ? profile.chosenAvailability : availability
        let resolved = social == .ghost ? FriendAvailabilityState.maybeDown : social
        if let status = statusesByPersonID[currentUserID] {
            statusesByPersonID[currentUserID] = PresenceStatus(
                id: status.id, personID: status.personID, availability: resolved,
                activity: status.activity, placeID: status.placeID,
                statusNote: status.statusNote, confidence: status.confidence,
                observedAt: status.observedAt, updatedAt: Date(),
                expiresAt: status.expiresAt, source: .manualOverride,
                isPublished: status.isPublished
            )
        }
        profile = UserProfile(
            personID: profile.personID, handle: profile.handle,
            chosenAvailability: resolved, visibilityNote: profile.visibilityNote,
            availabilityOptions: profile.availabilityOptions,
            activityVisibility: profile.activityVisibility,
            mapPreferences: profile.mapPreferences,
            closeFriends: profile.closeFriends, connectors: profile.connectors
        )
        didMutate()
    }

    /// Mock presence upsert from `LocalPresenceSync` (location / heartbeat / republish).
    /// One revision; mirrors draft availability; sets hard-expire window.
    func upsertOwnPresence(_ draft: PresenceStatusDraft, at now: Date = Date()) {
        let existing = statusesByPersonID[currentUserID]
        let personID = currentUserID
        let placeID = draft.placeID ?? existing?.placeID
        // Keep synthetic place coords when a place row exists; location drafts
        // primarily drive publish flag + freshness for mock friend visibility.
        statusesByPersonID[personID] = PresenceStatus(
            id: existing?.id ?? "presence-\(personID)",
            personID: personID,
            availability: draft.availability == .ghost ? .maybeDown : draft.availability,
            activity: draft.activity,
            placeID: placeID,
            statusNote: draft.statusNote ?? existing?.statusNote,
            confidence: draft.confidence,
            observedAt: draft.observedAt,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(PresenceFreshness.hardExpire),
            source: draft.source,
            isPublished: draft.isPublished
        )
        didMutate()
    }

    /// Orthogonal Ghost / privacy unpublish — clears friend-visible publish flag.
    /// Preserves social availability (Busy + Ghost stays Busy).
    func unpublishOwnPresence(at now: Date = Date()) {
        guard let status = statusesByPersonID[currentUserID] else {
            didMutate()
            return
        }
        statusesByPersonID[currentUserID] = PresenceStatus(
            id: status.id,
            personID: status.personID,
            availability: status.availability == .ghost ? .maybeDown : status.availability,
            activity: status.activity,
            placeID: status.placeID,
            statusNote: status.statusNote,
            confidence: status.confidence,
            observedAt: status.observedAt,
            updatedAt: now,
            expiresAt: now,
            source: status.source,
            isPublished: false
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
