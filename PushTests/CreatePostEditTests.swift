//
//  CreatePostEditTests.swift
//  PushTests
//
//  Issue #128 / Moments S9: existing-Moment edit loads MomentDetail, shapes
//  controls from capabilities, and persists metadata / tags / reorder /
//  soft-delete media / self-remove / creator delete through MomentRepository.
//

import XCTest
@testable import Push

@MainActor
final class CreatePostEditTests: XCTestCase {

    private let northPark = "moment-north-park"
    private let blueBottle = "moment-blue-bottle"

    // MARK: - Load + capabilities

    func testOpenExistingMomentLoadsDetailAndCapabilities() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value

        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertNotNil(viewModel.editDetail)
        XCTAssertEqual(viewModel.editDetail?.id, northPark)
        XCTAssertTrue(viewModel.editDetail?.capabilities.canEditMetadata == true)
        XCTAssertTrue(viewModel.editDetail?.capabilities.canDeleteMoment == true)
        XCTAssertTrue(viewModel.showsDeleteMomentAction)
        XCTAssertFalse(viewModel.showsLeaveMomentAction)
        XCTAssertEqual(viewModel.titleText, "North Park sunset")
        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertTrue(viewModel.items.allSatisfy { $0.existingMediaID != nil })
        // No changes yet — Save stays off.
        XCTAssertFalse(viewModel.canSubmit)
        XCTAssertFalse(viewModel.canAddMoreOnCompose)
    }

    func testTaggedNonContributorCannotEditMetadataOrDeleteMoment() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: blueBottle)
        await viewModel.editLoadTask?.value

        let caps = viewModel.editDetail?.capabilities
        XCTAssertEqual(caps?.canEditMetadata, false)
        XCTAssertEqual(caps?.canEditTags, false)
        XCTAssertEqual(caps?.canReorderMedia, false)
        XCTAssertEqual(caps?.canDeleteMoment, false)
        XCTAssertEqual(caps?.canSelfRemoveTag, true)
        XCTAssertFalse(viewModel.canEditMetadataFields)
        XCTAssertFalse(viewModel.canEditPeople)
        XCTAssertFalse(viewModel.canReorderEditMedia)
        XCTAssertFalse(viewModel.showsDeleteMomentAction)
        XCTAssertTrue(viewModel.showsLeaveMomentAction)
        XCTAssertFalse(viewModel.showsPrimarySaveAction)
    }

    func testFeedEditLoadsRepositoryDetailNotCarouselCopy() async {
        let container = AppDataContainer(seed: .standard())
        let detail = try! await container.moments.moment(id: northPark)
        let people = Dictionary(
            uniqueKeysWithValues: (try! await container.friends.friends()
                + [try! await container.friends.currentUser()]).map { ($0.id, $0) }
        )
        var carousel = MomentFeedCardBuilder.card(
            from: MomentSummary(
                moment: detail.moment,
                taggedPersonIDs: detail.members.map(\.personID),
                media: detail.media,
                visibleMediaCount: detail.media.count,
                capabilities: detail.capabilities
            ),
            people: people
        )
        // Stale card copy must not win over the repository.
        carousel = FeedMediaCarouselData(
            id: carousel.id,
            items: carousel.items,
            title: "STALE TITLE",
            locationTitle: "STALE LOC",
            dateTimeLabel: carousel.dateTimeLabel,
            participants: carousel.participants,
            canAddYours: carousel.canAddYours
        )

        let viewModel = CreatePostViewModel.forEditingFeedMoment(
            carousel, container: container, timing: .immediate
        )
        await viewModel.editLoadTask?.value

        XCTAssertEqual(viewModel.titleText, "North Park sunset")
        XCTAssertEqual(viewModel.locationText, "North Park")
        XCTAssertEqual(viewModel.editDetail?.id, northPark)
    }

    // MARK: - Metadata + tags

    func testSaveMetadataCallsUpdateMetadata() async {
        let container = AppDataContainer(seed: .standard())
        let spy = RecordingMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: spy, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value

        viewModel.titleText = "Golden hour"
        viewModel.locationText = "Balboa Park"
        XCTAssertTrue(viewModel.canSubmit)

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertEqual(spy.updateMetadataCalls.count, 1)
        XCTAssertEqual(spy.updateMetadataCalls.first?.title, "Golden hour")
        XCTAssertEqual(spy.updateMetadataCalls.first?.location, "Balboa Park")

        let detail = try! await container.moments.moment(id: northPark)
        XCTAssertEqual(detail.moment.title, "Golden hour")
        XCTAssertEqual(detail.moment.locationText, "Balboa Park")
    }

    func testSaveTagDiffsCallAddAndRemove() async {
        let container = AppDataContainer(seed: .standard())
        let spy = RecordingMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: spy, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value

        // Baseline tags: manav (creator), ram, ohm.
        XCTAssertEqual(Set(viewModel.memberPersonRows.map(\.id)), Set(["manav", "ram", "ohm"]))

        viewModel.openFriendEditor()
        viewModel.toggleFriend("ram") // remove
        if viewModel.availableFriends.contains(where: { $0.id == "nitin" }) {
            viewModel.toggleFriend("nitin") // add
        }
        viewModel.continueFromFriends()

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertTrue(spy.removeTagCalls.contains { $0.personID == "ram" })
        XCTAssertTrue(spy.addTagsCalls.contains { $0.personIDs.contains("nitin") })

        let detail = try! await container.moments.moment(id: northPark)
        let tags = Set(detail.members.map(\.personID))
        XCTAssertFalse(tags.contains("ram"))
        XCTAssertTrue(tags.contains("nitin"))
        XCTAssertTrue(tags.contains("manav"))
    }

    // MARK: - Reorder + media delete

    func testReorderSubmitsFullActiveMediaIDOrder() async {
        let container = AppDataContainer(seed: .standard())
        let spy = RecordingMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: spy, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value

        let original = viewModel.items.map { $0.existingMediaID! }
        XCTAssertEqual(original.count, 3)
        // Move cover to the end.
        viewModel.moveMedia(from: 0, to: 2)
        let expected = viewModel.items.map { $0.existingMediaID! }
        XCTAssertNotEqual(expected, original)

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertEqual(spy.reorderCalls.count, 1)
        XCTAssertEqual(spy.reorderCalls.first?.orderedIDs, expected)

        let detail = try! await container.moments.moment(id: northPark)
        XCTAssertEqual(detail.media.map(\.id), expected)
    }

    func testRemoveMediaSoftDeletesOnSave() async {
        let container = AppDataContainer(seed: .standard())
        let spy = RecordingMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: spy, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value

        let removedID = viewModel.items[0].existingMediaID!
        viewModel.removeItem(at: 0)
        XCTAssertEqual(viewModel.items.count, 2)

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertEqual(spy.softDeleteMediaCalls, [removedID])

        let detail = try! await container.moments.moment(id: northPark)
        XCTAssertEqual(detail.media.count, 2)
        XCTAssertFalse(detail.media.contains { $0.id == removedID })
    }

    func testContributorCannotDeleteSomeoneElsesMedia() async {
        let container = AppDataContainer(seed: .standard())
        // Become a contributor on blue bottle by appending as the current user.
        try! await container.moments.appendMedia(
            momentID: blueBottle,
            items: [
                MomentMediaDraft(
                    kind: .photo,
                    storagePath: "assets/friends/manav.png",
                    publicURL: "assets/friends/manav.png"
                )
            ]
        )
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: blueBottle)
        await viewModel.editLoadTask?.value

        // First two items are chitty / nitin — current user cannot delete those.
        let foreign = viewModel.items.first { item in
            guard let id = item.existingMediaID,
                  let media = viewModel.editDetail?.media.first(where: { $0.id == id })
            else { return false }
            return media.uploaderID != container.currentUserID
        }
        XCTAssertNotNil(foreign)
        if let foreign {
            XCTAssertFalse(viewModel.canDeleteDraftMedia(foreign))
            let before = viewModel.items.count
            if let index = viewModel.items.firstIndex(where: { $0.id == foreign.id }) {
                viewModel.removeItem(at: index)
            }
            XCTAssertEqual(viewModel.items.count, before)
        }
    }

    // MARK: - Destructive

    func testDeleteMomentSoftDeletesAndDismisses() async {
        let container = AppDataContainer(seed: .standard())
        let spy = RecordingMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: spy, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value

        await viewModel.deleteMoment()

        XCTAssertEqual(spy.softDeleteMomentCalls, [northPark])
        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertTrue(viewModel.shouldDismissAfterEdit)
        XCTAssertFalse(viewModel.existingMoments.contains { $0.id == northPark })

        do {
            _ = try await container.moments.moment(id: northPark)
            XCTFail("expected notFound")
        } catch let error as MomentRepositoryError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testLeaveMomentRemovesSelfTagAndDismisses() async {
        let container = AppDataContainer(seed: .standard())
        let spy = RecordingMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: spy, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: blueBottle)
        await viewModel.editLoadTask?.value

        await viewModel.leaveMoment()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertTrue(viewModel.shouldDismissAfterEdit)
        XCTAssertEqual(spy.removeTagCalls.count, 1)
        XCTAssertEqual(spy.removeTagCalls.first?.personID, container.currentUserID)

        // Viewer is no longer tagged — moment leaves the hub for them.
        do {
            _ = try await container.moments.moment(id: blueBottle)
            // Still viewable via friends-of-tagged if friendship path remains.
        } catch {
            // Losing the only view path is also acceptable.
        }
        XCTAssertFalse(viewModel.existingMoments.contains { $0.id == blueBottle })
    }

    // MARK: - Errors / retry

    func testSaveFailureKeepsDraftAndSurfacesRetryableError() async {
        let container = AppDataContainer(seed: .standard())
        let failing = FlippingMomentRepository(
            wrapping: container.moments,
            failUpdateMetadataTimes: 1
        )
        let viewModel = CreatePostViewModel(
            container: container, moments: failing, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value
        viewModel.titleText = "Retry me"

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertNotNil(viewModel.actionError)
        XCTAssertEqual(viewModel.titleText, "Retry me")

        await viewModel.retryPublish()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertNil(viewModel.actionError)
        let detail = try! await container.moments.moment(id: northPark)
        XCTAssertEqual(detail.moment.title, "Retry me")
    }

    func testReorderConflictReloadsDetailWithoutCorruptingBaseline() async {
        let container = AppDataContainer(seed: .standard())
        let failing = FlippingMomentRepository(
            wrapping: container.moments,
            failReorderTimes: 1
        )
        let viewModel = CreatePostViewModel(
            container: container, moments: failing, timing: .immediate
        )
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: northPark)
        await viewModel.editLoadTask?.value
        let serverOrder = viewModel.baselineMediaIDs

        viewModel.moveMedia(from: 0, to: 2)
        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertNotNil(viewModel.actionError)
        // Conflict path reloads detail — order returns to the server set.
        XCTAssertEqual(viewModel.items.map { $0.existingMediaID }, serverOrder)
        XCTAssertEqual(viewModel.baselineMediaIDs, serverOrder)
    }

    func testNotFoundOnLoadSurfacesFailedPhase() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        let missing = FeedMediaCarouselData(
            id: "moment-missing",
            items: [],
            title: "Gone",
            locationTitle: "",
            dateTimeLabel: "",
            participants: [],
            canAddYours: false
        )
        viewModel.openFeedMomentForEdit(missing)
        await viewModel.editLoadTask?.value

        XCTAssertEqual(viewModel.editContentPhase, .failed)
        XCTAssertNil(viewModel.editDetail)
    }
}

