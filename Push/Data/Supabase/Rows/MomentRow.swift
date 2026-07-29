//
//  MomentRow.swift
//  Push
//
//  Decoding for the `feed_moments` / `hub_moments` / `moment_detail` DTO
//  (migration 0026). One row already carries the Moment, its ordered tag ids,
//  the viewer-visible media, a viewer-visible count, and capability flags, so
//  the client never re-filters or issues follow-up reads.
//
//  Timestamps decode as `String` for the same reason as `PushRow`: the default
//  date strategy cannot read PostgREST's ISO-8601 strings.
//

import Foundation

struct MomentRow: Decodable {
    let id: String
    let creator_id: String
    let title: String
    let location_text: String
    let place_id: String?
    let push_id: String?
    let published_at: String
    let last_activity_at: String
    /// Creator first, then tag order; blocked people already removed server-side.
    let tagged_person_ids: [String]
    let media: [MomentMediaRow]
    let visible_media_count: Int
    let capabilities: MomentCapabilitiesRow

    func moment() -> Moment {
        Moment(
            id: id,
            creatorID: creator_id,
            title: title,
            locationText: location_text,
            placeID: place_id,
            pushID: push_id,
            publishedAt: PushDateFormatting.parse(published_at) ?? .distantPast,
            lastActivityAt: PushDateFormatting.parse(last_activity_at) ?? .distantPast,
            // The RPCs only ever return live Moments.
            deletedAt: nil
        )
    }

    func summary(viewerID: Person.ID) -> MomentSummary {
        let items = mediaItems()
        return MomentSummary(
            moment: moment(),
            taggedPersonIDs: tagged_person_ids,
            // First *visible* item, which may not be global sort_order 0 when
            // the cover's uploader is blocked for this viewer.
            coverMedia: items.first,
            visibleMediaCount: visible_media_count,
            capabilities: momentCapabilities(viewerID: viewerID)
        )
    }

    func detail(viewerID: Person.ID) -> MomentDetail {
        MomentDetail(
            moment: moment(),
            members: members(),
            media: mediaItems(),
            capabilities: momentCapabilities(viewerID: viewerID)
        )
    }

    /// Tag rows are not returned individually — the DTO ships an ordered id
    /// list, so synthesize members preserving that order.
    private func members() -> [MomentMember] {
        let taggedAt = PushDateFormatting.parse(published_at) ?? .distantPast
        return tagged_person_ids.enumerated().map { index, personID in
            MomentMember(
                id: "\(id)-\(personID)",
                momentID: id,
                personID: personID,
                taggedAt: taggedAt.addingTimeInterval(TimeInterval(index))
            )
        }
    }

    private func mediaItems() -> [MomentMedia] {
        media.compactMap { $0.momentMedia(momentID: id) }
    }

    private func momentCapabilities(viewerID: Person.ID) -> MomentCapabilities {
        capabilities.capabilities(
            viewerID: viewerID,
            isCreator: creator_id == viewerID,
            isTagged: tagged_person_ids.contains(viewerID)
        )
    }
}

struct MomentMediaRow: Decodable {
    let id: String
    let moment_id: String
    let uploader_id: String
    let kind: String
    let storage_path: String
    let public_url: String
    let poster_path: String?
    let poster_url: String?
    let sort_order: Int
    let created_at: String

    /// Nil for an unknown kind rather than guessing — a future media type must
    /// not silently render as a photo.
    func momentMedia(momentID: Moment.ID) -> MomentMedia? {
        guard let mediaKind = MomentMediaKind(rawValue: kind) else { return nil }
        return MomentMedia(
            id: id,
            momentID: momentID,
            uploaderID: uploader_id,
            kind: mediaKind,
            storagePath: storage_path,
            publicURL: public_url,
            posterPath: poster_path,
            posterURL: poster_url,
            sortOrder: sort_order,
            createdAt: PushDateFormatting.parse(created_at) ?? .distantPast,
            deletedAt: nil
        )
    }
}

/// `private.moment_capabilities` JSON. Camel-cased keys come straight from the
/// SQL `jsonb_build_object`.
struct MomentCapabilitiesRow: Decodable {
    let canView: Bool
    let canAddMedia: Bool
    let canEditTags: Bool
    let canEditMetadata: Bool
    let canReorderMedia: Bool
    let canDeleteMoment: Bool
    let youContributed: Bool
    let showOpenForAddsChip: Bool

    /// `canSelfRemoveTag` is not part of the server payload — it is expressed
    /// inside `remove_moment_member` — so derive it from the same two facts the
    /// RPC checks: tagged, and not the creator.
    func capabilities(
        viewerID: Person.ID,
        isCreator: Bool,
        isTagged: Bool
    ) -> MomentCapabilities {
        MomentCapabilities(
            viewerID: viewerID,
            canView: canView,
            canAddMedia: canAddMedia,
            canEditTags: canEditTags,
            canEditMetadata: canEditMetadata,
            canReorderMedia: canReorderMedia,
            canDeleteMoment: canDeleteMoment,
            canSelfRemoveTag: isTagged && !isCreator,
            youContributed: youContributed,
            showOpenForAddsChip: showOpenForAddsChip,
            isCreator: isCreator
        )
    }
}
