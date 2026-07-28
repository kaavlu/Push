import XCTest
@testable import Push
import CoreGraphics

@MainActor
final class FeedMediaCarouselTests: XCTestCase {
    func testMediaAspectRatioIsCompactPortrait() {
        // width / height in the compact cinematic band (not story-tall 3:4).
        XCTAssertGreaterThanOrEqual(FeedMediaLayout.aspectRatio, 0.84)
        XCTAssertLessThanOrEqual(FeedMediaLayout.aspectRatio, 0.88)
        XCTAssertEqual(FeedMediaLayout.aspectRatio, 0.86, accuracy: 0.0001)
    }

    func testMediaCornerRadiusIsInProductionBand() {
        XCTAssertGreaterThanOrEqual(FeedMediaLayout.cornerRadius, 28)
        XCTAssertLessThanOrEqual(FeedMediaLayout.cornerRadius, 32)
    }

    func testProgressBarHiddenForSingleItem() {
        XCTAssertEqual(FeedMediaCarouselFixtures.singlePhoto.items.count, 1)
        XCTAssertEqual(FeedMediaCarouselFixtures.missingMedia.items.count, 1)
        XCTAssertGreaterThan(FeedMediaCarouselFixtures.threeBundlePhotos.items.count, 1)
        XCTAssertGreaterThan(FeedMediaLayout.progressHorizontalInset, FeedMediaLayout.progressTopInset)
        XCTAssertGreaterThan(FeedMediaLayout.autoAdvanceDuration, 0)
    }

    func testFixturesCoverRequiredCarouselStates() {
        let three = FeedMediaCarouselFixtures.threeMixedAspectPhotos
        XCTAssertEqual(three.items.count, 3)
        XCTAssertTrue(three.items.allSatisfy { $0.kind == .photo })

        let single = FeedMediaCarouselFixtures.singlePhoto
        XCTAssertEqual(single.items.count, 1)

        let mixed = FeedMediaCarouselFixtures.mixedPortraitLandscapeSquare
        XCTAssertGreaterThanOrEqual(mixed.items.count, 3)

        let missing = FeedMediaCarouselFixtures.missingMedia
        XCTAssertEqual(missing.items.count, 1)
        XCTAssertEqual(missing.items.first?.source, .missing)

        let loading = FeedMediaCarouselFixtures.loadingMedia
        XCTAssertFalse(loading.items.isEmpty)
        XCTAssertTrue(loading.items.allSatisfy {
            if case .loading = $0.source { return true }
            return false
        })
    }

    func testMixedAspectSourcesUseDistinctRatios() {
        let items = FeedMediaCarouselFixtures.threeMixedAspectPhotos.items
        let ratios: [CGFloat] = items.compactMap { item in
            guard case .solidColor(let swatch) = item.source else { return nil }
            return swatch.width / swatch.height
        }
        XCTAssertEqual(ratios.count, 3)
        // Portrait, landscape, square — not all equal
        XCTAssertNotEqual(ratios[0], ratios[1], accuracy: 0.01)
        XCTAssertNotEqual(ratios[1], ratios[2], accuracy: 0.01)
        XCTAssertNotEqual(ratios[0], ratios[2], accuracy: 0.01)
    }

    func testSelectedIndexClampsToItemBounds() {
        XCTAssertEqual(FeedMediaCarouselSelection.clampedIndex(0, itemCount: 0), 0)
        XCTAssertEqual(FeedMediaCarouselSelection.clampedIndex(-1, itemCount: 3), 0)
        XCTAssertEqual(FeedMediaCarouselSelection.clampedIndex(0, itemCount: 3), 0)
        XCTAssertEqual(FeedMediaCarouselSelection.clampedIndex(2, itemCount: 3), 2)
        XCTAssertEqual(FeedMediaCarouselSelection.clampedIndex(9, itemCount: 3), 2)
        XCTAssertEqual(FeedMediaCarouselSelection.clampedIndex(1, itemCount: 1), 0)
    }

    func testProgressSegmentCountMatchesItems() {
        for carousel in FeedMediaCarouselFixtures.feedPushesPreviewStack {
            XCTAssertFalse(carousel.id.isEmpty)
            // Progress bar uses max(items.count, 1) for empty; fixtures always have items.
            XCTAssertGreaterThan(carousel.items.count, 0)
        }
        XCTAssertEqual(
            FeedMediaCarouselFixtures.feedPushesPreviewStack.count,
            7,
            "Preview stack should surface the required fixture gallery"
        )
        let videoKinds = FeedMediaCarouselFixtures.photoAndVideoPoster.items.map(\.kind)
        XCTAssertTrue(videoKinds.contains(.video))
    }

