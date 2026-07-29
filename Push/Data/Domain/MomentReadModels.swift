//
//  MomentReadModels.swift
//  Push
//
//  Repository read/write shapes: feed + hub rows, single-Moment detail, cursor
//  pagination, and the mutation drafts. Everything here is viewer-scoped —
//  media and counts are already block-filtered for the reader.
//

import Foundation

/// Feed / hub row. Carries the cover and a viewer-visible count rather than
/// the whole album (contract §7.4, §7.6).
struct MomentSummary: Identifiable, Equatable {
    let moment: Moment
    /// Creator first, then tag order; blocked people already removed.
    let taggedPersonIDs: [Person.ID]
    /// First viewer-visible item — not necessarily global `sortOrder` 0 when
    /// the cover's uploader is blocked for this viewer.
    let coverMedia: MomentMedia?
    let visibleMediaCount: Int
    let capabilities: MomentCapabilities

    var id: Moment.ID { moment.id }
}

/// Full album for edit / Add yours surfaces.
struct MomentDetail: Identifiable, Equatable {
    let moment: Moment
    let members: [MomentMember]
    /// Viewer-visible, dense order.
    let media: [MomentMedia]
    let capabilities: MomentCapabilities

    var id: Moment.ID { moment.id }
    var coverMedia: MomentMedia? { media.first }
}

/// Keyset cursor on `(lastActivityAt, id)` — matches the server feed index and
/// stays stable while new Moments arrive at the head.
struct MomentFeedCursor: Equatable {
    let lastActivityAt: Date
    let momentID: Moment.ID
}

struct MomentFeedPage: Equatable {
    let moments: [MomentSummary]
    /// Nil when the last page has been served.
    let nextCursor: MomentFeedCursor?

    var hasMore: Bool { nextCursor != nil }

    static let empty = MomentFeedPage(moments: [], nextCursor: nil)
}

/// One already-uploaded object, ready to be attached by a mutation. Bytes go
/// to Storage first (S3 `MomentMediaStoring`); the repository only ever sees
/// keys, so it never depends on the storage seam.
struct MomentMediaDraft: Equatable {
    let kind: MomentMediaKind
    let storagePath: String
    let publicURL: String
    let posterPath: String?
    let posterURL: String?

    init(
        kind: MomentMediaKind,
        storagePath: String,
        publicURL: String,
        posterPath: String? = nil,
        posterURL: String? = nil
    ) {
        self.kind = kind
        self.storagePath = storagePath
        self.publicURL = publicURL
        self.posterPath = posterPath
        self.posterURL = posterURL
    }

    /// Bridge from a completed S3 upload.
    init(upload: MomentMediaUploadResult) {
        self.init(
            kind: upload.kind,
            storagePath: upload.objectPath,
            publicURL: upload.publicURL,
            posterPath: upload.posterPath,
            posterURL: upload.posterURL
        )
    }
}

/// Publish payload. `pushID` set means "Moment from this past Push" — one per
/// Push, forever.
struct MomentDraft: Equatable {
    let title: String
    let locationText: String
    let pushID: PushPlan.ID?
    let taggedPersonIDs: [Person.ID]
    let media: [MomentMediaDraft]

    init(
        title: String,
        locationText: String = "",
        pushID: PushPlan.ID? = nil,
        taggedPersonIDs: [Person.ID] = [],
        media: [MomentMediaDraft]
    ) {
        self.title = title
        self.locationText = locationText
        self.pushID = pushID
        self.taggedPersonIDs = taggedPersonIDs
        self.media = media
    }
}

enum MomentLimits {
    /// Contract §4.1 — server-enforced too (0023 RPCs).
    static let maxActiveMedia = 8
    /// Matches the RPCs' `left(…, 80)` truncation.
    static let maxTextLength = 80
    static let defaultFeedPageSize = 10
}
