//
//  InMemoryDatabase+Moments.swift
//  Push
//
//  Mock Moment mutations mirroring the 0023 SECURITY DEFINER RPCs, so the
//  mock enforces the same rules the server does: one Moment per Push (even
//  soft-deleted), creator always tagged, max 8 active media, dense ordering
//  with cover at 0, activity bumps on create/append only, and last-media
//  deletion soft-deleting the Moment.
//
//  The acting user is always `currentUserID` — mock friendship is only known
//  relative to the signed-in seed user.
//

import Foundation

extension InMemoryDatabase {

    // MARK: - Graph context

    /// Viewer-scoped friendship/block answers used by `MomentAuthorization`.
    func momentGraphContext(viewerID: Person.ID) -> MomentGraphContext {
        MomentGraphContext(
            isFriend: { [weak self] personID in
                guard let self else { return false }
                guard viewerID == self.currentUserID else { return false }
                return self.acceptedFriendIDs.contains(personID)
            },
            isBlocked: { [weak self] personID in
                self?.isBlocked(viewerID, personID) ?? false
            }
        )
    }

    // MARK: - Row lookups

    func members(ofMoment momentID: Moment.ID) -> [MomentMember] {
        guard let moment = momentsByID[momentID] else { return [] }
        return MomentOrdering.sortedMembers(
            momentMembers.filter { $0.momentID == momentID },
            creatorID: moment.creatorID
        )
    }

    func media(ofMoment momentID: Moment.ID) -> [MomentMedia] {
        MomentOrdering.sortedMedia(momentMedia.filter { $0.momentID == momentID })
    }

    func activeMedia(ofMoment momentID: Moment.ID) -> [MomentMedia] {
        media(ofMoment: momentID).filter(\.isActive)
    }

    // MARK: - Create

    func createMoment(_ draft: MomentDraft, now: Date) throws -> Moment.ID {
        guard !draft.media.isEmpty else { throw MomentRepositoryError.mediaRequired }
        guard draft.media.count <= MomentLimits.maxActiveMedia else {
            throw MomentRepositoryError.mediaLimitExceeded
        }
        if let pushID = draft.pushID {
            try validatePushSlot(pushID)
        }

        let momentID = "moment-\(UUID().uuidString.lowercased())"
        let creatorID = currentUserID
        momentsByID[momentID] = Moment(
            id: momentID,
            creatorID: creatorID,
            title: truncated(draft.title),
            locationText: truncated(draft.locationText),
            placeID: nil,
            pushID: draft.pushID,
            publishedAt: now,
            lastActivityAt: now,
            deletedAt: nil
        )

        // Creator tag is implicit and first.
        appendMember(momentID: momentID, personID: creatorID, taggedAt: now)
        for personID in draft.taggedPersonIDs where personID != creatorID {
            try validateTagTarget(personID, momentID: momentID)
            guard !isTagged(personID, momentID: momentID) else { continue }
            appendMember(momentID: momentID, personID: personID, taggedAt: now)
        }

        for (index, item) in draft.media.enumerated() {
            momentMedia.append(
                makeMedia(item, momentID: momentID, uploaderID: creatorID, order: index, now: now)
            )
        }

        didMutate()
        return momentID
    }

    // MARK: - Append media

    /// Per-item like `append_moment_media`: earlier items stay committed when a
    /// later one hits the cap (contract §7.7 partial batch keeps successes).
    func appendMomentMedia(momentID: Moment.ID, items: [MomentMediaDraft], now: Date) throws {
        let moment = try activeMoment(momentID)
        guard isTagged(currentUserID, momentID: momentID) else {
            throw MomentRepositoryError.notAllowed
        }

        var appended = false
        defer { if appended { didMutate() } }

        for item in items {
            let active = activeMedia(ofMoment: momentID)
            guard active.count < MomentLimits.maxActiveMedia else {
                throw MomentRepositoryError.mediaLimitExceeded
            }
            let nextOrder = (active.map(\.sortOrder).max() ?? -1) + 1
            momentMedia.append(
                makeMedia(
                    item, momentID: momentID, uploaderID: currentUserID,
                    order: nextOrder, now: now
                )
            )
            bumpActivity(momentID: momentID, from: moment.lastActivityAt, now: now)
            appended = true
        }
    }

