//
//  AddYoursPartialAppendTests.swift
//  PushTests
//
//  Issue #127 / Moments S8: the failure half of Add Yours — committed items stay
//  committed, only the uncommitted upload is rolled back, the draft survives for
//  Retry, and local pre-flight rejects what can never be uploaded.
//

import XCTest
@testable import Push

@MainActor
final class AddYoursPartialAppendTests: XCTestCase {

    // MARK: - Partial success + retry

    func testPartialFailureKeepsCommittedItemsAndRollsBackOnlyTheFailure() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedAppendMomentRepository(
            wrapping: container.moments, appendOutcomes: [nil, .mediaLimitExceeded]
        )
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container,
            momentID: AddYoursSeedIDs.ownMoment,
            moments: repository,
            storage: storage
        )
        await viewModel.initialLoad?.value
        let before = container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment).count

        viewModel.applyLoadedDrafts([
            AddYoursTestSupport.uploadablePhoto(),
            AddYoursTestSupport.uploadablePhoto()
        ])
        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .composing)
        // The item that committed is gone from the composer; the other stays.
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(
            container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment).count,
            before + 1
        )
        // Only the rejected upload's object is removed.
        XCTAssertEqual(storage.uploadedPaths.count, 2)
        XCTAssertEqual(storage.deletedPaths, [storage.uploadedPaths[1]])

        XCTAssertEqual(
            viewModel.actionError?.message,
            AddYoursAppendCopy.partialPrefix(committed: 1) + AddYoursAppendCopy.mediaLimit
        )
    }

    func testRetryResubmitsOnlyTheRemainingItems() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedAppendMomentRepository(
            wrapping: container.moments, appendOutcomes: [nil, .notFound]
        )
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container,
            momentID: AddYoursSeedIDs.ownMoment,
            moments: repository,
            storage: storage
        )
        await viewModel.initialLoad?.value
        let before = container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment).count

        viewModel.applyLoadedDrafts([
            AddYoursTestSupport.uploadablePhoto(),
            AddYoursTestSupport.uploadablePhoto()
        ])
        await viewModel.submit()
        XCTAssertEqual(viewModel.items.count, 1)

        await viewModel.retrySubmit()

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertNil(viewModel.actionError)
        XCTAssertTrue(viewModel.items.isEmpty)
        // Three RPC attempts total (one rejected), never a duplicate commit.
        XCTAssertEqual(repository.appendCalls.count, 3)
        XCTAssertEqual(
            container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment).count,
            before + 2
        )
        XCTAssertEqual(storage.uploadedPaths.count, 3)
        XCTAssertEqual(storage.deletedPaths.count, 1)
    }

    func testDeniedAppendKeepsTheDraftAndLeavesNoStorageOrphan() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedAppendMomentRepository(
            wrapping: container.moments, appendOutcomes: [.notAllowed]
        )
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container,
            momentID: AddYoursSeedIDs.ownMoment,
            moments: repository,
            storage: storage
        )
        await viewModel.initialLoad?.value

        viewModel.applyLoadedDrafts([AddYoursTestSupport.uploadablePhoto()])
        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.actionError?.message, AddYoursAppendCopy.notAllowed)
        XCTAssertEqual(storage.deletedPaths, storage.uploadedPaths)
    }

    // MARK: - Local validation

    func testCapacityRejectionHappensBeforeAnyUpload() async {
        let container = AppDataContainer(seed: .standard())
        AddYoursTestSupport.fill(
            container: container, momentID: AddYoursSeedIDs.ownMoment, upTo: 7
        )
        let storage = PublishSpyMediaStorage()
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment, storage: storage
        )
        await viewModel.initialLoad?.value

        // Capacity is 1; force a two-item draft past the picker's own clamp so
        // the submit-time check is what rejects it.
        viewModel.applyLoadedDrafts([AddYoursTestSupport.uploadablePhoto()])
        viewModel.items.append(AddYoursTestSupport.uploadablePhoto())
        await viewModel.submit()

        XCTAssertEqual(viewModel.actionError?.message, AddYoursAppendCopy.mediaLimit)
        XCTAssertTrue(storage.uploadedPaths.isEmpty)
        XCTAssertEqual(viewModel.items.count, 2)
    }

    func testDraftWithoutBytesIsRejectedLocally() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment, storage: storage
        )
        await viewModel.initialLoad?.value

        viewModel.applyLoadedDrafts([AddYoursDraftItem(kind: .photo, previewImage: nil)])
        await viewModel.submit()

        XCTAssertEqual(viewModel.actionError?.message, AddYoursAppendCopy.mediaRejected)
        XCTAssertTrue(storage.uploadedPaths.isEmpty)
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testErrorCopyMapsRepositoryAndStorageFailures() {
        XCTAssertEqual(
            AddYoursAppendCopy.message(for: MomentRepositoryError.mediaLimitExceeded),
            AddYoursAppendCopy.mediaLimit
        )
        XCTAssertEqual(
            AddYoursAppendCopy.message(for: MomentRepositoryError.notFound),
            AddYoursAppendCopy.notFound
        )
        XCTAssertEqual(
            AddYoursAppendCopy.message(
                for: MomentMediaStorageError.fileTooLarge(bytes: 2, limit: 1)
            ),
            AddYoursAppendCopy.mediaTooLarge
        )
        XCTAssertEqual(
            AddYoursAppendCopy.message(for: URLError(.timedOut)),
            AddYoursAppendCopy.generic
        )
        XCTAssertEqual(
            AddYoursAppendCopy.message(for: URLError(.timedOut), committed: 2),
            AddYoursAppendCopy.partialPrefix(committed: 2) + AddYoursAppendCopy.generic
        )
    }

    // MARK: - Mock / live parity

    /// The publisher seam both repositories go through: a rejected commit deletes
    /// the object it just uploaded, so neither mode can leak a Storage orphan.
    func testPublisherAppendRollsBackTheUncommittedObject() async {
        let storage = PublishSpyMediaStorage()
        let upload = MomentMediaUpload(
            kind: .photo,
            data: AddYoursTestSupport.photoJPEG(),
            contentType: MomentMediaStorageConfig.jpegContentType
        )

        do {
            try await MomentMediaPublisher.append(
                upload: upload,
                momentID: AddYoursSeedIDs.ownMoment,
                userID: "you",
                storage: storage,
                useMomentFolder: true
            ) { _ in
                throw MomentRepositoryError.mediaLimitExceeded
            }
            XCTFail("expected the commit to throw")
        } catch {
            XCTAssertEqual(error as? MomentRepositoryError, .mediaLimitExceeded)
        }

        XCTAssertEqual(storage.uploadedPaths.count, 1)
        XCTAssertEqual(storage.deletedPaths, storage.uploadedPaths)
    }
}
