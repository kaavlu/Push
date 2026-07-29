//
//  SeedData+Moments.swift
//  Push
//
//  Mock Moment album seed. Mock-only by construction: the live container has
//  no `InMemoryDatabase`, so these rows can never reach an authenticated
//  session. Deterministic — ids are fixed and every timestamp is derived from
//  the caller's `now`, so ordering and covers reproduce exactly.
//
//  Deliberately independent of `feedEvents` (Feed › Now) and of the Feed
//  carousel fixtures: Moments own their data.
//

import Foundation

extension SeedData {

    static func standardMoments(now: Date) -> [Moment] {
        momentSpecs(now: now).map(\.moment)
    }

    static func standardMomentMembers(now: Date) -> [MomentMember] {
        momentSpecs(now: now).flatMap(\.members)
    }

    static func standardMomentMedia(now: Date) -> [MomentMedia] {
        momentSpecs(now: now).flatMap(\.media)
    }

    // MARK: - Specs

    /// One published album per row: `(id, title, location, creator, tags,
    /// media uploaders, hours ago)`. The current user creates one, is tagged
    /// without contributing on another (drives "open for adds"), and is a
    /// pure viewer on the third.
    private static let momentRoster:
        [(
            id: String,
            title: String,
            location: String,
            creatorID: Person.ID,
            taggedIDs: [Person.ID],
            uploaderIDs: [Person.ID],
            hoursAgo: Double
        )] = [
            (
                id: "moment-north-park",
                title: "North Park sunset",
                location: "North Park",
                creatorID: SeedIDs.currentUser,
                taggedIDs: ["ram", "ohm"],
                uploaderIDs: [SeedIDs.currentUser, SeedIDs.currentUser, "ram"],
                hoursAgo: 3
            ),
            (
                id: "moment-blue-bottle",
                title: "Coffee run",
                location: "Blue Bottle",
                creatorID: "chitty",
                taggedIDs: [SeedIDs.currentUser, "nitin"],
                uploaderIDs: ["chitty", "nitin"],
                hoursAgo: 20
            ),
            (
                id: "moment-crunch",
                title: "Leg day",
                location: "Crunch",
                creatorID: "rohan",
                taggedIDs: ["ryan"],
                uploaderIDs: ["rohan"],
                hoursAgo: 52
            )
        ]

    private static func momentSpecs(now: Date) -> [MomentSeedSpec] {
        momentRoster.map { row in
            let publishedAt = now.addingTimeInterval(-row.hoursAgo * SeedTime.hour)
            let members = ([row.creatorID] + row.taggedIDs).enumerated().map { index, personID in
                MomentMember(
                    id: "moment-member-\(row.id)-\(personID)",
                    momentID: row.id,
                    personID: personID,
                    // Creator first, then tag order.
                    taggedAt: publishedAt.addingTimeInterval(Double(index) * SeedTime.minute)
                )
            }
            let media = row.uploaderIDs.enumerated().map { index, uploaderID in
                seedMedia(
                    momentID: row.id,
                    uploaderID: uploaderID,
                    order: index,
                    createdAt: publishedAt.addingTimeInterval(Double(index) * SeedTime.minute)
                )
            }
            // Album activity = latest media add, matching the server rule.
            let lastActivityAt = media.map(\.createdAt).max() ?? publishedAt
            return MomentSeedSpec(
                moment: Moment(
                    id: row.id,
                    creatorID: row.creatorID,
                    title: row.title,
                    locationText: row.location,
                    placeID: nil,
                    pushID: nil,
                    publishedAt: publishedAt,
                    lastActivityAt: lastActivityAt,
                    deletedAt: nil
                ),
                members: members,
                media: media
            )
        }
    }

    /// Mock media points at the uploader's bundled avatar asset — real bytes on
    /// disk for the loader, no network, no carousel fixtures.
    private static func seedMedia(
        momentID: Moment.ID,
        uploaderID: Person.ID,
        order: Int,
        createdAt: Date
    ) -> MomentMedia {
        let path = "assets/friends/\(uploaderID).png"
        return MomentMedia(
            id: "moment-media-\(momentID)-\(order)",
            momentID: momentID,
            uploaderID: uploaderID,
            kind: .photo,
            storagePath: path,
            publicURL: path,
            posterPath: nil,
            posterURL: nil,
            sortOrder: order,
            createdAt: createdAt,
            deletedAt: nil
        )
    }
}

/// One seeded album with its tag and media rows.
private struct MomentSeedSpec {
    let moment: Moment
    let members: [MomentMember]
    let media: [MomentMedia]
}