    // MARK: - Metadata

    func updateMomentMetadata(
        momentID: Moment.ID, title: String, locationText: String
    ) throws {
        let moment = try activeMoment(momentID)
        guard moment.creatorID == currentUserID else { throw MomentRepositoryError.notAllowed }

        var updated = moment
        updated.title = truncated(title)
        updated.locationText = truncated(locationText)
        // Metadata never bumps lastActivityAt (contract §7.2).
        momentsByID[momentID] = updated
        didMutate()
    }

    // MARK: - Tags

    func addMomentMembers(momentID: Moment.ID, personIDs: [Person.ID], now: Date) throws {
        let moment = try activeMoment(momentID)
        guard canEditMomentTags(momentID: momentID) else {
            throw MomentRepositoryError.notAllowed
        }

        var inserted = false
        for personID in personIDs where personID != currentUserID {
            // Re-adding the creator is allowed; anyone else must be a friend.
            if personID != moment.creatorID {
                try validateTagTarget(personID, momentID: momentID)
            }
            guard !isTagged(personID, momentID: momentID) else { continue }
            appendMember(momentID: momentID, personID: personID, taggedAt: now)
            inserted = true
        }
        if inserted { didMutate() }
    }

    func removeMomentMember(momentID: Moment.ID, personID: Person.ID) throws {
        let moment = try activeMoment(momentID)
        guard personID != moment.creatorID else {
            throw MomentRepositoryError.cannotRemoveCreator
        }

        if personID == currentUserID {
            guard isTagged(currentUserID, momentID: momentID) else {
                throw MomentRepositoryError.notAllowed
            }
        } else {
            guard canEditMomentTags(momentID: momentID) else {
                throw MomentRepositoryError.notAllowed
            }
        }

        // Uploaded media stays; only the tag row goes.
        momentMembers.removeAll { $0.momentID == momentID && $0.personID == personID }
        didMutate()
    }

    // MARK: - Reorder

