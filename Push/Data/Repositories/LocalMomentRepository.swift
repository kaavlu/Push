//
//  LocalMomentRepository.swift
//  Push
//
//  Mock Moment repository over `InMemoryDatabase`. Reads project the same
//  visibility and capability rules the server applies (0022); writes delegate
//  to `InMemoryDatabase+Moments`, which mirrors the 0023 RPCs.
//

import Foundation

@MainActor
final class LocalMomentRepository: MomentRepository {
    private let database: InMemoryDatabase
    /// Injectable so tests can freeze publish/append times.
    private let clock: @Sendable () -> Date

    init(database: InMemoryDatabase, clock: (@Sendable () -> Date)? = nil) {
        self.database = database
        self.clock = clock ?? { Date() }
    }

    private var viewerID: Person.ID { database.currentUserID }

    private var graph: MomentGraphContext {
        database.momentGraphContext(viewerID: viewerID)
    }

    // MARK: - Reads

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        let pageSize = max(1, limit)
        var visible = viewableMoments()
        if let groupID {
            visible = visible.filter { sharesGroup(groupID, momentID: $0.id) }
        }
        if let cursor {
            visible = visible.filter { isAfter(cursor, moment: $0) }
        }

        let page = visible.prefix(pageSize).map(summary(for:))
        let hasMore = visible.count > pageSize
        let nextCursor = hasMore ? page.last.map {
            MomentFeedCursor(lastActivityAt: $0.moment.lastActivityAt, momentID: $0.moment.id)
        } : nil
        return MomentFeedPage(moments: Array(page), nextCursor: nextCursor)
    }

    /// Tagged ∪ contributed ∪ created, still viewable, newest activity first.
    func hubMoments() async throws -> [MomentSummary] {
        viewableMoments()
            .filter { moment in
                if moment.creatorID == viewerID { return true }
                let relation = MomentAuthorization.relation(
                    moment: moment,
                    members: database.members(ofMoment: moment.id),
                    media: database.media(ofMoment: moment.id),
                    viewerID: viewerID,
                    graph: graph
                )
                return relation.isTagged || relation.isContributor
            }
            .map(summary(for:))
    }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        guard let moment = database.momentsByID[id] else {
            throw MomentRepositoryError.notFound
        }
        let members = database.members(ofMoment: id)
        let allMedia = database.media(ofMoment: id)
        let capabilities = MomentAuthorization.capabilities(
            moment: moment, members: members, media: allMedia,
            viewerID: viewerID, graph: graph
        )
        guard capabilities.canView else { throw MomentRepositoryError.notFound }

        return MomentDetail(
            moment: moment,
            members: members.filter { !graph.isBlocked($0.personID) },
            media: MomentAuthorization.visibleMedia(allMedia, viewerID: viewerID, graph: graph),
            capabilities: capabilities
        )
    }

    // MARK: - Mutations

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        try database.createMoment(draft, now: clock())
    }

    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        try database.appendMomentMedia(momentID: momentID, items: items, now: clock())
    }

    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        try database.updateMomentMetadata(
            momentID: momentID, title: title, locationText: locationText
        )
    }

    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {
        try database.addMomentMembers(momentID: momentID, personIDs: personIDs, now: clock())
    }

    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {
        try database.removeMomentMember(momentID: momentID, personID: personID)
    }

    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {
        try database.reorderMomentMedia(momentID: momentID, orderedMediaIDs: orderedMediaIDs)
    }

    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        try database.softDeleteMomentMedia(mediaID: mediaID, now: clock())
    }

    func softDeleteMoment(momentID: Moment.ID) async throws {
        try database.softDeleteMoment(momentID: momentID, now: clock())
    }

    // MARK: - Projection

    private func viewableMoments() -> [Moment] {
        let context = graph
        let viewable = database.momentsByID.values.filter { moment in
            MomentAuthorization.canView(
                moment: moment,
                members: database.members(ofMoment: moment.id),
                media: database.media(ofMoment: moment.id),
                viewerID: viewerID,
                graph: context
            )
        }
        return MomentOrdering.sortedForFeed(Array(viewable))
    }

    private func summary(for moment: Moment) -> MomentSummary {
        let members = database.members(ofMoment: moment.id)
        let allMedia = database.media(ofMoment: moment.id)
        let visible = MomentAuthorization.visibleMedia(
            allMedia, viewerID: viewerID, graph: graph
        )
        return MomentSummary(
            moment: moment,
            taggedPersonIDs: members
                .filter { !graph.isBlocked($0.personID) }
                .map(\.personID),
            media: visible,
            visibleMediaCount: visible.count,
            capabilities: MomentAuthorization.capabilities(
                moment: moment, members: members, media: allMedia,
                viewerID: viewerID, graph: graph
            )
        )
    }

    /// Keyset comparison: strictly older activity, or same activity with a
    /// smaller id — the tiebreaker `MomentOrdering.sortedForFeed` uses.
    private func isAfter(_ cursor: MomentFeedCursor, moment: Moment) -> Bool {
        if moment.lastActivityAt != cursor.lastActivityAt {
            return moment.lastActivityAt < cursor.lastActivityAt
        }
        return moment.id < cursor.momentID
    }

    /// Group chips filter on shared membership with any tagged member
    /// (contract §7.8) — never on Moment visibility itself.
    private func sharesGroup(_ groupID: FriendGroup.ID, momentID: Moment.ID) -> Bool {
        let activeMemberIDs = Set(
            database.memberships
                .filter { $0.groupID == groupID && $0.membershipStatus == .active }
                .map(\.personID)
        )
        guard activeMemberIDs.contains(viewerID) else { return false }
        return database.members(ofMoment: momentID).contains {
            activeMemberIDs.contains($0.personID)
        }
    }
}
