//
//  AddYoursAppendTests.swift
//  PushTests
//
//  Issue #127 / Moments S8: Add Yours loads a real `MomentDetail`, gates the
//  affordance on server capabilities and remaining capacity, and appends each
//  item through Storage + `MomentRepository`. Partial-success, rollback, and
//  retry behavior lives in `AddYoursPartialAppendTests`.
//

import XCTest
@testable import Push

@MainActor
final class AddYoursAppendTests: XCTestCase {

    // MARK: - Load + capabilities

    func testLoadsDetailFromRepositoryNotFromTheFeedCard() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment
        )
        await viewModel.initialLoad?.value

        let seeded = container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment)
        XCTAssertEqual(viewModel.detail?.id, AddYoursSeedIDs.ownMoment)
        XCTAssertEqual(viewModel.detail?.media.map(\.id), seeded.map(\.id))
        XCTAssertEqual(viewModel.contentPhase, .content)
        XCTAssertTrue(viewModel.canAddMedia)
    }

    func testCarouselContextCarriesOnlyTheMomentIdentity() {
        let carousel = FeedMediaCarouselFixtures.threeBundlePhotos
        let context = AddYoursContext(carousel: carousel)
        XCTAssertEqual(context.momentID, carousel.id)
        XCTAssertEqual(context.id, carousel.id)
    }

    func testCapabilityGatingBlocksSubmitForAViewerWhoIsNotTagged() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.viewerOnlyMoment
        )
        await viewModel.initialLoad?.value

        XCTAssertFalse(viewModel.canAddMedia)
        XCTAssertTrue(viewModel.isDenied)
        XCTAssertFalse(viewModel.canAddMore)
        viewModel.applyLoadedDrafts([AddYoursTestSupport.uploadablePhoto()])
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testTaggedNonContributorMayAdd() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.taggedMoment
        )
        await viewModel.initialLoad?.value

        XCTAssertTrue(viewModel.canAddMedia)
        XCTAssertFalse(viewModel.isDenied)
    }

    func testLoadFailureSurfacesTheFailedState() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container,
            momentID: AddYoursSeedIDs.ownMoment,
            moments: FailingMomentRepository()
        )
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.contentPhase, .failed)
        XCTAssertNil(viewModel.detail)
        XCTAssertFalse(viewModel.canSubmit)
    }

    // MARK: - Capacity

    func testRemainingCapacityComesFromTheLoadedAlbum() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment
        )
        await viewModel.initialLoad?.value

        let existing = container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment).count
        XCTAssertEqual(viewModel.remainingCapacity, MomentLimits.maxActiveMedia - existing)
        XCTAssertEqual(viewModel.remainingSlots, MomentLimits.maxActiveMedia - existing)
    }

    func testSelectionStopsAtRemainingCapacity() async {
        let container = AppDataContainer(seed: .standard())
        AddYoursTestSupport.fill(
            container: container, momentID: AddYoursSeedIDs.ownMoment, upTo: 7
        )
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment
        )
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.remainingSlots, 1)
        viewModel.applyLoadedDrafts([
            AddYoursTestSupport.uploadablePhoto(),
            AddYoursTestSupport.uploadablePhoto(),
            AddYoursTestSupport.uploadablePhoto()
        ])
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertFalse(viewModel.canAddMore)
    }

    func testFullMomentReportsNoCapacity() async {
        let container = AppDataContainer(seed: .standard())
        AddYoursTestSupport.fill(
            container: container, momentID: AddYoursSeedIDs.ownMoment, upTo: 8
        )
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment
        )
        await viewModel.initialLoad?.value

        XCTAssertTrue(viewModel.isFull)
        XCTAssertEqual(viewModel.remainingSlots, 0)
        XCTAssertFalse(viewModel.canAddMore)
    }

    // MARK: - Append

    func testAppendUploadsToTheMomentFolderAndCommitsEachItemSeparately() async {
        let container = AppDataContainer(seed: .standard())
        let storage = PublishSpyMediaStorage()
        let repository = ScriptedAppendMomentRepository(wrapping: container.moments)
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

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertNil(viewModel.actionError)
        XCTAssertTrue(viewModel.items.isEmpty)
        // Two uploads under `{moment_id}/…`, never the pending prefix.
        XCTAssertEqual(storage.momentFolderUploads, 2)
        XCTAssertTrue(storage.pendingUserIDs.isEmpty)
        XCTAssertTrue(storage.deletedPaths.isEmpty)
        XCTAssertTrue(
            storage.uploadedPaths.allSatisfy {
                $0.hasPrefix("\(AddYoursSeedIDs.ownMoment)/")
            }
        )
        // Per item: rollback granularity depends on one media per RPC call.
        XCTAssertEqual(repository.appendCalls.count, 2)
        XCTAssertTrue(repository.appendCalls.allSatisfy { $0.items.count == 1 })
        XCTAssertEqual(
            container.database.activeMedia(ofMoment: AddYoursSeedIDs.ownMoment).count,
            before + 2
        )
    }

    func testSuccessfulAppendRefreshesDetailAndFeedOrdering() async {
        let container = AppDataContainer(seed: .standard())
        let feed = FeedViewModel(container: container)
        await feed.initialLoad?.value
        // The newest Moment leads the feed; the older one is the append target.
        XCTAssertNotEqual(feed.mediaCarousels.first?.id, AddYoursSeedIDs.taggedMoment)

        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.taggedMoment
        )
        await viewModel.initialLoad?.value
        let before = viewModel.detail?.media.count ?? 0
        viewModel.applyLoadedDrafts([AddYoursTestSupport.uploadablePhoto()])
        await viewModel.submit()

        XCTAssertEqual(viewModel.detail?.media.count, before + 1)
        XCTAssertTrue(viewModel.detail?.capabilities.youContributed ?? false)

        // Append bumps `lastActivityAt`, so a Feed reload puts the card first.
        await feed.load()
        XCTAssertEqual(feed.mediaCarousels.first?.id, AddYoursSeedIDs.taggedMoment)
    }

    /// Mock and live both take one media per `appendMedia` call from this view
    /// model, which is what makes per-item partial success identical in each.
    func testAppendCallShapeIsIdenticalForMockAndLiveRepositories() async {
        let container = AppDataContainer(seed: .standard())
        let repository = ScriptedAppendMomentRepository(wrapping: container.moments)
        let viewModel = AddYoursTestSupport.makeViewModel(
            container: container, momentID: AddYoursSeedIDs.ownMoment, moments: repository
        )
        await viewModel.initialLoad?.value

        viewModel.applyLoadedDrafts([
            AddYoursTestSupport.uploadablePhoto(),
            AddYoursTestSupport.uploadablePhoto()
        ])
        await viewModel.submit()

        for call in repository.appendCalls {
            XCTAssertEqual(call.momentID, AddYoursSeedIDs.ownMoment)
            XCTAssertEqual(call.items.count, 1)
            XCTAssertTrue(call.items[0].storagePath.hasPrefix("\(AddYoursSeedIDs.ownMoment)/"))
            XCTAssertFalse(call.items[0].publicURL.isEmpty)
        }
        // Detail was reloaded from the repository after the append.
        XCTAssertGreaterThanOrEqual(repository.momentLoads.count, 2)
    }
}
