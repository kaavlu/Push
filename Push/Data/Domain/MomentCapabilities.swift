//
//  MomentCapabilities.swift
//  Push
//
//  Client projection of the server permission matrix (contract §10, migration
//  0022 `private.moment_capabilities`). These flags shape UI affordances only —
//  every mutation is re-checked server-side, and the local repository applies
//  the same derivation so mock and live behave alike.
//

import Foundation

/// The viewer's derived standing on one Moment. Roles are never stored as
/// enums: creator/tagged/contributor are all recomputed from rows.
struct MomentRelation: Equatable {
    let isCreator: Bool
    let isTagged: Bool
    /// Has at least one non-deleted media item on this Moment.
    let isContributor: Bool
    let canView: Bool

    /// Contract §10 "K": contributor who is still tagged.
    var isTaggedContributor: Bool { isContributor && isTagged }
}

/// Viewer-scoped capability flags. Per-media deletion stays a function because
/// it depends on the item's uploader, not on the Moment alone.
struct MomentCapabilities: Equatable {
    let viewerID: Person.ID
    let canView: Bool
    let canAddMedia: Bool
    let canEditTags: Bool
    let canEditMetadata: Bool
    let canReorderMedia: Bool
    let canDeleteMoment: Bool
    let canSelfRemoveTag: Bool
    let youContributed: Bool
    /// Tagged but hasn't posted yet — drives the "open for adds" affordance.
    let showOpenForAddsChip: Bool
    /// Backing for `canDeleteMedia`; creators may remove anyone's item.
    private let isCreator: Bool

    init(
        viewerID: Person.ID,
        canView: Bool,
        canAddMedia: Bool,
        canEditTags: Bool,
        canEditMetadata: Bool,
        canReorderMedia: Bool,
        canDeleteMoment: Bool,
        canSelfRemoveTag: Bool,
        youContributed: Bool,
        showOpenForAddsChip: Bool,
        isCreator: Bool
    ) {
        self.viewerID = viewerID
        self.canView = canView
        self.canAddMedia = canAddMedia
        self.canEditTags = canEditTags
        self.canEditMetadata = canEditMetadata
        self.canReorderMedia = canReorderMedia
        self.canDeleteMoment = canDeleteMoment
        self.canSelfRemoveTag = canSelfRemoveTag
        self.youContributed = youContributed
        self.showOpenForAddsChip = showOpenForAddsChip
        self.isCreator = isCreator
    }

    /// Uploader may delete their own item; the creator may delete any item.
    /// Independent of `canView` — an untagged past contributor keeps this.
    func canDeleteMedia(_ media: MomentMedia) -> Bool {
        media.isActive && (media.uploaderID == viewerID || isCreator)
    }

    static func denied(viewerID: Person.ID) -> MomentCapabilities {
        MomentCapabilities(
            viewerID: viewerID,
            canView: false,
            canAddMedia: false,
            canEditTags: false,
            canEditMetadata: false,
            canReorderMedia: false,
            canDeleteMoment: false,
            canSelfRemoveTag: false,
            youContributed: false,
            showOpenForAddsChip: false,
            isCreator: false
        )
    }
}

/// The viewer's social graph as the Moment rules need it. Closures keep the
/// derivation independent of whichever store answers the questions.
struct MomentGraphContext {
    /// Accepted friendship between the viewer and `personID`.
    let isFriend: (Person.ID) -> Bool
    /// Block in either direction between the viewer and `personID`.
    let isBlocked: (Person.ID) -> Bool

    static func none() -> MomentGraphContext {
        MomentGraphContext(isFriend: { _ in false }, isBlocked: { _ in false })
    }
}

enum MomentAuthorization {

    /// Media the viewer may see: active, and not uploaded by someone they are
    /// blocked with (contract §4.4 / §5.1).
    static func visibleMedia(
        _ media: [MomentMedia],
        viewerID: Person.ID,
        graph: MomentGraphContext
    ) -> [MomentMedia] {
        MomentOrdering.sortedMedia(
            media.filter { $0.isActive && !graph.isBlocked($0.uploaderID) }
        )
    }

    /// Contract §5.1: not deleted, ≥1 viewer-visible media, and at least one
    /// tagged member who is the viewer or an unblocked accepted friend.
    static func canView(
        moment: Moment,
        members: [MomentMember],
        media: [MomentMedia],
        viewerID: Person.ID,
        graph: MomentGraphContext
    ) -> Bool {
        guard moment.isActive else { return false }
        guard !visibleMedia(media, viewerID: viewerID, graph: graph).isEmpty else { return false }
        return members.contains { member in
            guard !graph.isBlocked(member.personID) else { return false }
            return member.personID == viewerID || graph.isFriend(member.personID)
        }
    }

    static func relation(
        moment: Moment,
        members: [MomentMember],
        media: [MomentMedia],
        viewerID: Person.ID,
        graph: MomentGraphContext
    ) -> MomentRelation {
        MomentRelation(
            isCreator: moment.creatorID == viewerID,
            isTagged: members.contains { $0.personID == viewerID },
            isContributor: media.contains { $0.uploaderID == viewerID && $0.isActive },
            canView: canView(
                moment: moment, members: members, media: media,
                viewerID: viewerID, graph: graph
            )
        )
    }

    /// Tag edits and reorder: creator, or a contributor who is still tagged
    /// (0022 `can_edit_moment_tags` / `can_reorder_moment_media`).
    static func canEditTags(_ relation: MomentRelation) -> Bool {
        relation.isCreator || relation.isTaggedContributor
    }

    static func capabilities(
        moment: Moment,
        members: [MomentMember],
        media: [MomentMedia],
        viewerID: Person.ID,
        graph: MomentGraphContext
    ) -> MomentCapabilities {
        let relation = relation(
            moment: moment, members: members, media: media,
            viewerID: viewerID, graph: graph
        )
        let editsTags = canEditTags(relation)
        return MomentCapabilities(
            viewerID: viewerID,
            canView: relation.canView,
            canAddMedia: relation.canView && relation.isTagged,
            canEditTags: relation.canView && editsTags,
            canEditMetadata: relation.canView && relation.isCreator,
            canReorderMedia: relation.canView && editsTags,
            canDeleteMoment: relation.canView && relation.isCreator,
            // Creator can never drop their own tag.
            canSelfRemoveTag: relation.isTagged && !relation.isCreator,
            youContributed: relation.isContributor,
            showOpenForAddsChip: relation.canView
                && relation.isTagged
                && !relation.isContributor,
            isCreator: relation.isCreator
        )
    }
}
