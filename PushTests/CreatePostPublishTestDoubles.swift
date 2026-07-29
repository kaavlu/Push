//
//  CreatePostPublishTestDoubles.swift
//  PushTests
//
//  Doubles for the Create Post publish workflow (Issue #126 / S7): a seed with
//  historical pushes (one open for a Moment, one whose slot is taken), a mock
//  repository wrapper that can fail scripted attempts, and a Storage spy that
//  records the upload / rollback sequence.
//

import Foundation
@testable import Push


/// Standard graph plus two historical pushes: one open for a Moment and one whose
/// slot is already taken.
enum PastPushSeed {
    static let openPushID = "past-park-hang"
    static let consumedPushID = "past-taco-night"
    static let taggedFriendID = "ram"

    static func make(now: Date = Date()) -> SeedData {
        var seed = SeedData.standard(now: now)
        seed.plans += [
            plan(id: openPushID, title: "Park hang", hoursAgo: 30, now: now),
            plan(id: consumedPushID, title: "Taco night", hoursAgo: 54, now: now)
        ]
        seed.responses += [
            response(pushID: openPushID, personID: taggedFriendID, response: .in, now: now),
            response(pushID: openPushID, personID: "ohm", response: .out, now: now),
            response(pushID: consumedPushID, personID: taggedFriendID, response: .in, now: now)
        ]
        let publishedAt = now.addingTimeInterval(-40 * SeedTime.hour)
        seed.moments += [
            Moment(
                id: "moment-past-taco",
                creatorID: SeedIDs.currentUser,
                title: "Taco night",
                locationText: "Mission",
                placeID: nil,
                pushID: consumedPushID,
                publishedAt: publishedAt,
                lastActivityAt: publishedAt,
                deletedAt: nil
            )
        ]
        seed.momentMembers += [
            MomentMember(
                id: "moment-past-taco-member",
                momentID: "moment-past-taco",
                personID: SeedIDs.currentUser,
                taggedAt: publishedAt
            )
        ]
        seed.momentMedia += [
            MomentMedia(
                id: "moment-past-taco-media",
                momentID: "moment-past-taco",
                uploaderID: SeedIDs.currentUser,
                kind: .photo,
                storagePath: "moment-past-taco/a.jpg",
                publicURL: "assets/moments/taco.png",
                posterPath: nil,
                posterURL: nil,
                sortOrder: 0,
                createdAt: publishedAt,
                deletedAt: nil
            )
        ]
        return seed
    }

    private static func plan(
        id: String, title: String, hoursAgo: Double, now: Date
    ) -> PushPlan {
        let startsAt = now.addingTimeInterval(-hoursAgo * SeedTime.hour)
        return PushPlan(
            id: id,
            title: title,
            groupID: nil,
            creatorID: SeedIDs.currentUser,
            createdAt: startsAt,
            updatedAt: startsAt,
            startsAt: startsAt,
            hasExplicitTime: true,
            isApproximateTime: false,
            expiresAt: startsAt.addingTimeInterval(SeedTime.sixHours),
            cancelledAt: nil,
            placeID: nil,
            placeIsSuggested: false,
            state: .collecting,
            audience: .inviteesOnly,
            note: nil,
            locationText: "Dolores Park"
        )
    }

    private static func response(
        pushID: String, personID: String, response: PushResponse.Response, now: Date
    ) -> PushResponse {
        PushResponse(
            id: "\(pushID)-\(personID)",
            pushID: pushID,
            personID: personID,
            response: response,
            respondedAt: now,
            readyState: .unknown
        )
    }
}

/// Wraps the mock repository, counts `createMoment` calls, and can fail the first
/// N attempts with a scripted server error.
@MainActor
final class ScriptedMomentRepository: MomentRepository {
    private let wrapped: MomentRepository
    private var failures: [MomentRepositoryError]
    private(set) var createCalls = 0
    private(set) var lastDraft: MomentDraft?

    init(wrapping wrapped: MomentRepository, failures: [MomentRepositoryError] = []) {
        self.wrapped = wrapped
        self.failures = failures
    }

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        createCalls += 1
        lastDraft = draft
        if !failures.isEmpty {
            throw failures.removeFirst()
        }
        return try await wrapped.createMoment(draft)
    }

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        try await wrapped.feedPage(cursor: cursor, limit: limit, groupID: groupID)
    }
    func hubMoments() async throws -> [MomentSummary] { try await wrapped.hubMoments() }
    func moment(id: Moment.ID) async throws -> MomentDetail { try await wrapped.moment(id: id) }
    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        try await wrapped.appendMedia(momentID: momentID, items: items)
    }
    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        try await wrapped.updateMetadata(
            momentID: momentID, title: title, locationText: locationText
        )
    }
    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {
        try await wrapped.addTags(momentID: momentID, personIDs: personIDs)
    }
    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {
        try await wrapped.removeTag(momentID: momentID, personID: personID)
    }
    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {
        try await wrapped.reorderMedia(momentID: momentID, orderedMediaIDs: orderedMediaIDs)
    }
    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        try await wrapped.softDeleteMedia(mediaID: mediaID)
    }
    func softDeleteMoment(momentID: Moment.ID) async throws {
        try await wrapped.softDeleteMoment(momentID: momentID)
    }
}

/// Every hub read fails — drives the failed surface state.
@MainActor
final class FailingMomentRepository: MomentRepository {
    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        throw MomentRepositoryError.notAuthenticated
    }
    func hubMoments() async throws -> [MomentSummary] {
        throw MomentRepositoryError.notAuthenticated
    }
    func moment(id: Moment.ID) async throws -> MomentDetail {
        throw MomentRepositoryError.notFound
    }
    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        throw MomentRepositoryError.notAllowed
    }
    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {}
    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {}
    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {}
    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {}
    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {}
    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {}
    func softDeleteMoment(momentID: Moment.ID) async throws {}
}

/// Records the publish sequence without touching the file system.
final class PublishSpyMediaStorage: MomentMediaStoring, @unchecked Sendable {
    private(set) var uploadedPaths: [String] = []
    private(set) var deletedPaths: [String] = []
    private(set) var pendingUserIDs: [String] = []
    private(set) var momentFolderUploads = 0

    func uploadPending(userID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        pendingUserIDs.append(userID)
        let path = MomentMediaPath.pendingObjectPath(
            userID: userID, fileExtension: fileExtension
        )
        uploadedPaths.append(path)
        return MomentMediaUploadResult(
            kind: upload.kind,
            objectPath: path,
            publicURL: "https://cdn.invalid/\(path)",
            posterPath: nil,
            posterURL: nil
        )
    }

    func upload(momentID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        momentFolderUploads += 1
        let fileExtension = try MomentMediaValidator.validate(upload)
        let path = MomentMediaPath.momentObjectPath(
            momentID: momentID, fileExtension: fileExtension
        )
        uploadedPaths.append(path)
        return MomentMediaUploadResult(
            kind: upload.kind,
            objectPath: path,
            publicURL: "https://cdn.invalid/\(path)",
            posterPath: nil,
            posterURL: nil
        )
    }

    func delete(objectPath: String) async throws {
        deletedPaths.append(objectPath)
    }
}
