//
//  CreatePostPublishTests.swift
//  PushTests
//
//  Issue #126 / Moments S7: repository-backed Create Post hub plus the publish
//  workflow (validation → upload → create → rollback → retry → refresh) for
//  scratch and past-Push drafts.
//

import UIKit
import XCTest
@testable import Push

@MainActor
final class CreatePostPublishTests: XCTestCase {

    // MARK: - Hub reads

    func testHubReadsMomentsAndFriendsFromRepositories() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        XCTAssertFalse(viewModel.existingMoments.isEmpty)
        // Every row is a real Moment, not a fixture id.
        for row in viewModel.existingMoments {
            XCTAssertNotNil(container.database.momentsByID[row.id])
        }
        let fixtureIDs = Set(CreatePostFixtures.existingMoments.map(\.id))
        XCTAssertTrue(fixtureIDs.isDisjoint(with: Set(viewModel.existingMoments.map(\.id))))

        // Tag catalog is the viewer's friends, keyed by Person.ID.
        let friendIDs = Set(try! await container.friends.friends().map(\.id))
        XCTAssertFalse(viewModel.availableFriends.isEmpty)
        XCTAssertTrue(Set(viewModel.availableFriends.map(\.id)).isSubset(of: friendIDs))
        XCTAssertEqual(viewModel.hubContentPhase, .content)
    }

    func testPastPushesExcludePushesThatAlreadyHaveAMoment() async {
        let container = AppDataContainer(seed: PastPushSeed.make())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        let ids = viewModel.pastPushes.map(\.id)
        XCTAssertTrue(ids.contains(PastPushSeed.openPushID))
        XCTAssertFalse(ids.contains(PastPushSeed.consumedPushID))
        // Active pushes are not history.
        XCTAssertFalse(ids.contains("food-tonight"))

        let row = viewModel.pastPushes.first { $0.id == PastPushSeed.openPushID }
        XCTAssertEqual(row?.participants.map(\.id), [PastPushSeed.taggedFriendID])
        XCTAssertTrue(row?.mediaItems.isEmpty ?? false)
    }

    func testHubFailureSurfacesFailedPhase() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(
            container: container, moments: FailingMomentRepository(), timing: .immediate
        )
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.hubContentPhase, .failed)
        XCTAssertTrue(viewModel.existingMoments.isEmpty)
    }

    // MARK: - Scratch publish

    func testScratchPublishCreatesMomentWithTagsAndMedia() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        let before = container.database.momentsByID.count
        let friendID = viewModel.availableFriends[0].id
        viewModel.startFromScratch()
        viewModel.toggleFriend(friendID)
        viewModel.continueFromFriends()
        viewModel.titleText = "Rooftop"
        viewModel.locationText = "Downtown"
        viewModel.seed(with: [uploadablePhoto(), uploadablePhoto()])

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertNil(viewModel.actionError)
        XCTAssertEqual(container.database.momentsByID.count, before + 1)

        let moment = newestMoment(in: container)
        XCTAssertEqual(moment.title, "Rooftop")
        XCTAssertEqual(moment.locationText, "Downtown")
        XCTAssertNil(moment.pushID)
        XCTAssertEqual(moment.creatorID, container.currentUserID)
        XCTAssertEqual(
            container.database.members(ofMoment: moment.id).map(\.personID),
            [container.currentUserID, friendID]
        )
        XCTAssertEqual(container.database.activeMedia(ofMoment: moment.id).count, 2)
        // Hub reloaded, so the new Moment is immediately choosable.
        XCTAssertTrue(viewModel.existingMoments.contains { $0.id == moment.id })
    }

    func testPublishedMomentAppearsOnAFeedLoad() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.titleText = "Solo walk"
        viewModel.seed(with: [uploadablePhoto()])
        await viewModel.submit()

        let feed = FeedViewModel(container: container)
        await feed.initialLoad?.value
        let momentID = newestMoment(in: container).id
        XCTAssertTrue(feed.mediaCarousels.contains { $0.id == momentID })
    }

    // MARK: - Past-Push publish

    func testPastPushPublishSetsPushIDAndConsumesTheSlot() async {
        let container = AppDataContainer(seed: PastPushSeed.make())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value

        viewModel.selectChooserItem(id: PastPushSeed.openPushID)
        XCTAssertEqual(viewModel.source, .pastPush(id: PastPushSeed.openPushID))
        // Prefilled from the "in" responses.
        XCTAssertEqual(viewModel.memberPersonRows.map(\.id), [PastPushSeed.taggedFriendID])

        viewModel.seed(with: [uploadablePhoto()])
        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .success)
        let moment = newestMoment(in: container)
        XCTAssertEqual(moment.pushID, PastPushSeed.openPushID)
        // Slot is consumed: the chooser no longer offers that Push.
        XCTAssertFalse(viewModel.pastPushes.contains { $0.id == PastPushSeed.openPushID })
    }

    /// Race: the Push's Moment belongs to someone the viewer can't see, so the
    /// row is still listed and only the server can reject the publish.
    func testReusedPushSurfacesRecoverableError() async {
        let container = AppDataContainer(seed: PastPushSeed.make())
        let repository = ScriptedMomentRepository(
            wrapping: container.moments, failures: [.momentExistsForPush]
        )
        let viewModel = CreatePostViewModel(
            container: container, moments: repository, timing: .immediate
        )
        await viewModel.initialLoad?.value
        viewModel.selectChooserItem(id: PastPushSeed.openPushID)
        viewModel.seed(with: [uploadablePhoto()])

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertEqual(viewModel.actionError?.message, CreatePostPublishCopy.pushTaken)
        XCTAssertEqual(viewModel.items.count, 1)
    }

    // MARK: - Validation

    func testPublishRejectsDraftWithoutUploadableBytes() async {
        let container = AppDataContainer(seed: .standard())
        let repository = ScriptedMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: repository, timing: .immediate
        )
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        // Prefilled Storage media has a preview but no bytes to re-upload.
        viewModel.seed(with: [AddYoursDraftItem(kind: .photo, previewImage: nil)])

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertEqual(viewModel.actionError?.message, CreatePostPublishCopy.mediaRejected)
        XCTAssertEqual(repository.createCalls, 0)
    }

    func testPublishableUploadsEnforcesMediaRules() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(
            container: container,
            timing: .immediate,
            maxSelection: MomentLimits.maxActiveMedia + 1
        )
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()

        XCTAssertThrowsError(try viewModel.publishableUploads()) { error in
            XCTAssertEqual(error as? MomentRepositoryError, .mediaRequired)
        }

        let photo = uploadablePhoto()
        viewModel.seed(with: Array(repeating: photo, count: MomentLimits.maxActiveMedia + 1))
        XCTAssertThrowsError(try viewModel.publishableUploads()) { error in
            XCTAssertEqual(error as? MomentRepositoryError, .mediaLimitExceeded)
        }
    }

    func testTitleAndLocationTrimmedOntoTheDraft() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = CreatePostViewModel(container: container, timing: .immediate)
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.titleText = "  Taco night  "
        viewModel.locationText = "  Mission  "

        let draft = viewModel.draft(media: [], viewerID: container.currentUserID)
        XCTAssertEqual(draft.title, "Taco night")
        XCTAssertEqual(draft.locationText, "Mission")
        XCTAssertNil(draft.pushID)
    }

    // MARK: - Failure, rollback, retry

    func testFailedCreateRollsBackEveryUploadedObject() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedMomentRepository(
            wrapping: container.moments, failures: [.notAllowed]
        )
        let viewModel = CreatePostViewModel(
            container: container, moments: repository, mediaStorage: storage, timing: .immediate
        )
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.seed(with: [uploadablePhoto(), uploadablePhoto()])

        await viewModel.submit()

        XCTAssertEqual(storage.uploadedPaths.count, 2)
        XCTAssertEqual(Set(storage.deletedPaths), Set(storage.uploadedPaths))
        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertEqual(viewModel.actionError?.message, CreatePostPublishCopy.notAllowed)
        // Draft survives for the retry.
        XCTAssertEqual(viewModel.items.count, 2)
    }

    func testRetryAfterFailurePublishesExactlyOneMoment() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedMomentRepository(
            wrapping: container.moments, failures: [.notAllowed]
        )
        let viewModel = CreatePostViewModel(
            container: container, moments: repository, mediaStorage: storage, timing: .immediate
        )
        await viewModel.initialLoad?.value
        let before = container.database.momentsByID.count
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.seed(with: [uploadablePhoto()])

        await viewModel.submit()
        await viewModel.retryPublish()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertNil(viewModel.actionError)
        XCTAssertEqual(repository.createCalls, 2)
        XCTAssertEqual(container.database.momentsByID.count, before + 1)
        // Second attempt uploaded fresh keys; only the failed pair was deleted.
        XCTAssertEqual(storage.uploadedPaths.count, 2)
        XCTAssertEqual(storage.deletedPaths.count, 1)
        XCTAssertFalse(storage.deletedPaths.contains(storage.uploadedPaths[1]))
    }

    func testSecondSubmitWhileSubmittingIsIgnored() async {
        let container = AppDataContainer(seed: .standard())
        let repository = ScriptedMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: repository, timing: .immediate
        )
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.seed(with: [uploadablePhoto()])

        async let first: Void = viewModel.submit()
        async let second: Void = viewModel.submit()
        _ = await (first, second)

        XCTAssertEqual(repository.createCalls, 1)
        XCTAssertEqual(viewModel.phase, .success)
    }

    // MARK: - Mock / live parity

    /// Both modes run the same view-model workflow: upload every item to the
    /// caller's pending prefix, then commit those exact paths in album order.
    func testWorkflowUploadsPendingThenCommitsSamePaths() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedMomentRepository(wrapping: container.moments)
        let viewModel = CreatePostViewModel(
            container: container, moments: repository, mediaStorage: storage, timing: .immediate
        )
        await viewModel.initialLoad?.value
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.seed(with: [uploadablePhoto(), uploadablePhoto()])

        await viewModel.submit()

        XCTAssertEqual(storage.pendingUserIDs, [container.currentUserID, container.currentUserID])
        XCTAssertEqual(storage.momentFolderUploads, 0)
        XCTAssertEqual(repository.lastDraft?.media.map(\.storagePath), storage.uploadedPaths)
        XCTAssertTrue(
            storage.uploadedPaths.allSatisfy {
                $0.hasPrefix("\(MomentMediaStorageConfig.pendingPrefix)/")
            }
        )
    }

    func testLocalStorageAndLiveStorageShareKeyLayout() async throws {
        let upload = MomentMediaUpload(
            kind: .photo,
            data: photoJPEG(),
            contentType: MomentMediaStorageConfig.jpegContentType
        )
        let result = try await LocalMomentMediaStorage().uploadPending(
            userID: "Manav", upload: upload
        )
        XCTAssertTrue(
            result.objectPath.hasPrefix("\(MomentMediaStorageConfig.pendingPrefix)/manav/")
        )
        XCTAssertTrue(result.objectPath.hasSuffix(".jpg"))
        try await LocalMomentMediaStorage().delete(objectPath: result.objectPath)
    }

    // MARK: - Error copy

    func testServerErrorsMapToRecoverableMessages() {
        XCTAssertEqual(
            CreatePostPublishCopy.message(for: MomentRepositoryError.invalidTag),
            CreatePostPublishCopy.invalidTag
        )
        XCTAssertEqual(
            CreatePostPublishCopy.message(for: MomentRepositoryError.invalidPush),
            CreatePostPublishCopy.invalidPush
        )
        XCTAssertEqual(
            CreatePostPublishCopy.message(for: MomentRepositoryError.mediaLimitExceeded),
            CreatePostPublishCopy.mediaLimit
        )
        XCTAssertEqual(
            CreatePostPublishCopy.message(for: MomentRepositoryError.invalidMediaPath),
            CreatePostPublishCopy.mediaRejected
        )
        XCTAssertEqual(
            CreatePostPublishCopy.message(
                for: MomentMediaStorageError.fileTooLarge(bytes: 2, limit: 1)
            ),
            CreatePostPublishCopy.mediaTooLarge
        )
        XCTAssertEqual(
            CreatePostPublishCopy.message(for: URLError(.timedOut)),
            CreatePostPublishCopy.generic
        )
    }

    // MARK: - Helpers

    private func newestMoment(in container: AppDataContainer) -> Moment {
        let moments = container.database.momentsByID.values
        return moments.max { $0.publishedAt < $1.publishedAt }!
    }

    private func uploadablePhoto() -> AddYoursDraftItem {
        guard let draft = CreatePostMediaLoader.photoDraft(data: photoJPEG()) else {
            XCTFail("could not build an uploadable photo draft")
            return AddYoursDraftItem(kind: .photo, previewImage: nil)
        }
        return draft
    }

    private func photoJPEG() -> Data {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }
}
