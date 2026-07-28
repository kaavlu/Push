import UIKit
import XCTest
@testable import Push

@MainActor
final class AddYoursViewModelTests: XCTestCase {
    func testContextSubtitleUsesStartPushVoiceWithLocation() {
        let context = AddYoursContext(
            id: "p1",
            locationTitle: "Dolores Park",
            dateTimeLabel: "Sat · 4:30 PM"
        )
        XCTAssertEqual(context.subtitle, "Share photos or videos from Dolores Park.")
        XCTAssertEqual(context.contextDetail, "Sat · 4:30 PM")
    }

    func testContextSubtitleFallsBackWhenEmpty() {
        let context = AddYoursContext(id: "p1", locationTitle: "  ", dateTimeLabel: "")
        XCTAssertEqual(context.subtitle, AddYoursCopy.fallbackSubtitle)
        XCTAssertNil(context.contextDetail)
    }

    func testFittedHeroShrinksToAvailableHeight() {
        let wide = CGSize(width: 360, height: 200)
        let fitted = AddYoursLayout.fittedHeroSize(in: wide)
        XCTAssertLessThanOrEqual(fitted.height, wide.height + 0.5)
        XCTAssertLessThanOrEqual(fitted.width, wide.width + 0.5)
        XCTAssertGreaterThan(fitted.width, 0)
    }

    func testContextFromCarouselMapsFields() {
        let carousel = FeedMediaCarouselFixtures.threeBundlePhotos
        let context = AddYoursContext(carousel: carousel)
        XCTAssertEqual(context.id, carousel.id)
        XCTAssertEqual(context.locationTitle, carousel.locationTitle)
        XCTAssertEqual(context.dateTimeLabel, carousel.dateTimeLabel)
    }

    func testCanSubmitRequiresItemsAndComposingPhase() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.canSubmit)

        viewModel.seed(with: [draftPhoto()])
        XCTAssertTrue(viewModel.canSubmit)
        XCTAssertEqual(viewModel.phase, .composing)
    }

    func testSeedRespectsMaxSelection() {
        let viewModel = makeViewModel(maxSelection: 2)
        viewModel.seed(with: [draftPhoto(), draftPhoto(), draftPhoto()])
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertFalse(viewModel.canAddMore)
        XCTAssertEqual(viewModel.remainingSlots, 0)
    }

    func testSelectAndRemoveClampFocusedIndex() {
        let viewModel = makeViewModel()
        let a = draftPhoto()
        let b = draftPhoto()
        let c = draftPhoto()
        viewModel.seed(with: [a, b, c])

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

    func testSubmitTransitionsToSuccessWithImmediateTiming() async {
        let viewModel = makeViewModel()
        viewModel.seed(with: [draftPhoto(), draftVideo()])
        XCTAssertTrue(viewModel.canSubmit)

        await viewModel.submit()
        XCTAssertEqual(viewModel.phase, .success)
        // After success, submit is no longer available.
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testSubmitNoOpsWhenEmpty() async {
        let viewModel = makeViewModel()
        await viewModel.submit()
        XCTAssertEqual(viewModel.phase, .composing)
    }

    func testSelectionClampHelper() {
        XCTAssertEqual(AddYoursSelection.clampedIndex(0, itemCount: 0), 0)
        XCTAssertEqual(AddYoursSelection.clampedIndex(-1, itemCount: 3), 0)
        XCTAssertEqual(AddYoursSelection.clampedIndex(5, itemCount: 3), 2)
        XCTAssertEqual(AddYoursSelection.clampedIndex(1, itemCount: 3), 1)
    }

    // MARK: - Helpers

    private func makeViewModel(maxSelection: Int = 8) -> AddYoursViewModel {
        AddYoursViewModel(
            context: AddYoursFixtures.sampleContext,
            timing: .immediate,
            maxSelection: maxSelection
        )
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
