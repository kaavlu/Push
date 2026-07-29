//
//  Moment.swift
//  Push
//
//  Social Moment (media album) domain — the Feed › Pushes entity. Distinct
//  from `PushPlan` (coordination) and `FeedEvent` (activity timeline); the
//  three never map into each other. Mirrors migration 0021 tables.
//

import Foundation

/// One published album. Soft-deleted Moments keep their row (and their Push
/// slot) so `pushID` stays consumed forever.
struct Moment: Identifiable, Equatable {
    typealias ID = String

    let id: ID
    /// Immutable. The creator is always tagged and can never be untagged.
    let creatorID: Person.ID
    var title: String
    /// Frozen display string — live presence/sharing never rewrites it.
    var locationText: String
    var placeID: Place.ID?
    /// Optional source Push. At most one Moment per Push, ever.
    let pushID: PushPlan.ID?
    let publishedAt: Date
    /// Feed ordering. Bumped on create and media append only.
    var lastActivityAt: Date
    var deletedAt: Date?

    var isActive: Bool { deletedAt == nil }
}

/// An explicit tag ("With"). Not attendance inference — presence and Push
/// responses never create these rows.
struct MomentMember: Identifiable, Equatable {
    typealias ID = String

    let id: ID
    let momentID: Moment.ID
    let personID: Person.ID
    let taggedAt: Date
}

enum MomentMediaKind: String, Equatable, CaseIterable {
    case photo
    case video
}

/// One media item. `sortOrder` is dense across active items; 0 is the cover.
struct MomentMedia: Identifiable, Equatable {
    typealias ID = String

    let id: ID
    let momentID: Moment.ID
    let uploaderID: Person.ID
    let kind: MomentMediaKind
    /// Object key in the `moment-media` bucket (S3). The server derives the
    /// stored `publicURL` from it — this copy is for display only.
    let storagePath: String
    let publicURL: String
    let posterPath: String?
    let posterURL: String?
    var sortOrder: Int
    let createdAt: Date
    var deletedAt: Date?

    var isActive: Bool { deletedAt == nil }
}

enum MomentOrdering {
    /// Tag display order: creator first, then oldest tag, then id for stability.
    static func sortedMembers(_ members: [MomentMember], creatorID: Person.ID) -> [MomentMember] {
        members.sorted { lhs, rhs in
            if (lhs.personID == creatorID) != (rhs.personID == creatorID) {
                return lhs.personID == creatorID
            }
            if lhs.taggedAt != rhs.taggedAt { return lhs.taggedAt < rhs.taggedAt }
            return lhs.id < rhs.id
        }
    }

    /// Album order: dense `sortOrder`, ties broken by creation then id.
    static func sortedMedia(_ media: [MomentMedia]) -> [MomentMedia] {
        media.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }
    }

    /// Feed order: newest activity first, id descending as the tiebreaker —
    /// the same `(last_activity_at desc, id desc)` key the feed index uses.
    static func sortedForFeed(_ moments: [Moment]) -> [Moment] {
        moments.sorted { lhs, rhs in
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
            return lhs.id > rhs.id
        }
    }
}