// MARK: - Spies

@MainActor
private final class RecordingMomentRepository: MomentRepository {
    private let wrapped: MomentRepository
    private(set) var updateMetadataCalls: [(momentID: Moment.ID, title: String, location: String)] = []
    private(set) var addTagsCalls: [(momentID: Moment.ID, personIDs: [Person.ID])] = []
    private(set) var removeTagCalls: [(momentID: Moment.ID, personID: Person.ID)] = []
    private(set) var reorderCalls: [(momentID: Moment.ID, orderedIDs: [MomentMedia.ID])] = []
    private(set) var softDeleteMediaCalls: [MomentMedia.ID] = []
    private(set) var softDeleteMomentCalls: [Moment.ID] = []

    init(wrapping: MomentRepository) {
        self.wrapped = wrapping
    }

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        try await wrapped.feedPage(cursor: cursor, limit: limit, groupID: groupID)
    }

    func hubMoments() async throws -> [MomentSummary] {
        try await wrapped.hubMoments()
    }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        try await wrapped.moment(id: id)
    }

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        try await wrapped.createMoment(draft)
    }

    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        try await wrapped.appendMedia(momentID: momentID, items: items)
    }

    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        updateMetadataCalls.append((momentID, title, locationText))
        try await wrapped.updateMetadata(
            momentID: momentID, title: title, locationText: locationText
        )
    }

    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws {
        addTagsCalls.append((momentID, personIDs))
        try await wrapped.addTags(momentID: momentID, personIDs: personIDs)
    }

    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws {
        removeTagCalls.append((momentID, personID))
        try await wrapped.removeTag(momentID: momentID, personID: personID)
    }

    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws {
        reorderCalls.append((momentID, orderedMediaIDs))
        try await wrapped.reorderMedia(momentID: momentID, orderedMediaIDs: orderedMediaIDs)
    }

    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        softDeleteMediaCalls.append(mediaID)
        try await wrapped.softDeleteMedia(mediaID: mediaID)
    }

    func softDeleteMoment(momentID: Moment.ID) async throws {
        softDeleteMomentCalls.append(momentID)
        try await wrapped.softDeleteMoment(momentID: momentID)
    }
}

