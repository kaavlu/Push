//
//  AddYoursAppendTestDoubles.swift
//  PushTests
//
//  Doubles for the Add Yours append workflow (Issue #127 / S8): a repository
//  wrapper that records every `appendMedia` call and can reject scripted
//  attempts the way the RPC does under a concurrent cap hit.
//

import UIKit
@testable import Push

@MainActor
final class ScriptedAppendMomentRepository: MomentRepository {
    private let wrapped: MomentRepository
    /// One entry per `appendMedia` call, consumed in order. `nil` means "let it
    /// through"; an error rejects that call like the server would.
    private var appendOutcomes: [MomentRepositoryError?]
    private(set) var appendCalls: [(momentID: Moment.ID, items: [MomentMediaDraft])] = []
    private(set) var momentLoads: [Moment.ID] = []

    init(wrapping wrapped: MomentRepository, appendOutcomes: [MomentRepositoryError?] = []) {
        self.wrapped = wrapped
        self.appendOutcomes = appendOutcomes
    }

    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        appendCalls.append((momentID, items))
        if !appendOutcomes.isEmpty, let scripted = appendOutcomes.removeFirst() {
            throw scripted
        }
        try await wrapped.appendMedia(momentID: momentID, items: items)
    }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        momentLoads.append(id)
        return try await wrapped.moment(id: id)
    }

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        try await wrapped.feedPage(cursor: cursor, limit: limit, groupID: groupID)
    }
    func hubMoments() async throws -> [MomentSummary] { try await wrapped.hubMoments() }
    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        try await wrapped.createMoment(draft)
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

/// Seeded Moment ids the Add Yours tests target.
enum AddYoursSeedIDs {
    /// Created by the current user — tagged, contributor, 3 media.
    static let ownMoment = "moment-north-park"
    /// Current user tagged but not a contributor.
    static let taggedMoment = "moment-blue-bottle"
    /// Current user is a pure viewer — `canAddMedia` is false.
    static let viewerOnlyMoment = "moment-crunch"
}

/// Shared setup for the Add Yours append suites.
enum AddYoursTestSupport {

    @MainActor
    static func makeViewModel(
        container: AppDataContainer,
        momentID: Moment.ID,
        moments: MomentRepository? = nil,
        storage: MomentMediaStoring? = nil,
        maxSelection: Int = AddYoursLayout.maxSelectionCount
    ) -> AddYoursViewModel {
        AddYoursViewModel(
            context: AddYoursContext(momentID: momentID),
            container: container,
            moments: moments,
            mediaStorage: storage ?? PublishSpyMediaStorage(),
            timing: .immediate,
            maxSelection: maxSelection
        )
    }

    /// Pads the album to `count` active items so capacity rules can be exercised.
    @MainActor
    static func fill(container: AppDataContainer, momentID: Moment.ID, upTo count: Int) {
        let existing = container.database.activeMedia(ofMoment: momentID).count
        guard existing < count else { return }
        let drafts = (existing..<count).map { index in
            MomentMediaDraft(
                kind: .photo,
                storagePath: "\(momentID)/pad-\(index).jpg",
                publicURL: "assets/moments/pad-\(index).png"
            )
        }
        try? container.database.appendMomentMedia(
            momentID: momentID, items: drafts, now: Date()
        )
    }

    /// A draft carrying real JPEG bytes — the only kind the append can upload.
    static func uploadablePhoto() -> AddYoursDraftItem {
        CreatePostMediaLoader.photoDraft(data: photoJPEG())
            ?? AddYoursDraftItem(kind: .photo, previewImage: nil)
    }

    static func photoJPEG() -> Data {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }
}