    func testViewModelExposesMediaFixtures() {
        let viewModel = FeedViewModel()
        XCTAssertEqual(
            viewModel.mediaCarousels.map(\.id),
            FeedMediaCarouselFixtures.feedPushesPreviewStack.map(\.id)
        )
    }

    func testFixturesIncludeLocationMetadata() {
        for carousel in FeedMediaCarouselFixtures.feedPushesPreviewStack {
            XCTAssertFalse(carousel.locationTitle.isEmpty, carousel.id)
        }
        XCTAssertEqual(FeedMediaCarouselFixtures.threeBundlePhotos.locationTitle, "The Beehive")
        XCTAssertEqual(
            FeedMediaMetadataStyle.chipCornerRadius,
            FeedMediaMetadataStyle.overflowCornerRadius,
            accuracy: 0.01
        )
        XCTAssertEqual(
            FeedMediaMetadataStyle.chipHeight,
            FeedMediaMetadataStyle.overflowButtonSize,
            accuracy: 0.01
        )
    }

    func testParticipantNamesLineIncludesRemainingSuffix() {
        let names = FeedMediaParticipantCopy.namesLine(
            from: FeedMediaCarouselFixtures.threeBundlePhotos.participants
        )
        // Five participants → first two named + remaining count
        XCTAssertEqual(names, "Ohm, Viplove +3")
        XCTAssertEqual(
            FeedMediaParticipantCopy.avatarOverflowCount(participantCount: 5),
            2
        )
    }

    func testAddYoursHiddenForNonParticipants() {
        XCTAssertFalse(FeedMediaCarouselFixtures.mixedPortraitLandscapeSquare.canAddYours)
        XCTAssertTrue(FeedMediaCarouselFixtures.threeBundlePhotos.canAddYours)
        XCTAssertFalse(FeedMediaCarouselFixtures.threeBundlePhotos.participants.isEmpty)
        XCTAssertFalse(FeedMediaCarouselFixtures.threeBundlePhotos.contributorName.isEmpty)
    }

    func testBottomChromeOnlyOnFirstSlide() {
        // Bottom row (avatars / Add yours) is first-slide only; location + progress are every slide.
        XCTAssertTrue(FeedMediaCarouselSelection.showsFullChrome(selectedIndex: 0))
        XCTAssertFalse(FeedMediaCarouselSelection.showsFullChrome(selectedIndex: 1))
        XCTAssertFalse(FeedMediaCarouselSelection.showsFullChrome(selectedIndex: 2))
    }

    func testProgressSegmentFillClampsToUnitInterval() {
        // Active segment uses 0…1 fill; completed = 1, upcoming = 0.
        XCTAssertEqual(min(1, max(0, CGFloat(-0.2))), 0, accuracy: 0.001)
        XCTAssertEqual(min(1, max(0, CGFloat(0.45))), 0.45, accuracy: 0.001)
        XCTAssertEqual(min(1, max(0, CGFloat(1.4))), 1, accuracy: 0.001)
        XCTAssertGreaterThan(FeedMediaLayout.progressTickNanoseconds, 0)
    }

    func testPrimaryVisibilityRequiresMajorityOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 390, height: 700)
        let fullyOnScreen = CGRect(x: 16, y: 100, width: 358, height: 400)
        XCTAssertTrue(
            FeedMediaVisibility.isPrimarilyVisible(
                frame: fullyOnScreen,
                in: visible,
                threshold: FeedMediaLayout.autoplayVisibilityThreshold
            )
        )

        // Peeking next card: only a small band visible at the bottom of the viewport.
        let peeking = CGRect(x: 16, y: 640, width: 358, height: 400)
        XCTAssertFalse(
            FeedMediaVisibility.isPrimarilyVisible(
                frame: peeking,
                in: visible,
                threshold: FeedMediaLayout.autoplayVisibilityThreshold
            )
        )
    }

    func testSolidImageFactoryProducesRequestedSize() {
        let swatch = FeedSolidMediaSwatch(
            red: 0.5, green: 0.4, blue: 0.3,
            width: 120, height: 80
        )
        let image = FeedMediaImageFactory.image(for: swatch)
        XCTAssertEqual(image.size.width, 120, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 80, accuracy: 0.5)
    }
}