    func reorderMomentMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) throws {
        _ = try activeMoment(momentID)
        guard canEditMomentTags(momentID: momentID) else {
            throw MomentRepositoryError.notAllowed
        }

        let active = activeMedia(ofMoment: momentID)
        let requested = Set(orderedMediaIDs)
        guard orderedMediaIDs.count == active.count,
              requested.count == orderedMediaIDs.count,
              requested == Set(active.map(\.id))
        else {
            throw MomentRepositoryError.conflict
        }

        for (index, mediaID) in orderedMediaIDs.enumerated() {
            guard let position = momentMedia.firstIndex(where: { $0.id == mediaID }) else { continue }
            momentMedia[position].sortOrder = index
        }
        didMutate()
    }

    // MARK: - Soft deletes

    func softDeleteMomentMedia(mediaID: MomentMedia.ID, now: Date) throws {
        guard let index = momentMedia.firstIndex(where: { $0.id == mediaID && $0.isActive }) else {
            throw MomentRepositoryError.notFound
        }
        let item = momentMedia[index]
        let moment = try activeMoment(item.momentID)
        guard item.uploaderID == currentUserID || moment.creatorID == currentUserID else {
            throw MomentRepositoryError.notAllowed
        }

        momentMedia[index].deletedAt = now
        renumberMomentMedia(momentID: item.momentID)

        // Last active item takes the Moment with it (contract §4.2).
        if activeMedia(ofMoment: item.momentID).isEmpty {
            momentsByID[item.momentID]?.deletedAt = now
        }
        didMutate()
    }

    func softDeleteMoment(momentID: Moment.ID, now: Date) throws {
        let moment = try activeMoment(momentID)
        guard moment.creatorID == currentUserID else { throw MomentRepositoryError.notAllowed }
        momentsByID[momentID]?.deletedAt = now
        didMutate()
    }

    // MARK: - Internals

    private func activeMoment(_ momentID: Moment.ID) throws -> Moment {
        guard let moment = momentsByID[momentID], moment.isActive else {
            throw MomentRepositoryError.notFound
        }
        return moment
    }

    private func isTagged(_ personID: Person.ID, momentID: Moment.ID) -> Bool {
        momentMembers.contains { $0.momentID == momentID && $0.personID == personID }
    }

    private func canEditMomentTags(momentID: Moment.ID) -> Bool {
        guard let moment = momentsByID[momentID] else { return false }
        let relation = MomentAuthorization.relation(
            moment: moment,
            members: members(ofMoment: momentID),
            media: media(ofMoment: momentID),
            viewerID: currentUserID,
            graph: momentGraphContext(viewerID: currentUserID)
        )
        return MomentAuthorization.canEditTags(relation)
    }

    /// Mirrors `create_moment`: tags must be unblocked accepted friends.
    private func validateTagTarget(_ personID: Person.ID, momentID: Moment.ID) throws {
        guard peopleByID[personID] != nil,
              !isBlocked(currentUserID, personID),
              acceptedFriendIDs.contains(personID)
        else {
            throw MomentRepositoryError.invalidTag
        }
    }

    /// Mirrors `can_create_moment_from_push` + the UNIQUE(push_id) constraint:
    /// the slot is consumed by soft-deleted Moments too.
    private func validatePushSlot(_ pushID: PushPlan.ID) throws {
        guard !momentsByID.values.contains(where: { $0.pushID == pushID }) else {
            throw MomentRepositoryError.momentExistsForPush
        }
        guard let plan = plansByID[pushID],
              plan.cancelledAt == nil,
              plan.expiresAt <= Date()
        else {
            throw MomentRepositoryError.invalidPush
        }
    }

    private func appendMember(momentID: Moment.ID, personID: Person.ID, taggedAt: Date) {
        momentMembers.append(
            MomentMember(
                id: "moment-member-\(momentID)-\(personID)",
                momentID: momentID,
                personID: personID,
                taggedAt: taggedAt
            )
        )
    }

    private func makeMedia(
        _ draft: MomentMediaDraft,
        momentID: Moment.ID,
        uploaderID: Person.ID,
        order: Int,
        now: Date
    ) -> MomentMedia {
        MomentMedia(
            id: "moment-media-\(UUID().uuidString.lowercased())",
            momentID: momentID,
            uploaderID: uploaderID,
            kind: draft.kind,
            storagePath: draft.storagePath,
            publicURL: draft.publicURL,
            posterPath: draft.posterPath,
            posterURL: draft.posterURL,
            sortOrder: order,
            createdAt: now,
            deletedAt: nil
        )
    }

    /// Dense 0..n-1 across active items, cover first — `renumber_moment_media`.
    private func renumberMomentMedia(momentID: Moment.ID) {
        for (index, item) in activeMedia(ofMoment: momentID).enumerated() {
            guard let position = momentMedia.firstIndex(where: { $0.id == item.id }) else { continue }
            momentMedia[position].sortOrder = index
        }
    }

    /// Strictly increasing like the RPCs' `clock_timestamp()`, so two appends
    /// inside one test tick still order deterministically.
    private func bumpActivity(momentID: Moment.ID, from previous: Date, now: Date) {
        let next = max(now, previous.addingTimeInterval(MomentStoreConstants.activityTick))
        momentsByID[momentID]?.lastActivityAt = next
    }

    private func truncated(_ text: String) -> String {
        String(
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(MomentLimits.maxTextLength)
        )
    }
}

enum MomentStoreConstants {
    /// Smallest gap between two activity bumps in the mock clock.
    static let activityTick: TimeInterval = 0.001
}
