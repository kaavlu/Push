import UIKit
import XCTest
@testable import Push

@MainActor
final class AddYoursViewModelTests: XCTestCase {
    func testContextSubtitleIsFixedCopyWithoutLocation() {
        let context = AddYoursContext(momentID: "moment-1")
        XCTAssertEqual(context.subtitle, "Share photos and videos")
        XCTAssertEqual(context.subtitle, AddYoursCopy.subtitle)
    }

    func testFittedHeroShrinksToAvailableHeight() {
        let wide = CGSize(width: 360, height: 200)
        let fitted = AddYoursLayout.fittedHeroSize(in: wide)
        XCTAssertLessThanOrEqual(fitted.height, wide.height + 0.5)
        XCTAssertLessThanOrEqual(fitted.width, wide.width + 0.5)
        XCTAssertGreaterThan(fitted.width, 0)
    }

    func testContextFromCarouselUsesTheMomentID() {
        let carousel = FeedMediaCarouselFixtures.threeBundlePhotos
        let context = AddYoursContext(carousel: carousel)
        XCTAssertEqual(context.momentID, carousel.id)
    }

    func testCanSubmitRequiresItemsAndComposingPhase() async {
        let viewModel = await makeLoadedViewModel()
        XCTAssertFalse(viewModel.canSubmit)

        viewModel.applyLoadedDrafts([draftPhoto()])
        XCTAssertTrue(viewModel.canSubmit)
        XCTAssertEqual(viewModel.phase, .composing)
    }

    func testSelectionRespectsMaxSelection() async {
        let viewModel = await makeLoadedViewModel(maxSelection: 2)
        viewModel.applyLoadedDrafts([draftPhoto(), draftPhoto(), draftPhoto()])
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertFalse(viewModel.canAddMore)
        XCTAssertEqual(viewModel.remainingSlots, 0)
    }

    func testSelectAndRemoveClampFocusedIndex() async {
        let viewModel = await makeLoadedViewModel()
        let a = draftPhoto()
        let b = draftPhoto()
        let c = draftPhoto()
        viewModel.applyLoadedDrafts([a, b, c])

        viewModel.selectItem(at: 2)
        XCTAssertEqual(viewModel.focusedIndex, 2)
        XCTAssertEqual(viewModel.focusedItem?.id, c.id)

        viewModel.removeFocusedItem()
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.focusedIndex, 1)

        viewModel.removeItem(at: 0)
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.focusedIndex, 0)

        viewModel.removeFocusedItem()
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.focusedIndex, 0)
        XCTAssertNil(viewModel.focusedItem)
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testApplyLoadedDraftsFocusesFirstUploadedItem() async {
        let viewModel = await makeLoadedViewModel()
        let first = draftPhoto()
        let second = draftPhoto()
        let third = draftVideo()

        viewModel.applyLoadedDrafts([first, second, third])
        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertEqual(viewModel.focusedIndex, 0)
        XCTAssertEqual(viewModel.focusedItem?.id, first.id)

        // Adding more later still keeps focus on the original first upload.
        let fourth = draftPhoto()
        viewModel.selectItem(at: 2)
        viewModel.applyLoadedDrafts([fourth])
        XCTAssertEqual(viewModel.items.count, 4)
        XCTAssertEqual(viewModel.focusedIndex, 0)
        XCTAssertEqual(viewModel.focusedItem?.id, first.id)
    }

    func testSubmitNoOpsWhenEmpty() async {
        let viewModel = await makeLoadedViewModel()
        await viewModel.submit()
        XCTAssertEqual(viewModel.phase, .composing)
        XCTAssertNil(viewModel.actionError)
    }

    func testSelectionClampHelper() {
        XCTAssertEqual(AddYoursSelection.clampedIndex(0, itemCount: 0), 0)
        XCTAssertEqual(AddYoursSelection.clampedIndex(-1, itemCount: 3), 0)
        XCTAssertEqual(AddYoursSelection.clampedIndex(5, itemCount: 3), 2)
        XCTAssertEqual(AddYoursSelection.clampedIndex(1, itemCount: 3), 1)
    }

    // MARK: - Helpers

    /// A Moment the seeded current user is tagged in, loaded from the mock
    /// repository — the same path the app uses.
    private func makeLoadedViewModel(
        maxSelection: Int = AddYoursLayout.maxSelectionCount
    ) async -> AddYoursViewModel {
        let container = AppDataContainer(seed: .standard())
        let viewModel = AddYoursViewModel(
            context: AddYoursContext(momentID: AddYoursSeedIDs.taggedMoment),
            container: container,
            mediaStorage: PublishSpyMediaStorage(),
            timing: .immediate,
            maxSelection: maxSelection
        )
        await viewModel.initialLoad?.value
        return viewModel
    }

    private func draftPhoto() -> AddYoursDraftItem {
        AddYoursDraftItem(
            kind: .photo,
            previewImage: UIImage(systemName: "photo")
        )
    }

    private func draftVideo() -> AddYoursDraftItem {
        AddYoursDraftItem(kind: .video, previewImage: nil)
    }
}