/// Fails the first N calls of selected mutations, then delegates.
@MainActor
private final class FlippingMomentRepository: MomentRepository {
    private let wrapped: MomentRepository
    private var failUpdateMetadataTimes: Int
    private var failReorderTimes: Int

    init(
        wrapping: MomentRepository,
        failUpdateMetadataTimes: Int = 0,
        failReorderTimes: Int = 0
    ) {
        self.wrapped = wrapping
        self.failUpdateMetadataTimes = failUpdateMetadataTimes
        self.failReorderTimes = failReorderTimes
    }

    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage {
        try await wrapped.feedPage(cursor: cursor, limit: limit, groupID: groupID)
    }

    func hubMoments() async throws -> [MomentSummary] {
        try await wrapped.hubMoments()
    }

    func moment(id: Moment.ID) async throws -> MomentDetail {
        try await wrapped.moment(id: id)
    }

    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID {
        try await wrapped.createMoment(draft)
    }

    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws {
        try await wrapped.appendMedia(momentID: momentID, items: items)
    }

    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws {
        if failUpdateMetadataTimes > 0 {
            failUpdateMetadataTimes -= 1
            throw MomentRepositoryError.notAllowed
        }
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
        if failReorderTimes > 0 {
            failReorderTimes -= 1
            throw MomentRepositoryError.conflict
        }
        try await wrapped.reorderMedia(momentID: momentID, orderedMediaIDs: orderedMediaIDs)
    }

    func softDeleteMedia(mediaID: MomentMedia.ID) async throws {
        try await wrapped.softDeleteMedia(mediaID: mediaID)
    }

    func softDeleteMoment(momentID: Moment.ID) async throws {
        try await wrapped.softDeleteMoment(momentID: momentID)
    }
}
